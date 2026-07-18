import SwiftUI

struct DevicePickerView: View {
    @Environment(AudioSessionStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("音频设备")
                .font(.caption)
                .foregroundStyle(.secondary)

            deviceSection(
                title: "输出",
                systemImage: "speaker.wave.2",
                devices: store.outputDevices,
                emptyText: "未找到输出设备",
                selection: Binding(
                    get: { store.outputDevices.first(where: \.isDefault)?.id ?? store.outputDevices.first?.id ?? 0 },
                    set: { newID in
                        if let device = store.outputDevices.first(where: { $0.id == newID }) {
                            store.setDefaultOutputDevice(device)
                        }
                    }
                )
            )

            deviceSection(
                title: "输入",
                systemImage: "mic",
                devices: store.inputDevices,
                emptyText: "未找到输入设备",
                selection: Binding(
                    get: { store.inputDevices.first(where: \.isDefault)?.id ?? store.inputDevices.first?.id ?? 0 },
                    set: { newID in
                        if let device = store.inputDevices.first(where: { $0.id == newID }) {
                            store.setDefaultInputDevice(device)
                        }
                    }
                )
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func deviceSection(
        title: String,
        systemImage: String,
        devices: [AudioDevice],
        emptyText: String,
        selection: Binding<AudioObjectID>
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(.callout)
                .frame(width: 34, alignment: .leading)

            if devices.isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Picker(title, selection: selection) {
                    ForEach(devices) { device in
                        Text(device.isDefault ? "\(device.name) ✓" : device.name)
                            .tag(device.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

import CoreAudio
