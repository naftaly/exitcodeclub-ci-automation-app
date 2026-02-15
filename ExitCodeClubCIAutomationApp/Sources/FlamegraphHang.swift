import Foundation

enum FlamegraphHang {
    private static var endTime: Date = .distantPast

    static func run(duration: TimeInterval) {
        endTime = Date().addingTimeInterval(duration)
        while Date() < endTime {
            dispatchWorkload()
        }
    }

    @inline(never)
    private static func dispatchWorkload() {
        let choice = Int.random(in: 0..<5)
        switch choice {
        case 0: performNetworkSimulation()
        case 1: performJSONProcessing()
        case 2: performImageProcessing()
        case 3: performDatabaseSimulation()
        default: performUILayoutCalculation()
        }
    }

    // MARK: - Network Simulation

    @inline(never)
    private static func performNetworkSimulation() {
        parseHTTPHeaders()
        deserializeResponseBody()
        validateSSLCertificate()
    }

    @inline(never)
    private static func parseHTTPHeaders() {
        for _ in 0..<50 {
            let _ = UUID().uuidString.split(separator: "-").map { String($0).lowercased() }
        }
    }

    @inline(never)
    private static func deserializeResponseBody() {
        decodeBase64Payload()
        uncompressGzipData()
    }

    @inline(never)
    private static func decodeBase64Payload() {
        for _ in 0..<30 {
            let str = String(repeating: "abc123", count: 100)
            let _ = Data(str.utf8).base64EncodedString()
        }
    }

    @inline(never)
    private static func uncompressGzipData() {
        var result: [UInt8] = []
        for i in 0..<5000 {
            result.append(UInt8(i % 256))
        }
        let _ = result.reduce(0, { $0 &+ Int($1) })
    }

    @inline(never)
    private static func validateSSLCertificate() {
        computeCertificateHash()
        verifyCertificateChain()
    }

    @inline(never)
    private static func computeCertificateHash() {
        var hash: UInt64 = 0
        for i in 0..<10000 {
            hash = hash &* 31 &+ UInt64(i)
        }
        let _ = hash
    }

    @inline(never)
    private static func verifyCertificateChain() {
        for _ in 0..<20 {
            let _ = (0..<100).map { _ in arc4random() }.sorted()
        }
    }

    // MARK: - JSON Processing

    @inline(never)
    private static func performJSONProcessing() {
        tokenizeJSONString()
        buildAbstractSyntaxTree()
        serializeToObjects()
    }

    @inline(never)
    private static func tokenizeJSONString() {
        let json = String(repeating: "{\"key\":\"value\"},", count: 200)
        for char in json {
            let _ = char.isLetter || char.isPunctuation
        }
    }

    @inline(never)
    private static func buildAbstractSyntaxTree() {
        parseObjectNode()
        parseArrayNode()
    }

    @inline(never)
    private static func parseObjectNode() {
        var dict: [String: Int] = [:]
        for i in 0..<500 {
            dict["key_\(i)"] = i * 2
        }
        let _ = dict.values.reduce(0, +)
    }

    @inline(never)
    private static func parseArrayNode() {
        var arrays: [[Int]] = []
        for _ in 0..<50 {
            arrays.append((0..<100).map { $0 })
        }
        let _ = arrays.flatMap { $0 }.count
    }

    @inline(never)
    private static func serializeToObjects() {
        mapJSONToModel()
        validateModelConstraints()
    }

    @inline(never)
    private static func mapJSONToModel() {
        struct TempModel { var id: Int; var name: String; var value: Double }
        var models: [TempModel] = []
        for i in 0..<200 {
            models.append(TempModel(id: i, name: "Model_\(i)", value: Double(i) * 1.5))
        }
        let _ = models.map { $0.value }.reduce(0, +)
    }

    @inline(never)
    private static func validateModelConstraints() {
        for _ in 0..<100 {
            let values = (0..<50).map { Double($0) }
            let _ = values.filter { $0 > 25 }.map { $0 * 2 }
        }
    }

    // MARK: - Image Processing

    @inline(never)
    private static func performImageProcessing() {
        decodePixelBuffer()
        applyColorTransform()
        encodeCompressedOutput()
    }

    @inline(never)
    private static func decodePixelBuffer() {
        readBitmapHeader()
        decompressPixelData()
    }

    @inline(never)
    private static func readBitmapHeader() {
        var header: [UInt8] = []
        for i in 0..<1000 {
            header.append(UInt8(truncatingIfNeeded: i))
        }
        let _ = header.prefix(54)
    }

    @inline(never)
    private static func decompressPixelData() {
        var pixels: [UInt32] = []
        for _ in 0..<2000 {
            pixels.append(arc4random())
        }
        let _ = pixels.map { $0 & 0xFF }
    }

    @inline(never)
    private static func applyColorTransform() {
        convertRGBToHSL()
        adjustSaturation()
        convertHSLToRGB()
    }

    @inline(never)
    private static func convertRGBToHSL() {
        for _ in 0..<500 {
            let r = Double.random(in: 0...1)
            let g = Double.random(in: 0...1)
            let b = Double.random(in: 0...1)
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let _ = (maxC + minC) / 2
        }
    }

    @inline(never)
    private static func adjustSaturation() {
        var values: [Double] = []
        for _ in 0..<1000 {
            values.append(Double.random(in: 0...1) * 1.2)
        }
        let _ = values.map { min(1.0, $0) }
    }

    @inline(never)
    private static func convertHSLToRGB() {
        for _ in 0..<500 {
            let h = Double.random(in: 0...360)
            let s = Double.random(in: 0...1)
            let l = Double.random(in: 0...1)
            let c = (1 - abs(2 * l - 1)) * s
            let _ = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        }
    }

    @inline(never)
    private static func encodeCompressedOutput() {
        var compressed: [UInt8] = []
        for i in 0..<3000 {
            compressed.append(UInt8(i % 256))
        }
        let _ = compressed.count
    }

    // MARK: - Database Simulation

    @inline(never)
    private static func performDatabaseSimulation() {
        parseQueryStatement()
        executeQueryPlan()
        fetchResultSet()
    }

    @inline(never)
    private static func parseQueryStatement() {
        tokenizeSQLKeywords()
        buildQueryTree()
    }

    @inline(never)
    private static func tokenizeSQLKeywords() {
        let sql = "SELECT id, name, value FROM users WHERE status = 'active' ORDER BY created_at DESC LIMIT 100"
        for _ in 0..<100 {
            let _ = sql.components(separatedBy: " ").map { $0.uppercased() }
        }
    }

    @inline(never)
    private static func buildQueryTree() {
        var tree: [String: [String]] = [:]
        for i in 0..<100 {
            tree["node_\(i)"] = (0..<5).map { "child_\($0)" }
        }
        let _ = tree.values.flatMap { $0 }.count
    }

    @inline(never)
    private static func executeQueryPlan() {
        scanTableIndex()
        joinRelatedTables()
        sortResultRows()
    }

    @inline(never)
    private static func scanTableIndex() {
        var index: [Int: String] = [:]
        for i in 0..<1000 {
            index[i] = "row_\(i)"
        }
        let _ = index.keys.filter { $0 % 2 == 0 }.count
    }

    @inline(never)
    private static func joinRelatedTables() {
        let table1 = (0..<200).map { ("id_\($0)", $0) }
        let table2 = (0..<200).map { ("id_\($0)", $0 * 2) }
        var joined: [(String, Int, Int)] = []
        for (k1, v1) in table1 {
            for (k2, v2) in table2 where k1 == k2 {
                joined.append((k1, v1, v2))
            }
        }
        let _ = joined.count
    }

    @inline(never)
    private static func sortResultRows() {
        var rows = (0..<500).map { _ in arc4random() }
        rows.sort()
        let _ = rows.first
    }

    @inline(never)
    private static func fetchResultSet() {
        var results: [[String: Any]] = []
        for i in 0..<100 {
            results.append(["id": i, "name": "Item \(i)", "active": i % 2 == 0])
        }
        let _ = results.filter { ($0["active"] as? Bool) == true }.count
    }

    // MARK: - UI Layout

    @inline(never)
    private static func performUILayoutCalculation() {
        measureTextContent()
        calculateConstraints()
        resolveLayoutPass()
    }

    @inline(never)
    private static func measureTextContent() {
        computeGlyphWidths()
        calculateLineBreaks()
    }

    @inline(never)
    private static func computeGlyphWidths() {
        let text = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 20)
        var widths: [Double] = []
        for char in text {
            widths.append(Double(char.asciiValue ?? 0) * 0.6)
        }
        let _ = widths.reduce(0, +)
    }

    @inline(never)
    private static func calculateLineBreaks() {
        let words = (0..<200).map { "word\($0)" }
        var lines: [[String]] = [[]]
        var currentWidth = 0.0
        for word in words {
            let wordWidth = Double(word.count) * 8.0
            if currentWidth + wordWidth > 300 {
                lines.append([])
                currentWidth = 0
            }
            lines[lines.count - 1].append(word)
            currentWidth += wordWidth
        }
        let _ = lines.count
    }

    @inline(never)
    private static func calculateConstraints() {
        solveLinearEquations()
        propagateConstraintChanges()
    }

    @inline(never)
    private static func solveLinearEquations() {
        var matrix: [[Double]] = []
        for i in 0..<50 {
            matrix.append((0..<50).map { j in Double(i + j) })
        }
        let _ = matrix.map { $0.reduce(0, +) }.reduce(0, +)
    }

    @inline(never)
    private static func propagateConstraintChanges() {
        var constraints: [Double] = (0..<200).map { Double($0) }
        for i in 0..<constraints.count {
            if i > 0 {
                constraints[i] = max(constraints[i], constraints[i - 1] + 10)
            }
        }
        let _ = constraints.last
    }

    @inline(never)
    private static func resolveLayoutPass() {
        layoutSubviews()
        updateDisplayList()
    }

    @inline(never)
    private static func layoutSubviews() {
        var frames: [(x: Double, y: Double, w: Double, h: Double)] = []
        for i in 0..<100 {
            frames.append((x: Double(i % 10) * 50, y: Double(i / 10) * 50, w: 45, h: 45))
        }
        let _ = frames.map { $0.w * $0.h }.reduce(0, +)
    }

    @inline(never)
    private static func updateDisplayList() {
        var displayList: [String] = []
        for i in 0..<300 {
            displayList.append("DrawRect(\(i * 10), \(i * 10), 100, 100)")
        }
        let _ = displayList.joined(separator: "\n")
    }
}
