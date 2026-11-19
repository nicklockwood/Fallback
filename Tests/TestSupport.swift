import Fallback
import Foundation

/// CaseIterable Int enum
enum TestResultCode: Int, CaseIterable, Decodable {
    case success = 0
    case error = -1
}

/// CaseIterable String enum
enum TestRole: String, CaseIterable, Codable {
    case user, admin, guest
}

/// Custom defaultable type
struct TestErrorType: Defaultable, Codable, Hashable {
    static let `default` = TestErrorType(cause: "fubar")
    let cause: String
}

func decodeJSON<T: Decodable>(_ type: T.Type, json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}
