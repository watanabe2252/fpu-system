import SwiftUI
import MapKit
import CoreLocation

/// Lets the user set (or clear) coordinates for one or more receive-point
/// names at once — e.g. "本社仮設1" and "本社仮設2" are physically the same
/// spot with different pan/tilt heads, so selecting both and entering the
/// address once applies the same coordinate to both names.
struct LocationEditSheet: View {
    @ObservedObject var vm: WorkspaceViewModel
    let initialSelection: Set<String>
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String>
    @State private var addressText = ""
    @State private var latText = ""
    @State private var lonText = ""
    @State private var statusMessage: String?
    @State private var isGeocoding = false
    @State private var isSaving = false
    private let geocoder = CLGeocoder()

    init(vm: WorkspaceViewModel, initialSelection: Set<String>) {
        self.vm = vm
        self.initialSelection = initialSelection
        _selected = State(initialValue: initialSelection)
    }

    var body: some View {
        ZStack {
            Theme.bgDark.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("地点の座標を編集")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.accentBlue)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("① 対象の地点を選択(同じ場所ならまとめて選択可)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.gray)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(vm.pointNames, id: \.self) { name in
                                    let hasLocation = vm.location(named: name) != nil
                                    let isSelected = selected.contains(name)
                                    Button {
                                        if isSelected { selected.remove(name) } else { selected.insert(name) }
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
                                        .background(isSelected ? Theme.accentBlue.opacity(0.25) : Theme.cardBg)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(isSelected ? Theme.accentBlue : Theme.borderStroke))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if !selected.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("② 住所を入力すると緯度経度を自動取得できます")
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
                                        Text("取得")
                                    }
                                }
                                .disabled(addressText.trimmingCharacters(in: .whitespaces).isEmpty || isGeocoding)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("③ 緯度経度を直接入力・修正することもできます")
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
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                Task { await saveAll() }
                            } label: {
                                if isSaving {
                                    ProgressView().tint(Theme.bgDark)
                                } else {
                                    Text("選択した\(selected.count)地点に座標を保存")
                                        .font(.system(size: 12, weight: .black))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Double(latText) == nil || Double(lonText) == nil ? Theme.accentGreen.opacity(0.4) : Theme.accentGreen)
                            .foregroundStyle(Theme.bgDark)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(Double(latText) == nil || Double(lonText) == nil || isSaving)
                        }

                        Button(role: .destructive) {
                            Task { await deleteAll() }
                        } label: {
                            Text("選択した地点の座標を削除")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.rose)
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(statusMessage.hasPrefix("✔") ? Theme.accentGreen : Theme.rose)
                    }

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
        .onAppear { prefillFromSelection() }
        .onChange(of: selected) { _, _ in prefillFromSelection() }
    }

    private func prefillFromSelection() {
        guard let name = selected.first(where: { vm.location(named: $0) != nil }),
              let location = vm.location(named: name) else {
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
            statusMessage = "✔ 住所から座標を取得しました。内容を確認して保存してください"
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
        isGeocoding = false
    }

    private func saveAll() async {
        guard let lat = Double(latText), let lon = Double(lonText) else { return }
        isSaving = true
        statusMessage = nil
        do {
            for name in selected {
                try await vm.saveLocation(name: name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
            statusMessage = "✔ \(selected.count)件の座標を更新しました"
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
        isSaving = false
    }

    private func deleteAll() async {
        isSaving = true
        statusMessage = nil
        do {
            for name in selected {
                if let location = vm.location(named: name) {
                    try await vm.deleteLocation(location)
                }
            }
            latText = ""
            lonText = ""
            statusMessage = "✔ 選択した地点の座標を削除しました"
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
        isSaving = false
    }
}
