import Foundation
import KSCrash

/// Terminal stage of the report pipeline: POSTs each crash report to the
/// backend's reports endpoint.
///
/// KSCrash hands reports to stages one at a time. Returning the payload marks
/// the report delivered (deleted from disk); throwing keeps it on disk for the
/// next send.
struct CrashServiceSink: PipelineStage {
    private let apiURL: URL
    private let session: URLSession

    init(url: URL) {
        self.apiURL = url
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func process(_ report: Report) async throws -> Report? {
        try await upload(report)
        return report
    }

    private func upload(_ report: Report) async throws {
        // Report round-trips the on-disk schema, so the model encodes straight
        // to the JSON the server expects.
        let body = try JSONEncoder().encode(report)

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "CrashServiceSink",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: responseBody]
            )
        }
    }
}
