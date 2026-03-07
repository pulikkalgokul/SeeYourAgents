import Foundation

// MARK: - Top-Level JSONL Record

struct TranscriptRecord: Decodable {
    let type: String
    let message: TranscriptMessage?
    let subtype: String?
    let parentToolUseID: String?
    let data: ProgressData?

    enum CodingKeys: String, CodingKey {
        case type, message, subtype
        case parentToolUseID = "parentToolUseId"
        case data
    }
}

// MARK: - Message

struct TranscriptMessage: Decodable {
    let role: String?
    let content: MessageContent?
}

/// Content can be a plain string or an array of content blocks.
enum MessageContent: Decodable {
    case string(String)
    case blocks([ContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            self = .blocks(blocks)
        } else {
            self = .string("")
        }
    }

    var blocks: [ContentBlock] {
        switch self {
        case .string: return []
        case .blocks(let b): return b
        }
    }
}

// MARK: - Content Blocks

struct ContentBlock: Decodable {
    let type: String
    let id: String?
    let name: String?
    let input: [String: AnyCodable]?
    let toolUseId: String?
    let content: ToolResultContent?

    enum CodingKeys: String, CodingKey {
        case type, id, name, input
        case toolUseId = "tool_use_id"
        case content
    }
}

/// Tool result content can be string or array of blocks.
enum ToolResultContent: Decodable {
    case string(String)
    case blocks([ContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            self = .blocks(blocks)
        } else {
            self = .string("")
        }
    }
}

// MARK: - Progress Data (for sub-agent tracking)

struct ProgressData: Decodable {
    let type: String?
    let message: TranscriptMessage?
}

// MARK: - Flexible JSON Value

/// A type-erased Decodable wrapper for arbitrary JSON values.
struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            value = str
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }

    var stringValue: String? { value as? String }
}
