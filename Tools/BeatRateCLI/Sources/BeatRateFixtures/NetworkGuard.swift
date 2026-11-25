import Foundation
import Synchronization

/// Zero network, enforced. Every request through the URL loading system fails and is
/// recorded, and so is every request without a fixture. The CLI exits on the first
/// record, so a test fails even when the app caught the error and recovered.
/// Copied from ReflexArchitecture_iOS @ befa64a.
nonisolated public final class NetworkGuard: URLProtocol {
    private static let entries = Mutex<[String]>([])

    public static var violations: [String] { entries.withLock { $0 } }
    public static func record(_ entry: String) { entries.withLock { $0.append(entry) } }
    public static func reset() { entries.withLock { $0.removeAll() } }

    // ponytail: covers URLSession.shared and the global protocol registry; a session built from
    // its own URLSessionConfiguration needs NetworkGuard in its protocolClasses.
    public static func install() { URLProtocol.registerClass(NetworkGuard.self) }

    override public class func canInit(with request: URLRequest) -> Bool { true }
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override public func startLoading() {
        Self.record("\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "?")")
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override public func stopLoading() {}
}
