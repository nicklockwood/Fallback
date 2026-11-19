import Fallback
import Foundation
import Testing

@Suite("Decoding policies")
struct DecodingPolicyTests {
    enum Role: String, Codable, CaseIterable, Defaultable {
        case guest, user, admin
        static let `default`: Role = .user
    }

    struct AbsentModel: Decodable {
        @IfAbsent.Default var role: Role
        var optional: String?
        @IfAbsent.Empty var string: String
        @IfAbsent.Empty var array: [Int]
        @IfAbsent.Empty var set: Set<Int>
        @IfAbsent.Empty var dictionary: [String: Int]
        @IfAbsent.False var disabled: Bool
        @IfAbsent.True var enabled: Bool
        @IfAbsent.Zero var total: Int
        @IfAbsent.One var scale: Double
        @IfAbsent.FirstCase var first: Role
        @IfAbsent.LastCase var last: Role
    }

    struct OnErrorModel: Decodable {
        @OnError.False var falsy: Bool
        @OnError.True var truthy: Bool
        @OnError.Zero var int: Int
        @OnError.Zero var double: Double
        @OnError.One var scale: Double
        @OnError.Empty var string: String
        @OnError.Empty var array: [String]
        @OnError.Empty var dict: [String: Int]
        @OnError.FirstCase var result: TestResultCode
        @OnError.LastCase var role: TestRole
        @OnError.Default var error: TestErrorType
        @OnError.Nil var optional: String?
    }

    @Test("IfAbsent preserves valid fields")
    func validValues() throws {
        let model = try decodeJSON(
            AbsentModel.self,
            json: #"{"role":"admin","optional":"value","string":"text","array":[1,2],"set":[1,2],"dictionary":{"a":1},"disabled":true,"enabled":false,"total":42,"scale":2.5,"first":"user","last":"guest"}"#
        )
        #expect(model.role == .admin)
        #expect(model.optional == "value")
        #expect(model.string == "text")
        #expect(model.array == [1, 2])
        #expect(model.set == [1, 2])
        #expect(model.dictionary == ["a": 1])
        #expect(model.disabled)
        #expect(!model.enabled)
        #expect(model.total == 42)
        #expect(model.scale == 2.5)
        #expect(model.first == .user)
        #expect(model.last == .guest)
    }

    @Test("IfAbsent supplies defaults for missing and null fields", arguments: [
        "{}",
        #"{"role":null,"optional":null,"string":null,"array":null,"set":null,"dictionary":null,"disabled":null,"enabled":null,"total":null,"scale":null,"first":null,"last":null}"#,
    ])
    func absentDefaults(json: String) throws {
        let model = try decodeJSON(AbsentModel.self, json: json)
        #expect(model.role == .user)
        #expect(model.optional == nil)
        #expect(model.string.isEmpty)
        #expect(model.array.isEmpty)
        #expect(model.set.isEmpty)
        #expect(model.dictionary.isEmpty)
        #expect(!model.disabled)
        #expect(model.enabled)
        #expect(model.total == 0)
        #expect(model.scale == 1)
        #expect(model.first == .guest)
        #expect(model.last == .admin)
    }

    @Test("IfAbsent rejects invalid fields", arguments: [
        #"{"role":"unknown"}"#,
        #"{"optional":42}"#,
        #"{"string":false}"#,
        #"{"array":[1,"bad",3]}"#,
        #"{"set":[1,"bad",3]}"#,
        #"{"dictionary":{"a":1,"b":"bad"}}"#,
        #"{"disabled":0}"#,
        #"{"enabled":"true"}"#,
        #"{"total":"1"}"#,
        #"{"scale":false}"#,
        #"{"first":"unknown"}"#,
        #"{"last":42}"#,
    ])
    func invalidValues(json: String) throws {
        #expect(throws: DecodingError.self) {
            try decodeJSON(AbsentModel.self, json: json)
        }
    }

    @Test("Valid properties are unchanged")
    func validPropertiesUnchanged() throws {
        let json = Data("""
        {
          "falsy": true,
          "truthy": false,
          "int": 42,
          "double": 3.14,
          "scale": 2,
          "string": "hello",
          "array": ["a", "b"],
          "dict": { "x": 1, "y": 2 },
          "result": -1,
          "role": "admin",
          "error": { "cause": "pebkac" },
          "optional": "present!"
        }
        """.utf8)

        let model = try JSONDecoder().decode(OnErrorModel.self, from: json)
        #expect(model.falsy == true)
        #expect(model.truthy == false)
        #expect(model.int == 42)
        #expect(model.double == 3.14)
        #expect(model.scale == 2)
        #expect(model.string == "hello")
        #expect(model.array == ["a", "b"])
        #expect(model.dict == ["x": 1, "y": 2])
        #expect(model.result == .error)
        #expect(model.role == .admin)
        #expect(model.error == .init(cause: "pebkac"))
        #expect(model.optional == "present!")
    }

    @Test("Missing values use defaults")
    func missingValuesUseDefaults() throws {
        let json = Data("{}".utf8)

        let model = try JSONDecoder().decode(OnErrorModel.self, from: json)
        #expect(model.falsy == false)
        #expect(model.truthy == true)
        #expect(model.int == 0)
        #expect(model.double == 0)
        #expect(model.scale == 1)
        #expect(model.string == "")
        #expect(model.array == [])
        #expect(model.dict == [:])
        #expect(model.result == .success)
        #expect(model.role == .guest)
        #expect(model.error == .default)
        #expect(model.optional == nil)
    }

    @Test("Null values use defaults")
    func nullValuesUseDefaults() throws {
        let json = Data("""
        {
          "falsy": null,
          "truthy": null,
          "int": null,
          "double": null,
          "scale": null,
          "string": null,
          "array": null,
          "dict": null,
          "result": null,
          "role": null,
          "error": null,
          "optional": null
        }
        """.utf8)

        let model = try JSONDecoder().decode(OnErrorModel.self, from: json)
        #expect(model.falsy == false)
        #expect(model.truthy == true)
        #expect(model.int == 0)
        #expect(model.double == 0)
        #expect(model.scale == 1)
        #expect(model.string == "")
        #expect(model.array == [])
        #expect(model.dict == [:])
        #expect(model.result == .success)
        #expect(model.role == .guest)
        #expect(model.error == .default)
        #expect(model.optional == nil)
    }

    @Test("Invalid properties use defaults")
    func invalidPropertiesUseDefaults() throws {
        let json = Data("""
        {
          "falsy": "negative",
          "truthy": "positive",
          "string": 7,
          "int": false,
          "double": "red",
          "scale": "huge!",
          "array": 42,
          "dict": [false],
          "role": ["bad"],
          "result": {},
          "error": false,
          "optional": 5
        }
        """.utf8)

        let model = try JSONDecoder().decode(OnErrorModel.self, from: json)
        #expect(model.falsy == false)
        #expect(model.truthy == true)
        #expect(model.int == 0)
        #expect(model.double == 0)
        #expect(model.scale == 1)
        #expect(model.string == "")
        #expect(model.array == [])
        #expect(model.dict == [:])
        #expect(model.result == .success)
        #expect(model.role == .guest)
        #expect(model.error == .default)
        #expect(model.optional == nil)
    }

    @Test("Uses Nil default for incorrect types")
    func onErrorNil() throws {
        struct Model: Decodable {
            @OnError.Nil var bool: Bool?
            @OnError.Nil var int: Int?
            @OnError.Nil var double: Double?
            @OnError.Nil var string: String?
            @OnError.Nil var array: [String]?
            @OnError.Nil var dict: [String: Int]?
            @OnError.Nil var role: TestRole?
            @OnError.Nil var result: TestResultCode?
            @OnError.Nil var error: TestErrorType?
            @OnError.Nil var optional: String?
        }

        let json = Data("""
        {
          "bool": "negative",
          "string": 7,
          "int": false,
          "double": "red",
          "array": 42,
          "dict": [false],
          "role": ["bad"],
          "result": {},
          "error": false,
          "optional": 5
        }
        """.utf8)

        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.bool == nil)
        #expect(model.int == nil)
        #expect(model.double == nil)
        #expect(model.string == nil)
        #expect(model.array == nil)
        #expect(model.dict == nil)
        #expect(model.result == nil)
        #expect(model.role == nil)
        #expect(model.error == nil)
        #expect(model.optional == nil)
    }

    @Test("Null consistently uses the fallback even for types that can decode null")
    func nullUsesFallback() throws {
        enum Value: String, Decodable, Defaultable {
            case fallback, decodedNull
            static let `default`: Value = .fallback

            init(from _: any Decoder) throws {
                self = .decodedNull
            }
        }

        struct Model: Decodable {
            @OnError.Default var value: Value
        }

        #expect(try decodeJSON(Value.self, json: "null") == .decodedNull)
        #expect(try decodeJSON(OnError.Default<Value>.self, json: "null").wrappedValue == .fallback)
        #expect(try decodeJSON(Model.self, json: #"{"value":null}"#).value == .fallback)
    }

    @Test("IfAbsent preserves custom errors while OnError recovers")
    func customErrors() throws {
        enum Failure: Error { case invalid }
        struct Value: Decodable, Defaultable, Equatable {
            static let `default` = Value()
            init() {}
            init(from _: any Decoder) throws { throw Failure.invalid }
        }
        struct Strict: Decodable { @IfAbsent.Default var value: Value }
        struct Lenient: Decodable { @OnError.Default var value: Value }
        #expect(throws: Failure.invalid) { try decodeJSON(Strict.self, json: #"{"value":{}}"#) }
        #expect(try decodeJSON(Lenient.self, json: #"{"value":{}}"#).value == .default)
        #expect(try decodeJSON(Strict.self, json: "{}").value == .default)
    }
}
