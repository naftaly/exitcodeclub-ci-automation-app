import Foundation
import KSCrash

/// Terminal stage of the run-summary pipeline: POSTs each summary to the
/// backend's runs endpoint.
///
/// KSCrash hands summaries to stages one at a time, so every POST carries a
/// single-run `{"runs":[...]}` envelope. Returning the payload marks the run
/// delivered (deleted from disk); throwing keeps it on disk for the next send.
struct RunSummarySink: PipelineStage {
    private let apiURL: URL
    private let session: URLSession

    init(url: URL) {
        self.apiURL = url
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func process(_ run: RunSummary) async throws -> RunSummary? {
        try await upload(run)
        return run
    }

    private struct Envelope: Encodable {
        let runs: [RunSummary]
    }

    private func upload(_ run: RunSummary) async throws {
        // RunSummary encodes to the wire schema, so the envelope is just the
        // model wrapped in the {"runs":[...]} the server expects.
        let body = try JSONEncoder().encode(Envelope(runs: [run]))

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        // The server is idempotent on run_id, so a 2xx that reports a
        // duplicate still means "delivered".
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "RunSummarySink",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: responseBody]
            )
        }
    }
}
