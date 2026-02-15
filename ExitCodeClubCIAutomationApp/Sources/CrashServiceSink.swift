import Foundation
@preconcurrency import KSCrashRecording

final class CrashServiceSink: NSObject, CrashReportFilter {
    private let apiURL: URL
    private let session: URLSession

    init(url: URL) {
        self.apiURL = url
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        super.init()
    }

    func filterReports(
        _ reports: [any CrashReport],
        onCompletion: (([any CrashReport]?, (any Error)?) -> Void)?
    ) {
        guard !reports.isEmpty else {
            onCompletion?(reports, nil)
            return
        }

        Task {
            var successfulReports: [any CrashReport] = []
            var lastError: Error?

            for report in reports {
                do {
                    try await uploadReport(report)
                    successfulReports.append(report)
                } catch {
                    lastError = error
                }
            }

            onCompletion?(successfulReports, lastError)
        }
    }

    private func uploadReport(_ report: any CrashReport) async throws {
        guard let dictReport = report as? CrashReportDictionary else {
            throw URLError(.badServerResponse)
        }

        let jsonData = try JSONSerialization.data(withJSONObject: dictReport.value)

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "CrashServiceSink",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: body]
            )
        }
    }
}
