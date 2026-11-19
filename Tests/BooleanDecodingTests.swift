import Fallback
import Foundation
import Testing

@Suite("Boolean decoding")
struct BooleanDecodingTests {
    struct BooleanModel: Codable, Hashable {
        @IfAbsent.False var absentFalse: Bool
        @IfAbsent.True var absentTrue: Bool
        @OnError.False var errorFalse: Bool
        @OnError.True var errorTrue: Bool
    }

    @Test(
        "True and False retain strict boolean decoding",
        arguments: ["0", "1", #""false""#, #""true""#]
    )
    func strictBooleans(json: String) throws {
        #expect(throws: DecodingError.self) { try decodeJSON(IfAbsent.False<Bool>.self, json: json) }
        #expect(throws: DecodingError.self) { try decodeJSON(IfAbsent.True<Bool>.self, json: json) }
        #expect(try !decodeJSON(OnError.False<Bool>.self, json: json).wrappedValue)
        #expect(try decodeJSON(OnError.True<Bool>.self, json: json).wrappedValue)
    }

    @Test("True and False preserve boolean values", arguments: [
        ("true", true), ("false", false),
    ])
    func booleanValues(json: String, expected: Bool) throws {
        let model = try decodeJSON(BooleanModel.self, json: """
        {"absentFalse":\(json),"absentTrue":\(json),"errorFalse":\(json),"errorTrue":\(json)}
        """)
        #expect(model.absentFalse == expected)
        #expect(model.absentTrue == expected)
        #expect(model.errorFalse == expected)
        #expect(model.errorTrue == expected)
        #expect(try decodeJSON(IfAbsent.False<Bool>.self, json: json).wrappedValue == expected)
        #expect(try decodeJSON(IfAbsent.True<Bool>.self, json: json).wrappedValue == expected)
        #expect(try decodeJSON(OnError.False<Bool>.self, json: json).wrappedValue == expected)
        #expect(try decodeJSON(OnError.True<Bool>.self, json: json).wrappedValue == expected)
        let encoded = try JSONEncoder().encode(model)
        #expect(try JSONDecoder().decode(BooleanModel.self, from: encoded) == model)
        #expect(Set([model, model]).count == 1)
        let fields = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(fields.count == 4)
        #expect(fields.values.allSatisfy { ($0 as? Bool) == expected })
        #expect(try String(
            decoding: JSONEncoder().encode(OnError.False(wrappedValue: expected)),
            as: UTF8.self
        ) == (expected ? "true" : "false"))
    }

    @Test("True and False default for missing and null values", arguments: [
        "{}", #"{"absentFalse":null,"absentTrue":null,"errorFalse":null,"errorTrue":null}"#,
    ])
    func booleanDefaults(json: String) throws {
        let model = try decodeJSON(BooleanModel.self, json: json)
        #expect(!model.absentFalse)
        #expect(model.absentTrue)
        #expect(!model.errorFalse)
        #expect(model.errorTrue)
        #expect(try !decodeJSON(IfAbsent.False<Bool>.self, json: "null").wrappedValue)
        #expect(try decodeJSON(IfAbsent.True<Bool>.self, json: "null").wrappedValue)
        #expect(try !decodeJSON(OnError.False<Bool>.self, json: "null").wrappedValue)
        #expect(try decodeJSON(OnError.True<Bool>.self, json: "null").wrappedValue)
    }

    @Test("Invalid booleans follow the selected error policy", arguments: [
        "0", "1", "0.0", "1.0", "1e0", #""0""#, #""1""#,
        #""true""#, #""false""#, #""TRUE""#, #""FaLsE""#,
        "2", "-1", "0.5", "1.5", "[]", "{}", #""""#, #""yes""#, #""no""#,
        #""on""#, #""off""#, #"" true ""#, #""2""#, #""1.0""#,
    ])
    func invalidBooleans(json: String) throws {
        #expect(try !decodeJSON(OnError.False<Bool>.self, json: json).wrappedValue)
        #expect(try decodeJSON(OnError.True<Bool>.self, json: json).wrappedValue)
        #expect(throws: DecodingError.self) { try decodeJSON(IfAbsent.False<Bool>.self, json: json) }
        #expect(throws: DecodingError.self) { try decodeJSON(IfAbsent.True<Bool>.self, json: json) }
        #expect(throws: DecodingError.self) {
            try decodeJSON(BooleanModel.self, json: "{\"absentFalse\":\(json)}")
        }
        #expect(throws: DecodingError.self) {
            try decodeJSON(BooleanModel.self, json: "{\"absentTrue\":\(json)}")
        }
        let model = try decodeJSON(
            BooleanModel.self,
            json: "{\"errorFalse\":\(json),\"errorTrue\":\(json)}"
        )
        #expect(!model.errorFalse)
        #expect(model.errorTrue)
    }

    @Test("Boolean decoding errors preserve the coding path")
    func codingPath() throws {
        do {
            _ = try decodeJSON(BooleanModel.self, json: #"{"absentFalse":"invalid"}"#)
            Issue.record("Expected decoding to fail")
        } catch let DecodingError.typeMismatch(_, context) {
            #expect(context.codingPath.map(\.stringValue) == ["absentFalse"])
        }
    }
}
