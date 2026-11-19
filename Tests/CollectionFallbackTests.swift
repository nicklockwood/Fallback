import Fallback
import Foundation
import Testing

@Suite("Collection fallbacks")
struct CollectionFallbackTests {
    @Test("Valid sets are unchanged")
    func validSetsUnchanged() throws {
        struct Model: Decodable {
            @OnError.Empty var tags: Set<String>
        }

        let json = Data(#"{"tags": ["a", "b", "a"]}"#.utf8)
        let model = try JSONDecoder().decode(Model.self, from: json)
        #expect(model.tags == ["a", "b"])
    }

    @Test("Missing, null, invalid, and empty sets decode as empty", arguments: [
        #"{}"#,
        #"{"tags": null}"#,
        #"{"tags": 42}"#,
        #"{"tags": ["a", 42]}"#,
        #"{"tags": []}"#,
    ])
    func emptySets(json: String) throws {
        struct Model: Decodable {
            @OnError.Empty var tags: Set<String>
        }

        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        #expect(model.tags.isEmpty)
    }

    @Test("Emptyable supports generic models and custom collections")
    func emptyableCollections() throws {
        struct Values: Emptyable, Decodable {
            var elements: [Int] = []
            init() {}
            var startIndex: Int {
                elements.startIndex
            }

            var endIndex: Int {
                elements.endIndex
            }

            func index(after i: Int) -> Int { elements.index(after: i) }
            subscript(index: Int) -> Int { elements[index] }
        }

        struct Model<T: Decodable & Emptyable>: Decodable {
            @OnError.Empty var values: T
        }

        #expect(try decodeJSON(Model<[Int]>.self, json: "{}").values.isEmpty)
        #expect(try decodeJSON(Model<Set<Int>>.self, json: #"{"values":[1,2]}"#).values == [1, 2])
        #expect(try decodeJSON(Model<Values>.self, json: "{}").values.isEmpty)
        #expect(try decodeJSON(Model<Values>.self, json: #"{"values":{"elements":[1,2]}}"#).values
            .elements == [
                1,
                2,
            ])
        #expect(try decodeJSON(OnError.Empty<ContiguousArray<Int>>.self, json: "null").wrappedValue
            .isEmpty)
    }
}
