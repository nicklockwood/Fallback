import Fallback
import Foundation
import Testing

@Suite("Codable integration")
struct CodableIntegrationTests {
    @Test("Wrappers decode valid values directly")
    func onErrorDirectDecoding() throws {
        #expect(try decodeJSON(OnError.Default<TestErrorType>.self, json: #"{"cause":"test"}"#)
            .wrappedValue == .init(cause: "test"))
        #expect(try decodeJSON(OnError.Nil<String?>.self, json: #""hello""#)
            .wrappedValue == "hello")
        #expect(try decodeJSON(OnError.Empty<String>.self, json: #""hello""#)
            .wrappedValue == "hello")
        #expect(try decodeJSON(OnError.Empty<[Int]>.self, json: "[1,2]").wrappedValue == [1, 2])
        #expect(try decodeJSON(OnError.Empty<Set<Int>>.self, json: "[1,2,1]").wrappedValue == [
            1,
            2,
        ])
        #expect(try decodeJSON(OnError.Empty<[String: Int]>.self, json: #"{"a":1}"#)
            .wrappedValue == ["a": 1])
        #expect(try decodeJSON(OnError.False<Bool>.self, json: "true").wrappedValue)
        #expect(try !decodeJSON(OnError.True<Bool>.self, json: "false").wrappedValue)
        #expect(try decodeJSON(OnError.Zero<Int>.self, json: "42").wrappedValue == 42)
        #expect(try decodeJSON(OnError.One<Double>.self, json: "2.5").wrappedValue == 2.5)
        #expect(try decodeJSON(OnError.FirstCase<TestRole>.self, json: #""admin""#)
            .wrappedValue == .admin)
        #expect(try decodeJSON(OnError.LastCase<TestRole>.self, json: #""user""#)
            .wrappedValue == .user)
    }

    @Test("Wrappers use defaults when decoded directly", arguments: ["null", "[]", "{}"])
    func directDecodingDefaults(json: String) throws {
        #expect(try decodeJSON(OnError.Default<TestErrorType>.self, json: json)
            .wrappedValue == .default)
        #expect(try decodeJSON(OnError.Nil<String?>.self, json: json).wrappedValue == nil)
        #expect(try decodeJSON(OnError.Empty<String>.self, json: json).wrappedValue.isEmpty)
        #expect(try decodeJSON(OnError.Empty<[Int]>.self, json: json).wrappedValue.isEmpty)
        #expect(try decodeJSON(OnError.Empty<Set<Int>>.self, json: json).wrappedValue.isEmpty)
        #expect(try decodeJSON(OnError.Empty<[String: Int]>.self, json: json).wrappedValue.isEmpty)
        #expect(try !decodeJSON(OnError.False<Bool>.self, json: json).wrappedValue)
        #expect(try decodeJSON(OnError.True<Bool>.self, json: json).wrappedValue)
        #expect(try decodeJSON(OnError.Zero<Int>.self, json: json).wrappedValue == 0)
        #expect(try decodeJSON(OnError.One<Double>.self, json: json).wrappedValue == 1)
        #expect(try decodeJSON(OnError.FirstCase<TestRole>.self, json: json).wrappedValue == .user)
        #expect(try decodeJSON(OnError.LastCase<TestRole>.self, json: json).wrappedValue == .guest)
    }

    @Test("IfAbsent works with direct, generic, and unkeyed decoding")
    func ifAbsentDirectDecoding() throws {
        struct Box<T: Decodable>: Decodable { var value: T }
        #expect(try decodeJSON(IfAbsent.Zero<Int>.self, json: "42").wrappedValue == 42)
        #expect(try decodeJSON(IfAbsent.Zero<Int>.self, json: "null").wrappedValue == 0)
        #expect(try decodeJSON(Box<IfAbsent.Zero<Int>>.self, json: #"{"value":42}"#).value
            .wrappedValue == 42)
        #expect(try decodeJSON([IfAbsent.One<Int>].self, json: "[2,null,3]")
            .map(\.wrappedValue) == [
                2,
                1,
                3,
            ])
        #expect(throws: DecodingError.self) {
            try decodeJSON(Box<IfAbsent.Zero<Int>>.self, json: #"{"value":"bad"}"#)
        }
        #expect(throws: DecodingError.self) {
            try decodeJSON([IfAbsent.One<Int>].self, json: #"[2,"bad",3]"#)
        }
    }

    @Test("Wrappers decode through generic containers and arrays")
    func genericDecoding() throws {
        struct Box<T: Codable>: Codable {
            var value: T
        }

        let box = try decodeJSON(Box<OnError.Zero<Int>>.self, json: #"{"value":"bad"}"#)
        #expect(box.value.wrappedValue == 0)
        let array = try decodeJSON([OnError.Zero<Int>].self, json: #"[1,"bad",null,3]"#)
        #expect(array.map(\.wrappedValue) == [1, 0, 0, 3])
    }

    @Test("Wrappers preserve JSONDecoder data and date strategies")
    func decoderStrategies() throws {
        struct Model: Decodable {
            @OnError.Empty var data: Data
            @OnError.Nil var date: Date?
        }

        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .base64
        decoder.dateDecodingStrategy = .secondsSince1970
        let model = try decoder.decode(Model.self, from: Data(#"{"data":"aGk=","date":123}"#.utf8))
        #expect(model.data == Data("hi".utf8))
        #expect(model.date == Date(timeIntervalSince1970: 123))
        #expect(try decoder.decode(OnError.Empty<Data>.self, from: Data(#""aGk=""#.utf8))
            .wrappedValue == model.data)
        #expect(try decoder.decode(OnError.Nil<Date?>.self, from: Data("123".utf8))
            .wrappedValue == model.date)
    }

    @Test("All wrappers preserve flat encoding and value conformances")
    func wrapperRoundTrips() throws {
        func check<T: Codable & Hashable>(_ value: T, json: String) throws {
            let data = try JSONEncoder().encode(value)
            #expect(String(decoding: data, as: UTF8.self) == json)
            #expect(try JSONDecoder().decode(T.self, from: data) == value)
            #expect(Set([value, value]).count == 1)
        }

        try check(OnError.Default(wrappedValue: TestErrorType.default), json: #"{"cause":"fubar"}"#)
        try check(OnError.Nil<String?>(wrappedValue: nil), json: "null")
        try check(OnError.Empty(wrappedValue: [1, 2]), json: "[1,2]")
        try check(OnError.False(wrappedValue: true), json: "true")
        try check(OnError.True(wrappedValue: false), json: "false")
        try check(OnError.Zero(wrappedValue: 42), json: "42")
        try check(OnError.One(wrappedValue: 2), json: "2")
        try check(OnError.FirstCase(wrappedValue: TestRole.admin), json: #""admin""#)
        try check(OnError.LastCase(wrappedValue: TestRole.user), json: #""user""#)
    }

    @Test("Fallback @propertyWrapper conforms to standard protocols")
    func fallbackWrapperConformsToProtocols() throws {
        struct Name: Identifiable, Codable, Hashable, Defaultable {
            static let `default` = Name(id: "Alice")

            var id: String
        }

        struct Model: Codable, Hashable {
            @OnError.Zero var count: Int = 10
            @OnError.True var bool: Bool = false
            @OnError.Default var name: Name = .init(id: "Bob")
        }

        let json = try JSONEncoder().encode(Model())
        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model == Model())
    }
}
