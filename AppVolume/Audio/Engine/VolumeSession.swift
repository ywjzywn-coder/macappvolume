import CoreAudio
import Foundation

/// Owns per-bundleID audio control:
/// - mute / volume 0  → mute-only Process Tap (no IO)
/// - 0 < volume < 1 → tap + gain playback engine
/// - volume == 1 && unmuted → release all control (system passthrough)
final class VolumeSession {
    let bundleID: String
    private let muteTap = ProcessTapController()
    private let engine = GainPlaybackEngine()
    private(set) var lastError: String?
    private var lastProcessIDs: [AudioObjectID] = []
    private var lastOutputUID: String?

    init(bundleID: String) {
        self.bundleID = bundleID
        AudioTeardown.shared.register(id: bundleID) { [weak self] in
            self?.stop()
        }
    }

    deinit {
        stop()
        AudioTeardown.shared.unregister(id: bundleID)
    }

    var isActive: Bool {
        muteTap.isActive(key: bundleID) || engine.isRunning
    }

    var isMuteTapActive: Bool {
        muteTap.isActive(key: bundleID)
    }

    var isGainActive: Bool {
        engine.isRunning
    }

    @discardableResult
    func apply(
        state: AppVolumeState,
        processObjectIDs: [AudioObjectID],
        outputDeviceUID: String?
    ) -> Bool {
        lastProcessIDs = processObjectIDs
        lastOutputUID = outputDeviceUID

        // Full passthrough — no interception.
        if !state.needsTapControl {
            muteTap.destroy(key: bundleID)
            engine.stop()
            lastError = nil
            return true
        }

        // Hard silence: mute-only tap is enough and cheaper than full IO.
        if state.isMuted || state.effectiveGain < 0.001 {
            engine.stop()
            do {
                try muteTap.ensureMuteTap(key: bundleID, processObjectIDs: processObjectIDs)
                lastError = nil
                return true
            } catch {
                lastError = error.localizedDescription
                AVLog.error("Mute path failed for \(bundleID): \(error.localizedDescription)")
                return false
            }
        }

        // Partial volume: destroy mute-only tap, run gain engine.
        muteTap.destroy(key: bundleID)
        guard let outputUID = outputDeviceUID, !outputUID.isEmpty else {
            lastError = GainEngineError.noOutputDevice.localizedDescription
            return false
        }

        do {
            engine.setGain(state.effectiveGain)
            try engine.start(processObjectIDs: processObjectIDs, outputDeviceUID: outputUID)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            AVLog.error("Gain path failed for \(bundleID): \(error.localizedDescription)")
            return false
        }
    }

    func updateGainOnly(_ state: AppVolumeState) {
        if engine.isRunning {
            engine.setGain(state.effectiveGain)
        }
    }

    func stop() {
        engine.stop()
        muteTap.destroyAll()
        lastError = nil
    }
}
