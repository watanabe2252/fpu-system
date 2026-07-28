import SwiftUI

@main
struct FPUFieldSystemApp: App {
    @StateObject private var supabase = SupabaseService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(supabase)
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 980, idealWidth: 1280, minHeight: 640, idealHeight: 820)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 820)
        #endif
    }
}
