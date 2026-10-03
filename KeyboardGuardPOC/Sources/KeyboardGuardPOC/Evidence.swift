import Foundation
import KeyboardCore

struct EvidenceEvent: Codable {
    var timestamp = ISO8601DateFormatter().string(from: Date())
    var runID: String
    var kind: String
    var state: SessionState?
    var code: Int32?
    var codeHex: String?
    var message: String?
    var device: KeyboardDevice?
    var classification: Classification?
    var source = "program"

    init(runID: String, kind: String, state: SessionState? = nil, code: Int32? = nil,
         message: String? = nil, device: KeyboardDevice? = nil, source: String = "program") {
        self.runID = runID; self.kind = kind; self.state = state; self.code = code
        self.codeHex = code.map { String(format: "0x%08x", UInt32(bitPattern: $0)) }
        self.message = message; self.device = device; self.classification = device?.classification
        self.source = source
    }

    var jsonLine: Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = try! encoder.encode(self); data.append(0x0a); return data
    }
}

func emit(_ event: EvidenceEvent) { try? FileHandle.standardOutput.write(contentsOf: event.jsonLine) }
