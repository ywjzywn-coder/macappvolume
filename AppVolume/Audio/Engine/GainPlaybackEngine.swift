import AudioToolbox
import CoreAudio
import Foundation

enum GainEngineError: LocalizedError {
    case permissionDenied
    case emptyProcessList
    case noOutputDevice
    case createTapFailed(OSStatus)
    case createAggregateFailed(OSStatus)
    case createIOProcFailed(OSStatus)
    case startFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要屏幕录制权限才能调节其他 App 音量"
        case .emptyProcessList:
            return "没有可控制的音频进程"
        case .noOutputDevice:
            return "没有可用的输出设备"
        case .createTapFailed(let s):
            return "创建 Process Tap 失败（\(s)）"
        case .createAggregateFailed(let s):
            return "创建 Aggregate 设备失败（\(s)）"
        case .createIOProcFailed(let s):
            return "创建 IOProc 失败（\(s)）"
        case .startFailed(let s):
            return "启动音频 IO 失败（\(s)）"
        }
    }
}

/// Captures a process via Core Audio Process Tap, mutes the original path,
/// and plays the tapped audio to the system output with adjustable gain.
final class GainPlaybackEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var processObjectIDs: [AudioObjectID] = []
    private var outputUID: String = ""
    private var tapUUID = UUID()

    /// Accessed from realtime IO thread — keep updates simple/aligned.
    nonisolated(unsafe) private var gainValue: Float = 1

    private(set) var isRunning = false

    var gain: Float {
        get { gainValue }
        set { gainValue = min(max(newValue, 0), 1) }
    }

    func setGain(_ value: Float) {
        gain = value
    }

    /// Starts (or restarts if process list / output changed) gain-controlled playback.
    func start(processObjectIDs: [AudioObjectID], outputDeviceUID: String) throws {
        let ids = Array(Set(processObjectIDs)).sorted()
        guard !ids.isEmpty else { throw GainEngineError.emptyProcessList }
        guard !outputDeviceUID.isEmpty else { throw GainEngineError.noOutputDevice }

        lock.lock()
        defer { lock.unlock() }

        if isRunning,
           self.processObjectIDs == ids,
           self.outputUID == outputDeviceUID
        {
            return
        }

        stopLocked()

        guard ScreenCapturePermission.requestIfNeeded() else {
            throw GainEngineError.permissionDenied
        }

        tapUUID = UUID()
        let description = CATapDescription(stereoMixdownOfProcesses: ids)
        description.name = "AppVolume.Gain.\(tapUUID.uuidString.prefix(8))"
        description.uuid = tapUUID
        description.muteBehavior = CATapMuteBehavior(rawValue: 1)! // CATapMuted
        description.isPrivate = true
        if #available(macOS 26.0, *) {
            description.isProcessRestoreEnabled = true
        }

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr, newTapID != kAudioObjectUnknown else {
            if !ScreenCapturePermission.isGranted {
                throw GainEngineError.permissionDenied
            }
            throw GainEngineError.createTapFailed(status)
        }
        tapID = newTapID

        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "AppVolume Aggregate \(tapUUID.uuidString.prefix(8))",
            kAudioAggregateDeviceUIDKey: "appvolume.agg.\(tapUUID.uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputDeviceUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUUID.uuidString,
                    kAudioSubTapDriftCompensationKey: true
                ]
            ]
        ]

        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &newAggregateID)
        guard status == noErr, newAggregateID != kAudioObjectUnknown else {
            destroyTapLocked()
            throw GainEngineError.createAggregateFailed(status)
        }
        aggregateID = newAggregateID

        let context = Unmanaged.passUnretained(self).toOpaque()
        var procID: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil) { _, inInputData, _, outOutputData, _ in
            Self.render(
                context: context,
                input: inInputData,
                output: outOutputData
            )
        }
        guard status == noErr, let procID else {
            destroyAggregateLocked()
            destroyTapLocked()
            throw GainEngineError.createIOProcFailed(status)
        }
        ioProcID = procID

        status = AudioDeviceStart(aggregateID, procID)
        guard status == noErr else {
            destroyIOProcLocked()
            destroyAggregateLocked()
            destroyTapLocked()
            throw GainEngineError.startFailed(status)
        }

        self.processObjectIDs = ids
        self.outputUID = outputDeviceUID
        isRunning = true
        AVLog.info("Gain engine started tap=\(tapID) agg=\(aggregateID) processes=\(ids.count)")
    }

    func stop() {
        lock.lock()
        stopLocked()
        lock.unlock()
    }

    private func stopLocked() {
        guard isRunning || tapID != kAudioObjectUnknown || aggregateID != kAudioObjectUnknown else {
            return
        }
        if aggregateID != kAudioObjectUnknown, let procID = ioProcID {
            AudioDeviceStop(aggregateID, procID)
        }
        destroyIOProcLocked()
        destroyAggregateLocked()
        destroyTapLocked()
        processObjectIDs = []
        outputUID = ""
        isRunning = false
        AVLog.info("Gain engine stopped")
    }

    private func destroyIOProcLocked() {
        if aggregateID != kAudioObjectUnknown, let procID = ioProcID {
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        ioProcID = nil
    }

    private func destroyAggregateLocked() {
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = kAudioObjectUnknown
        }
    }

    private func destroyTapLocked() {
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = kAudioObjectUnknown
        }
    }

    private static func render(
        context: UnsafeMutableRawPointer?,
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>
    ) {
        guard let context else { return }

        let engine = Unmanaged<GainPlaybackEngine>.fromOpaque(context).takeUnretainedValue()
        let gain = engine.gainValue

        let inBuffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: input)
        )
        let outBuffers = UnsafeMutableAudioBufferListPointer(output)

        let bufferCount = min(inBuffers.count, outBuffers.count)
        for i in 0..<bufferCount {
            let inBuf = inBuffers[i]
            let outBuf = outBuffers[i]
            guard let inData = inBuf.mData, let outData = outBuf.mData else { continue }

            let byteCount = min(Int(inBuf.mDataByteSize), Int(outBuf.mDataByteSize))
            let sampleCount = byteCount / MemoryLayout<Float>.size
            let inSamples = inData.bindMemory(to: Float.self, capacity: sampleCount)
            let outSamples = outData.bindMemory(to: Float.self, capacity: sampleCount)

            if gain <= 0.0001 {
                memset(outData, 0, byteCount)
            } else if abs(gain - 1) < 0.0001 {
                memcpy(outData, inData, byteCount)
            } else {
                for s in 0..<sampleCount {
                    outSamples[s] = inSamples[s] * gain
                }
            }

            outBuffers[i].mDataByteSize = UInt32(byteCount)
        }

        if outBuffers.count > inBuffers.count {
            for i in inBuffers.count..<outBuffers.count {
                if let outData = outBuffers[i].mData {
                    memset(outData, 0, Int(outBuffers[i].mDataByteSize))
                }
            }
        }
    }
}
