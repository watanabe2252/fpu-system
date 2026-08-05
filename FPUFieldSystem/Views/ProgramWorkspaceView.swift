import SwiftUI

struct ProgramWorkspaceView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @StateObject private var vm: WorkspaceViewModel
    let onBack: () -> Void

    @State private var selectedTab: Tab = .dashboard
    @State private var isEditingTitle = false
    @State private var editedTitle = ""

    enum Tab: Hashable {
        case dashboard, input, maintenance
    }

    init(program: Program, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _vm = StateObject(wrappedValue: WorkspaceViewModel(program: program, supabase: SupabaseService.shared))
    }

    var body: some View {
        content
            .background(Theme.bgDark.ignoresSafeArea())
            .task {
                if vm.links.isEmpty { await vm.loadAll() }
                vm.subscribeRealtime()
            }
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

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        #else
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
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .dashboard:
            MacDashboardView(vm: vm)
        case .input:
            MacInputView(vm: vm)
        case .maintenance:
            MacMaintenanceView(vm: vm)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    vm.unsubscribeRealtime()
                    onBack()
                } label: {
                    Label("大会一覧に戻る", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accentBlue)

                HStack(spacing: 6) {
                    Text(vm.programTitle)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if supabase.currentUserRole == .admin {
                        Button {
                            editedTitle = vm.programTitle
                            isEditingTitle = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.realtimeConnected ? Theme.accentGreen : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(vm.realtimeConnected ? "リアルタイム接続中" : "未接続")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(supabase.currentUserRole == .admin ? "ADMIN" : "STAFF")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.borderStroke.opacity(0.5))
                        .foregroundStyle(.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(16)

            List(selection: $selectedTab) {
                Label("ダッシュボード", systemImage: "chart.bar.fill")
                    .tag(Tab.dashboard)
                Label("データ入力", systemImage: "square.and.pencil")
                    .tag(Tab.input)
                if supabase.currentUserRole == .admin {
                    Label("メンテナンス", systemImage: "wrench.and.screwdriver.fill")
                        .tag(Tab.maintenance)
                }
            }
            .listStyle(.sidebar)
        }
        .background(Theme.cardBg)
    }
    #endif

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
