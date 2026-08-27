import SwiftUI
import MapKit
import CoreLocation

struct MapPointsEditorView: View {
    @ObservedObject var vm: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPointName: String?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var statusMessage: String?
    @State private var isSaving = false
    @State private var latText = ""
    @State private var lonText = ""
    @State private var addressText = ""
    @State private var isGeocoding = false
    private let geocoder = CLGeocoder()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("① 地点を選択してから、地図をタップして位置を指定してください。")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.gray)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.pointNames, id: \.self) { name in
                            let hasLocation = vm.location(named: name) != nil
                            Button {
                                selectedPointName = name
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: hasLocation ? "mappin.circle.fill" : "mappin.circle")
                                        .foregroundStyle(hasLocation ? Theme.accentGreen : .gray)
                                    Text(name)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedPointName == name ? Theme.accentBlue.opacity(0.25) : Theme.cardBg)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(selectedPointName == name ? Theme.accentBlue : Theme.borderStroke)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if let selectedPointName {
                    HStack {
                        Text("選択中: \(selectedPointName)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Theme.accentBlue)
                        Spacer()
                        if vm.location(named: selectedPointName) != nil {
                            Button(role: .destructive) {
                                Task { await deleteSelected() }
                            } label: {
                                Label("位置を削除", systemImage: "trash")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                    }

                    Text("② 住所を入力すると緯度経度を自動取得できます。")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.gray)
                    HStack(spacing: 8) {
                        TextField("住所 (例: 東京都渋谷区神南1-1-1)", text: $addressText)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            Task { await geocodeAddress() }
                        } label: {
                            if isGeocoding {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("住所から取得")
                            }
                        }
                        .disabled(addressText.trimmingCharacters(in: .whitespaces).isEmpty || isGeocoding)
                    }

                    Text("③ 緯度経度を直接入力・修正することもできます。")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.gray)
                    HStack(spacing: 8) {
                        TextField("緯度 (例: 35.6812)", text: $latText)
                            #if os(iOS)
                            .keyboardType(.numbersAndPunctuation)
                            #endif
                            .textFieldStyle(.roundedBorder)
                        TextField("経度 (例: 139.7671)", text: $lonText)
                            #if os(iOS)
                            .keyboardType(.numbersAndPunctuation)
                            #endif
                            .textFieldStyle(.roundedBorder)
                        Button("座標を保存") {
                            Task { await saveTypedCoordinate() }
                        }
                        .disabled(Double(latText) == nil || Double(lonText) == nil)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(statusMessage.hasPrefix("✔") ? Theme.accentGreen : Theme.rose)
                }
            }
            .padding(16)
            .background(Theme.cardBg)

            MapReader { proxy in
                Map(position: $cameraPosition) {
                    ForEach(vm.locations) { location in
                        Marker(location.name, coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
                            .tint(location.name == selectedPointName ? Theme.amber : Theme.accentBlue)
                    }
                }
                .mapStyle(.standard)
                .onTapGesture { screenPoint in
                    guard let selectedPointName else {
                        statusMessage = "❌ 先に地点を選んでください"
                        return
                    }
                    guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }
                    Task { await save(name: selectedPointName, coordinate: coordinate) }
                }
            }
        }
        .background(Theme.bgDark)
        .navigationTitle("地点の位置を編集")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
        }
        .onChange(of: selectedPointName) { _, newValue in
            loadTextFields(for: newValue)
        }
    }

    private func loadTextFields(for name: String?) {
        addressText = ""
        guard let name, let location = vm.location(named: name) else {
            latText = ""
            lonText = ""
            return
        }
        latText = String(location.latitude)
        lonText = String(location.longitude)
    }

    private func geocodeAddress() async {
        let query = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isGeocoding = true
        statusMessage = nil
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            guard let coordinate = placemarks.first?.location?.coordinate else {
                statusMessage = "❌ 住所から位置を特定できませんでした"
                isGeocoding = false
                return
            }
            latText = String(coordinate.latitude)
            lonText = String(coordinate.longitude)
            cameraPosition = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
            statusMessage = "✔ 住所から座標を取得しました。内容を確認して「座標を保存」を押してください"
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
        isGeocoding = false
    }

    private func save(name: String, coordinate: CLLocationCoordinate2D) async {
        isSaving = true
        statusMessage = nil
        do {
            try await vm.saveLocation(name: name, coordinate: coordinate)
            latText = String(coordinate.latitude)
            lonText = String(coordinate.longitude)
            statusMessage = "✔ 「\(name)」の位置を更新しました"
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
        isSaving = false
    }

    private func saveTypedCoordinate() async {
        guard let selectedPointName, let lat = Double(latText), let lon = Double(lonText) else { return }
        await save(name: selectedPointName, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }

    private func deleteSelected() async {
        guard let selectedPointName, let location = vm.location(named: selectedPointName) else { return }
        do {
            try await vm.deleteLocation(location)
            latText = ""
            lonText = ""
            statusMessage = "✔ 「\(selectedPointName)」の位置を削除しました"
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }
}
