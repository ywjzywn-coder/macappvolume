import Foundation

final class AudioTeardown: @unchecked Sendable {
    static let shared = AudioTeardown()

    private let lock = NSLock()
    private var handlers: [String: () -> Void] = [:]

    private init() {}

    func register(id: String, teardown: @escaping () -> Void) {
        lock.lock()
        handlers[id] = teardown
        lock.unlock()
    }

    func unregister(id: String) {
        lock.lock()
        handlers.removeValue(forKey: id)
        lock.unlock()
    }

    func tearDownAll() {
        lock.lock()
        let copy = Array(handlers.values)
        handlers.removeAll()
        lock.unlock()
        for handler in copy {
            handler()
        }
        AVLog.info("AudioTeardown completed (\(copy.count) handlers)")
    }
}
