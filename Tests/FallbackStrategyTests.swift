import Fallback
import Foundation
import Testing

@Suite("Fallback strategies")
struct FallbackStrategyTests {
    @Test("Invalid enum defaults to specified case")
    func invalidEnumValueDefaults() throws {
        struct Model: Decodable {
            @OnError.FirstCase var role: TestRole
            @OnError.LastCase var result: TestResultCode
        }

        let json = Data(#"{ "role": "superadmin" }"#.utf8)

        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.role == .user)
        #expect(model.result == .error)
    }

    @Test("Missing enum fallback throws a decoding error instead of trapping")
    func emptyCaseIterable() throws {
        enum Value: String, Decodable, CaseIterable {
            case valid
            static let allCases: [Value] = []
        }

        struct Model: Decodable {
            @OnError.LastCase var value: Value
        }

        #expect(try decodeJSON(OnError.FirstCase<Value>.self, json: #""valid""#)
            .wrappedValue == .valid)
        #expect(try decodeJSON(OnError.LastCase<Value>.self, json: #""valid""#)
            .wrappedValue == .valid)
        #expect(throws: DecodingError.self) {
            try decodeJSON(OnError.FirstCase<Value>.self, json: "null")
        }
        #expect(throws: DecodingError.self) {
            try decodeJSON(OnError.LastCase<Value>.self, json: "42")
        }
        do {
            _ = try decodeJSON(Model.self, json: "{}")
            Issue.record("Expected a missing fallback to throw")
        } catch let DecodingError.valueNotFound(_, context) {
            #expect(context.codingPath.map(\.stringValue) == ["value"])
        }
    }

    @Test("AdditiveArithmetic doesn't conflict with ExpressibleByIntegerLiteral")
    func additiveArithmeticDoesntConflictwithExpressibleByIntegerLiteral() throws {
        enum Bit: Int, Decodable, AdditiveArithmetic, ExpressibleByIntegerLiteral {
            static let zero: Self = .off

            case off, on

            init(integerLiteral: IntegerLiteralType) {
                self = integerLiteral % 2 == 0 ? .off : .on
            }

            static func + (lhs: Self, rhs: Self) -> Self {
                .init(rawValue: lhs.rawValue + rhs.rawValue)!
            }

            static func - (lhs: Self, rhs: Self) -> Self {
                .init(rawValue: lhs.rawValue - rhs.rawValue)!
            }
        }

        struct Model: Decodable {
            @OnError.One var on: Bit
            @OnError.Zero var off: Bit
        }

        let json = Data("{}".utf8)
        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.on == 1)
        #expect(model.off == 0)
    }

    @Test("Default and Zero select their own defaults")
    func defaultAndZeroRemainDistinct() throws {
        struct Angle: AdditiveArithmetic, ExpressibleByIntegerLiteral, Decodable, Defaultable {
            static let zero = Angle(degrees: 0)
            static let `default` = Angle(degrees: 180)
            var degrees: Double

            init(degrees: Double) {
                self.degrees = degrees
            }

            init(integerLiteral: IntegerLiteralType) {
                self.init(degrees: Double(integerLiteral))
            }

            static func + (lhs: Self, rhs: Self) -> Self {
                .init(degrees: lhs.degrees + rhs.degrees)
            }

            static func - (lhs: Self, rhs: Self) -> Self {
                .init(degrees: lhs.degrees - rhs.degrees)
            }
        }

        struct Model: Decodable {
            @OnError.Default var angle1: Angle
            @OnError.Zero var angle2: Angle
        }

        let json = Data("{}".utf8)
        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.angle1 == .default)
        #expect(model.angle2 == .zero)
    }

    @Test("Default, FirstCase, and LastCase select their own defaults")
    func defaultAndEnumCasesRemainDistinct() throws {
        enum Role: String, CaseIterable, Decodable, Defaultable {
            static let `default`: Role = .user
            case guest, user, admin
        }

        struct Model: Decodable {
            @OnError.Default var role1: Role
            @OnError.FirstCase var role2: Role
            @OnError.LastCase var role3: Role
        }

        let json = Data("{}".utf8)
        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.role1 == .user)
        #expect(model.role2 == .guest)
        #expect(model.role3 == .admin)
    }

    @Test("Wrapper strategies remain distinct with overlapping conformances")
    func overlappingConformances() throws {
        enum Number: Int, Codable, CaseIterable, ExpressibleByIntegerLiteral, Defaultable {
            case zero, one, two, three
            static let `default`: Number = .two

            init(integerLiteral value: Int) {
                self = Number(rawValue: value)!
            }
        }

        struct Model: Codable, Hashable {
            @OnError.One var one: Number
            @OnError.FirstCase var first: Number
            @OnError.LastCase var last: Number
            @OnError.Default var custom: Number
        }

        for json in [
            "{}",
            #"{"one":null,"first":null,"last":null,"custom":null}"#,
            #"{"one":99,"first":99,"last":99,"custom":99}"#,
        ] {
            let model = try decodeJSON(Model.self, json: json)
            #expect(model.one == .one)
            #expect(model.first == .zero)
            #expect(model.last == .three)
            #expect(model.custom == .two)
            #expect(try JSONDecoder()
                .decode(Model.self, from: JSONEncoder().encode(model)) == model)
        }
    }

    @Test("IfAbsent keeps strategies distinct and preserves standard conformances")
    func overlappingStrategies() throws {
        enum Number: Int, Codable, CaseIterable, ExpressibleByIntegerLiteral {
            case zero, one, two
            init(integerLiteral value: Int) { self = Number(rawValue: value)! }
        }
        struct Model: Codable, Hashable {
            @IfAbsent.One var one: Number
            @IfAbsent.LastCase var last: Number
        }
        let model = try decodeJSON(Model.self, json: "{}")
        #expect(model.one == .one)
        #expect(model.last == .two)
        #expect(try JSONDecoder().decode(Model.self, from: JSONEncoder().encode(model)) == model)
        #expect(Set([model, model]).count == 1)
        struct Name: Codable, Identifiable, Defaultable {
            var id: String
            static let `default` = Name(id: "default")
        }
        #expect(IfAbsent.Default(wrappedValue: Name.default).id == "default")
        #expect(OnError.Default(wrappedValue: Name.default).id == "default")
    }
}
