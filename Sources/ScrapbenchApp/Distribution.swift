import Foundation

/// Which build this is. The App Store build runs in the sandbox, where user
/// scripts cannot run and Services cannot be registered; one source tree
/// serves both builds, so the check is made at run time.
enum Distribution {
    static let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
}
