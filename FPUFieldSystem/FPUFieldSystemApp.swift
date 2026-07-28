import SwiftUI

@main
struct FPUFieldSystemApp: App {
    @StateObject private var supabase = SupabaseService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(supabase)
                .preferredColorScheme(.dark)
        }
    }
}
