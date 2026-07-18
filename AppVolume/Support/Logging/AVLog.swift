import Foundation
import os.log

enum AVLog {
    private static let logger = Logger(subsystem: "local.appvolume", category: "audio")

    static var isVerbose = false

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func debug(_ message: String) {
        guard isVerbose else { return }
        logger.debug("\(message, privacy: .public)")
    }
}
