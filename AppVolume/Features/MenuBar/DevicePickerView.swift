import SwiftUI

struct DevicePickerView: View {
    @Environment(AudioSessionStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            deviceSection(
                title: "输出设备",
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
                title: "输入设备",
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
        .padding(.vertical, 8)
    }

    private func deviceSection(
        title: String,
        devices: [AudioDevice],
        emptyText: String,
        selection: Binding<AudioObjectID>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            if devices.isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            } else {
                Picker(title, selection: selection) {
                    ForEach(devices) { device in
                        Text(device.isDefault ? "\(device.name) ✓" : device.name)
                            .tag(device.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
            }
        }
    }
}

import CoreAudio
