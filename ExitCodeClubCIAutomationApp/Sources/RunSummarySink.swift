import Foundation
@preconcurrency import KSCrashRecording

final class RunSummarySink: NSObject, CrashRunFilter {

    // Server caps a single envelope at 100 runs. The store's default
    // maxRunSummaryCount is 50, so a single batch is the common case;
    // chunking is here for the unusual run where someone bumped the cap.
    private static let maxBatchSize = 100

    private let apiURL: URL
    private let session: URLSession

    init(url: URL) {
        self.apiURL = url
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        super.init()
    }

    func filterRuns(
        _ runs: [RunSummary],
        onCompletion: (([RunSummary]?, (any Error)?) -> Void)?
    ) {
        guard !runs.isEmpty else {
            onCompletion?(runs, nil)
            return
        }

        Task {
            // The server is idempotent on run_id, so a 2xx that reports
            // duplicates still means "delivered" — include those runs in
            // accepted so the store can delete the on-disk files. Per-run
            // attribution within a batch isn't possible (server returns
            // only counts), so a failed batch keeps every run in it for
            // retry on the next call.
            var accepted: [RunSummary] = []
            var lastError: Error?

            for batch in Self.chunked(runs, by: Self.maxBatchSize) {
                do {
                    try await uploadBatch(batch)
                    accepted.append(contentsOf: batch)
                } catch {
                    lastError = error
                    print("[RunSummarySink] Failed batch of \(batch.count): \(error)")
                }
            }

            onCompletion?(accepted, lastError)
        }
    }

    private func uploadBatch(_ runs: [RunSummary]) async throws {
        // Each RunSummary already knows how to encode itself to the wire
        // schema. To assemble a {"runs":[...]} envelope we deserialize each
        // back to a Foundation object and reserialize as one — a string
        // splice would be faster but would couple this sink to the
        // encoder's exact byte layout (whitespace, key ordering, etc.).
        var runObjects: [Any] = []
        runObjects.reserveCapacity(runs.count)
        for run in runs {
            guard let data = run.jsonData() else {
                throw URLError(.cannotParseResponse)
            }
            runObjects.append(try JSONSerialization.jsonObject(with: data))
        }
        let envelope: [String: Any] = ["runs": runObjects]
        let body = try JSONSerialization.data(withJSONObject: envelope)

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "RunSummarySink",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: body]
            )
        }
    }

    private static func chunked<T>(_ source: [T], by size: Int) -> [[T]] {
        guard size > 0, source.count > size else { return [source] }
        return stride(from: 0, to: source.count, by: size).map {
            Array(source[$0..<Swift.min($0 + size, source.count)])
        }
    }
}
