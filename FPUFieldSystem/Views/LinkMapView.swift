import SwiftUI
import MapKit

struct LinkMapView: View {
    @ObservedObject var vm: WorkspaceViewModel
    @EnvironmentObject private var supabase: SupabaseService

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showEditor = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                ForEach(vm.locations) { location in
                    Marker(location.name, coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
                        .tint(Theme.accentBlue)
                }
                ForEach(vm.mapLinkLines) { line in
                    MapPolyline(coordinates: [line.from, line.to])
                        .stroke(line.category.accentColor, lineWidth: 3)
                }
            }
            .mapStyle(.standard(elevation: .realistic))

            if vm.locations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.gray)
                    Text("地点の位置情報がまだ登録されていません。")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.gray)
                    if supabase.currentUserRole == .admin {
                        Text("右下のボタンから地点を地図上に登録できます。")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.gray)
                    }
                }
                .padding(20)
                .background(Theme.cardBg.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            if supabase.currentUserRole == .admin {
                Button {
                    showEditor = true
                } label: {
                    Label("地点を編集", systemImage: "mappin.and.ellipse")
                        .font(.system(size: 13, weight: .black))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.accentBlue)
                        .foregroundStyle(Theme.bgDark)
                        .clipShape(Capsule())
                }
                .padding(16)
            }
        }
        .task {
            if vm.locations.isEmpty { await vm.reloadLocations() }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                MapPointsEditorView(vm: vm)
            }
            #if os(macOS)
            .frame(minWidth: 640, minHeight: 560)
            #endif
        }
    }
}
