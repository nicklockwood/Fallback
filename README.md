[![PayPal](https://img.shields.io/badge/paypal-donate-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=PE25MTMPF2YFN)
[![Build](https://github.com/nicklockwood/Fallback/actions/workflows/build.yml/badge.svg)](https://github.com/nicklockwood/Fallback/actions/workflows/build.yml)
[![Codecov](https://codecov.io/gh/nicklockwood/Fallback/graphs/badge.svg)](https://codecov.io/gh/nicklockwood/Fallback)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20|%20macOS%20|%20tvOS%20|%20Linux-lightgray.svg)](#how-do-i-install-it)
[![Swift 5.10](https://img.shields.io/badge/swift-5.10-red.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE.md)
[![Mastodon](https://img.shields.io/badge/mastodon-@nicklockwood@mastodon.social-636dff.svg)](https://mastodon.social/@nicklockwood)

# Fallback

## What is this?

Fallback is a Swift library for making `Codable` easier and more pleasant to use with uncontrolled data. It provides a property wrapper you can use to decide what happens when individual fields are missing or can't be decoded.

## Why would I want to use it?

`Codable` saves a lot of boilerplate, but provides no mechanism for versioning or adapting data. A missing property, new enum case or a boolean value sent as a string will prevent the whole object from decoding.

The standard solutions are either to make properties optional (which spoils the ergonomics of using the type in code) or to replace the the synthesized `init(from:)` method with a handwritten version (at the risk of introducing subtle bugs).

Fallback lets you specify a desired behavior individually for each missing or malformed property.

## How do I install it?

Fallback requires Swift 5.10 or later (Xcode 15.3 or later). The library has no external package dependencies. Running the tests requires Swift 6.0 or later (Xcode 16 or later).

### Option 1: Swift Package Manager

Add this to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/nicklockwood/Fallback.git", .upToNextMinor(from: "1.0.0"))
```

Then add the library product to your target's dependencies:

```swift
.product(name: "Fallback", package: "Fallback")
```

Add `import Fallback` to files that use the library.

### Option 2: Manual Installation

If you'd rather skip the package setup, you can just copy [Fallback.swift](Sources/Fallback.swift) into your project.

## How do I use it?

Choose a wrapper for each property that needs a default, then use your decoder as usual. `IfAbsent` handles missing keys and `null`, while `OnError` also handles malformed or unexpected values:

```swift
import Fallback
import Foundation

enum Priority: String, Decodable, CaseIterable {
    case low, normal, high
}

struct Settings: Decodable {
    @IfAbsent.False var notificationsEnabled: Bool
    @IfAbsent.Empty var tags: [String]
    @OnError.FirstCase var priority: Priority
}

let json = #"{"tags":["swift"],"priority":"urgent"}"#
let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))

print(settings.notificationsEnabled) // false
print(settings.tags)                 // ["swift"]
print(settings.priority)             // low
```

In this example, `notificationsEnabled` is missing, so it defaults to `false`. The tags array is decoded normally, and the unfamiliar priority value falls back to `.low`. Note that we haven't made the whole model lenient: an invalid tag would still throw a decoding error, because `tags` uses `IfAbsent` and not `@OnError`.

### Defaults

Each wrapper below is available under both namespaces, for example `@IfAbsent.Zero` or `@OnError.Zero`, except `Nil`, which is only available under `OnError`. All wrapped types must conform to `Decodable`.

| Wrapper     | Applies to                                                             | Default value     |
| ----------- | ---------------------------------------------------------------------- | ----------------- |
| `Default`   | Types conforming to [`Defaultable`](#enums-and-custom-defaults)        | `.default`        |
| `Nil`       | Optionals or `ExpressibleByNilLiteral`                                 | `nil`             |
| `Empty`     | `Emptyable` collections (`String`, `Array`, `Set`, `Dictionary`, etc.) | `""`, `[]`, `[:]` |
| `False`     | `Bool` or `ExpressibleByBooleanLiteral`                                | `false`           |
| `True`      | `Bool` or `ExpressibleByBooleanLiteral`                                | `true`            |
| `Zero`      | `AdditiveArithmetic` (`Int`, `Double`, etc.)                           | `.zero`           |
| `One`       | `ExpressibleByIntegerLiteral` (including floats)                       | `1`               |
| `FirstCase` | `CaseIterable` types (typically enums)                                 | First case        |
| `LastCase`  | `CaseIterable` types (typically enums)                                 | Last case         |

Use `OnError.Nil` when an invalid value should become `nil` instead of throwing. If you only need `nil` for missing or null values, use a normal optional property without a wrapper.

### Initializers

Giving a property an initial value doesn't set its decoding fallback:

```swift
struct Counter: Decodable {
    @IfAbsent.Zero var count: Int = 10
}

print(Counter().count) // 10

let counter = try JSONDecoder().decode(Counter.self, from: Data("{}".utf8))
print(counter.count) // 0
```

The `10` is used when you create a `Counter` without passing a count. When decoding, it's the wrapper that chooses the fallback, so a missing or null count becomes `0`.

## Collections

`Empty` supports collections that conform to `Emptyable`. This protocol extends `Collection` and requires an `init()` that creates an empty collection. Standard conformances include `String`, `Array`, `ContiguousArray`, `Dictionary`, `Set`, and Foundation's `Data`.

One thing to watch out for: the fallback applies to the whole collection. If one element can't be decoded, `OnError.Empty` replaces the lot:

```swift
struct Scores: Decodable {
    @OnError.Empty var values: [Int]
}

let json = #"{"values":[1,"invalid",3]}"#
let scores = try JSONDecoder().decode(Scores.self, from: Data(json.utf8))
print(scores.values) // []
```

The same goes for sets and dictionaries. This doesn't filter out bad elements and keep the rest. If you'd rather catch those errors, use `IfAbsent.Empty`: missing or null collections still become empty, but invalid elements cause decoding to throw.

## Enums and custom defaults

`FirstCase` and `LastCase` use the order of `allCases`. For an enum with synthesized `CaseIterable` conformance, this is the declaration order, so rearranging the cases can change the fallback.

The `IfAbsent` versions throw for unknown enum values. The `OnError` versions recover from unknown values and other decoding errors, including wrong types. If `allCases` is empty and a fallback is needed, either policy throws `DecodingError.valueNotFound`.

If you'd prefer to pick a particular case without worrying about where it appears in the enum, conform the type to `Defaultable`:

```swift
enum Role: String, Decodable, Defaultable {
    case guest, user, admin
    static let `default`: Role = .user
}

struct Account: Decodable {
    @OnError.Default var role: Role
}

let json = #"{"role":"unknown"}"#
let account = try JSONDecoder().decode(Account.self, from: Data(json.utf8))
print(account.role) // user
```

`Defaultable` can be used with any `Decodable` type, not just enums. Its default is shared by every property of that type using `IfAbsent.Default` or `OnError.Default`.

### Custom strategies

If you need a different default for one property (say, a retry count of `3`), you can define a `FallbackStrategy` and use it with `FallbackValue`:

```swift
enum ThreeAttempts: FallbackStrategy {
    typealias Value = Int

    static func fallback(codingPath: [any CodingKey]) throws -> Int { 3 }
}

struct RequestOptions: Decodable {
    @FallbackValue<ThreeAttempts, IfAbsent> var attempts: Int
}

let options = try JSONDecoder().decode(RequestOptions.self, from: Data("{}".utf8))
print(options.attempts) // 3
```

The strategy's default `decode(from:)` implementation decodes its `Value` normally. You can override it to accept other representations; it receives a `SingleValueDecodingContainer` for a present, non-null value. The policy determines whether errors from that decoding step are propagated or replaced with the fallback.

The built-in wrappers are aliases for `FallbackValue` with strategies from `FallbackValues` and either `IfAbsent` or `OnError` as their `FallbackPolicy`. Each strategy and policy combination is a distinct type, so overlapping conformances on the wrapped type don't change the selected default.

## Encoding

You can still encode your models: the wrappers conform to `Encodable` when their values do, and encode the current value directly. You won't get an extra object around each property. Defaults are encoded too, because the wrapper doesn't remember whether the value came from the input or from a fallback.

There is one difference to watch for with optionals. When Swift generates your model's `Encodable` conformance, a wrapped `nil` is encoded as `null`:

```swift
struct Record: Codable {
    @OnError.Nil var name: String?
}

let json = #"{"name":123}"#
let record = try JSONDecoder().decode(Record.self, from: Data(json.utf8))
let data = try JSONEncoder().encode(record)
print(String(decoding: data, as: UTF8.self)) // {"name":null}
```

To omit the key instead, implement `encode(to:)` on your model and call `encodeIfPresent` with the optional property's value.

Wrappers also conform to `Equatable`, `Hashable`, and `Identifiable` when their wrapped values do. You can decode wrapper types directly, or use them in arrays and generic containers.

## FAQ

### Q: Can I use a property's initial value as its decoding default?

**A:** No. In `@IfAbsent.Zero var count = 10`, the initial value is `10`, but the decoding fallback is `0`. Use `Defaultable` or a [custom strategy](#custom-strategies) to supply a different decoding default.

### Q: Can I decode strings or numbers as booleans?

**A:** `True` and `False` use normal `Bool` decoding. With JSON, that means `true` and `false`; strings such as `"true"` and numbers such as `1` cause `IfAbsent` to throw and `OnError` to use the chosen default. They aren't converted to booleans.

### Q: Can Fallback recover from malformed JSON?

**A:** It can recover from values that don't match the expected type when you use `OnError`, but the document must still be valid JSON. For example, `@OnError.False` defaults to `false` for `{"enabled":"no"}`, while `@IfAbsent.False` throws. Neither policy can fix missing quotes, brackets, or other syntax errors.

### Q: How do I use `Empty` with a custom collection?

**A:** Conform the collection to `Emptyable`, which requires an `init()` that creates an empty collection. It must also conform to `Decodable`; `Emptyable` doesn't provide decoding. Generic models using `IfAbsent.Empty` or `OnError.Empty` should constrain the collection type to `Decodable & Emptyable`.

### Q: Why doesn't a missing-key fallback work in my generic decoding helper?

**A:** Missing keys are handled by a `KeyedDecodingContainer.decode` overload for `FallbackValue`. Swift selects that overload when it generates decoding for a wrapped property. If your helper only knows the field as `T: Decodable`, it won't select that overload, so a missing key still throws. Keep the wrapper type visible at the call to `decode` if you need this behavior.

### Q: How is this different from other Codable libraries?

**A:** Fallback focuses on choosing defaults for individual properties, with an explicit choice between missing-value handling and error recovery. It uses a single source file, with no macros or external package dependencies. It doesn't replace `Codable` or require a custom decoder.

## Testing

Run the tests with Swift 6.0 or later:

```sh
swift test
```

The test suite uses Swift Testing. CI is configured to build the library with Swift 5.10, run tests with Swift 6 on macOS and Linux, and build for WebAssembly.

## License

Fallback is available under the [MIT license](LICENSE.md).
