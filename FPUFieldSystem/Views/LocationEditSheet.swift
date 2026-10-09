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
    @State private var useDMSInput = false
    @State private var latDeg = ""
    @State private var latMin = ""
    @State private var latSec = ""
    @State private var lonDeg = ""
    @State private var lonMin = ""
    @State private var lonSec = ""
    @State private var elevationText = ""
    @State private var heightAboveGroundText = ""
    @State private var antennaGainText = ""
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
                            HStack {
                                Text("③ 緯度経度を直接入力・修正することもできます")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.gray)
                                Spacer()
                                Picker("形式", selection: $useDMSInput) {
                                    Text("10進数").tag(false)
                                    Text("度分秒").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
                            }

                            if useDMSInput {
                                VStack(alignment: .leading, spacing: 6) {
                                    dmsRow(label: "緯度", deg: $latDeg, min: $latMin, sec: $latSec)
                                    dmsRow(label: "経度", deg: $lonDeg, min: $lonMin, sec: $lonSec)
                                    Text("例: 35°09'02.772\" → 35 / 9 / 2.772")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.gray.opacity(0.7))
                                }
                            } else {
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
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("④ アンテナ設置情報 (任意)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.gray)
                            HStack(spacing: 8) {
                                labeledNumberField(title: "標高 (m)", text: $elevationText)
                                labeledNumberField(title: "地上高 (m)", text: $heightAboveGroundText)
                                labeledNumberField(title: "アンテナ利得 (dBi)", text: $antennaGainText)
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
                            .background(resolvedCoordinate == nil ? Theme.accentGreen.opacity(0.4) : Theme.accentGreen)
                            .foregroundStyle(Theme.bgDark)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(resolvedCoordinate == nil || isSaving)
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
            elevationText = ""
            heightAboveGroundText = ""
            antennaGainText = ""
            return
        }
        latText = String(location.latitude)
        lonText = String(location.longitude)
        let latDMS = Self.decimalToDMS(location.latitude)
        let lonDMS = Self.decimalToDMS(location.longitude)
        latDeg = String(latDMS.deg); latMin = String(latDMS.min); latSec = String(format: "%.3f", latDMS.sec)
        lonDeg = String(lonDMS.deg); lonMin = String(lonDMS.min); lonSec = String(format: "%.3f", lonDMS.sec)
        elevationText = location.elevation.map { String($0) } ?? ""
        heightAboveGroundText = location.heightAboveGround.map { String($0) } ?? ""
        antennaGainText = location.antennaGain.map { String($0) } ?? ""
    }

    /// The coordinate currently entered, from whichever input mode (decimal or DMS) is active.
    private var resolvedCoordinate: CLLocationCoordinate2D? {
        if useDMSInput {
            guard let lat = Self.dmsToDecimal(deg: latDeg, min: latMin, sec: latSec),
                  let lon = Self.dmsToDecimal(deg: lonDeg, min: lonMin, sec: lonSec) else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            guard let lat = Double(latText), let lon = Double(lonText) else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    private static func dmsToDecimal(deg: String, min: String, sec: String) -> Double? {
        guard let d = Double(deg), let m = Double(min), let s = Double(sec) else { return nil }
        return d + m / 60 + s / 3600
    }

    private static func decimalToDMS(_ value: Double) -> (deg: Int, min: Int, sec: Double) {
        let deg = Int(value)
        let remainderMinutes = (value - Double(deg)) * 60
        let min = Int(remainderMinutes)
        let sec = (remainderMinutes - Double(min)) * 60
        return (deg, min, sec)
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
        guard let coordinate = resolvedCoordinate else { return }
        let elevation = Double(elevationText)
        let heightAboveGround = Double(heightAboveGroundText)
        let antennaGain = Double(antennaGainText)
        isSaving = true
        statusMessage = nil
        do {
            for name in selected {
                try await vm.saveLocation(
                    name: name,
                    coordinate: coordinate,
                    elevation: elevation,
                    heightAboveGround: heightAboveGround,
                    antennaGain: antennaGain
                )
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

    @ViewBuilder
    private func dmsRow(label: String, deg: Binding<String>, min: Binding<String>, sec: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, alignment: .leading)
            dmsField(deg, suffix: "°")
            dmsField(min, suffix: "'")
            dmsField(sec, suffix: "\"")
        }
    }

    @ViewBuilder
    private func dmsField(_ text: Binding<String>, suffix: String) -> some View {
        HStack(spacing: 2) {
            TextField("0", text: text)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
            Text(suffix).font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
        }
    }

    @ViewBuilder
    private func labeledNumberField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.gray)
            TextField("", text: text)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
                .textFieldStyle(.roundedBorder)
        }
    }
}
