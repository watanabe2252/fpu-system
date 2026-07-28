import SwiftUI

struct RootView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @State private var isRestoring = true
    @State private var selectedProgram: Program?

    var body: some View {
        ZStack {
            Theme.bgDark.ignoresSafeArea()

            if isRestoring {
                ProgressView()
                    .tint(Theme.accentBlue)
            } else if !supabase.isAuthenticated {
                LoginView()
            } else if let program = selectedProgram {
                ProgramWorkspaceView(program: program) {
                    selectedProgram = nil
                }
            } else {
                ProgramSelectView(onSelect: { program in
                    selectedProgram = program
                })
            }
        }
        .task {
            await supabase.restoreSession()
            isRestoring = false
        }
    }
}
