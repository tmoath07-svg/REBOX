import Foundation

/// Boundary for the future Xbox Remote Play engine.
/// The app intentionally has no fake connection implementation.
@MainActor
protocol StreamingEngine: AnyObject {
    var state: StreamingState { get }
    func discoverConsoles() async throws
    func connect(to console: ConsoleDescriptor) async throws
    func disconnect() async
}

enum StreamingState: Equatable {
    case idle
    case discovering
    case connecting
    case streaming
    case failed(String)
}

struct ConsoleDescriptor: Identifiable, Equatable {
    let id: String
    let name: String
    let model: String
}
