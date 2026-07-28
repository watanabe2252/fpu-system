import SwiftUI

struct ProgramWorkspaceView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @StateObject private var vm: WorkspaceViewModel
    let onBack: () -> Void

    @State private var selectedTab: Tab = .dashboard
    @State private var isEditingTitle = false
    @State private var editedTitle = ""

    enum Tab {
        case dashboard, input, maintenance
    }

    init(program: Program, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _vm = StateObject(wrappedValue: WorkspaceViewModel(program: program, supabase: SupabaseService.shared))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $selectedTab) {
                DashboardView(vm: vm)
                    .tabItem { Label("ダッシュボード", systemImage: "chart.bar.fill") }
                    .tag(Tab.dashboard)

                InputView(vm: vm)
                    .tabItem { Label("データ入力", systemImage: "square.and.pencil") }
                    .tag(Tab.input)

                if supabase.currentUserRole == .admin {
                    NavigationStack {
                        MaintenanceView(vm: vm)
                    }
                    .tabItem { Label("メンテナンス", systemImage: "wrench.and.screwdriver.fill") }
                    .tag(Tab.maintenance)
                }
            }
            .tint(Theme.accentBlue)
        }
        .background(Theme.bgDark.ignoresSafeArea())
        .onDisappear { vm.unsubscribeRealtime() }
        .alert("番組名を編集", isPresented: $isEditingTitle) {
            TextField("番組名", text: $editedTitle)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                let newTitle = editedTitle.trimmingCharacters(in: .whitespaces)
                if !newTitle.isEmpty {
                    Task { try? await vm.updateProgramTitle(newTitle) }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                vm.unsubscribeRealtime()
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Theme.accentBlue)
            }
            Text(vm.programTitle)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.accentBlue)
                .lineLimit(1)
            if supabase.currentUserRole == .admin {
                Button {
                    editedTitle = vm.programTitle
                    isEditingTitle = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
            }
            Spacer()
            Circle()
                .fill(vm.realtimeConnected ? Theme.accentGreen : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(supabase.currentUserRole == .admin ? "ADMIN" : "STAFF")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.borderStroke.opacity(0.5))
                .foregroundStyle(.gray)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.cardBg)
    }
}
