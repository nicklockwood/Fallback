//
//  Fallback.swift
//  Fallback
//
//  Created by Nick Lockwood on 20/06/2025.
//  Copyright © 2025 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/Fallback
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#if canImport(Foundation)
import Foundation
#endif

/// A protocol for types that have a default value.
/// Defaultable types can be used with `@IfAbsent.Default` or `@OnError.Default`.
public protocol Defaultable {
    static var `default`: Self { get }
}

/// A collection that can be initialized with no elements.
/// Custom collections must conform to this protocol to be used with `@IfAbsent.Empty` or `@OnError.Empty`.
public protocol Emptyable: Collection {
    init()
}

extension String: Emptyable {}
extension Substring: Emptyable {}
extension Array: Emptyable {}
extension ArraySlice: Emptyable {}
extension ContiguousArray: Emptyable {}
extension Dictionary: Emptyable {}
extension Set: Emptyable {}

#if canImport(Foundation)
extension Data: Emptyable {}
#endif

/// Use a fallback for missing keys and null values. Other decoding errors are propagated.
public enum IfAbsent: FallbackPolicy {
    public static let handlesErrors = false

    /// Fall back to the type's `default` value.
    public typealias Default<T: Decodable & Defaultable> = FallbackValue<FallbackValues.Default<T>, IfAbsent>

    /// Fall back to an empty collection.
    public typealias Empty<T: Decodable & Emptyable> = FallbackValue<FallbackValues.Empty<T>, IfAbsent>

    /// Fall back to `false`, using strict decoding.
    public typealias False<T: Decodable & ExpressibleByBooleanLiteral> = FallbackValue<FallbackValues.False<T>, IfAbsent>

    /// Fall back to `true`, using strict decoding.
    public typealias True<T: Decodable & ExpressibleByBooleanLiteral> = FallbackValue<FallbackValues.True<T>, IfAbsent>

    /// Fall back to zero.
    public typealias Zero<T: Decodable & AdditiveArithmetic> = FallbackValue<FallbackValues.Zero<T>, IfAbsent>

    /// Fall back to one.
    public typealias One<T: Decodable & ExpressibleByIntegerLiteral> = FallbackValue<FallbackValues.One<T>, IfAbsent>

    /// Fall back to the first value in `allCases`.
    public typealias FirstCase<T: Decodable & CaseIterable> = FallbackValue<FallbackValues.FirstCase<T>, IfAbsent>

    /// Fall back to the last value in `allCases`.
    public typealias LastCase<T: Decodable & CaseIterable> = FallbackValue<FallbackValues.LastCase<T>, IfAbsent>
}

/// Use a fallback for missing keys, null values, and any error decoding the wrapped value.
public enum OnError: FallbackPolicy {
    public static let handlesErrors = true

    /// Fall back to the type's `default` value.
    public typealias Default<T: Decodable & Defaultable> = FallbackValue<FallbackValues.Default<T>, OnError>

    /// Fall back to `nil`.
    public typealias Nil<T: Decodable & ExpressibleByNilLiteral> = FallbackValue<FallbackValues.Nil<T>, OnError>

    /// Fall back to an empty collection.
    public typealias Empty<T: Decodable & Emptyable> = FallbackValue<FallbackValues.Empty<T>, OnError>

    /// Fall back to `false`, using strict decoding.
    public typealias False<T: Decodable & ExpressibleByBooleanLiteral> = FallbackValue<FallbackValues.False<T>, OnError>

    /// Fall back to `true`, using strict decoding.
    public typealias True<T: Decodable & ExpressibleByBooleanLiteral> = FallbackValue<FallbackValues.True<T>, OnError>

    /// Fall back to zero.
    public typealias Zero<T: Decodable & AdditiveArithmetic> = FallbackValue<FallbackValues.Zero<T>, OnError>

    /// Fall back to one.
    public typealias One<T: Decodable & ExpressibleByIntegerLiteral> = FallbackValue<FallbackValues.One<T>, OnError>

    /// Fall back to the first value in `allCases`.
    public typealias FirstCase<T: Decodable & CaseIterable> = FallbackValue<FallbackValues.FirstCase<T>, OnError>

    /// Fall back to the last value in `allCases`.
    public typealias LastCase<T: Decodable & CaseIterable> = FallbackValue<FallbackValues.LastCase<T>, OnError>
}

// MARK: Shared wrapper

/// Determines whether errors decoding a present value should use the fallback.
/// Use `IfAbsent` or `OnError` for the built-in policies.
public protocol FallbackPolicy {
    static var handlesErrors: Bool { get }
}

/// Supplies a fallback value and decodes present, non-null values.
public protocol FallbackStrategy {
    associatedtype Value: Decodable
    static func fallback(codingPath: [any CodingKey]) throws -> Value
    static func decode(from container: any SingleValueDecodingContainer) throws -> Value
}

public extension FallbackStrategy {
    static func decode(from container: any SingleValueDecodingContainer) throws -> Value {
        try container.decode(Value.self)
    }
}

/// The shared implementation of the wrappers in `IfAbsent` and `OnError`.
@propertyWrapper
public struct FallbackValue<Strategy: FallbackStrategy, Policy: FallbackPolicy>: Decodable {
    public var wrappedValue: Strategy.Value

    public init(wrappedValue: Strategy.Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            if !container.decodeNil() {
                self.wrappedValue = try Strategy.decode(from: container)
                return
            }
        } catch {
            guard Policy.handlesErrors else { throw error }
        }
        self.wrappedValue = try Strategy.fallback(codingPath: decoder.codingPath)
    }
}

extension FallbackValue: Encodable where Strategy.Value: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension FallbackValue: Equatable where Strategy.Value: Equatable {}
extension FallbackValue: Hashable where Strategy.Value: Hashable {}

@available(macOS 10.15, iOS 13.0, *)
extension FallbackValue: Identifiable where Strategy.Value: Identifiable {
    public var id: Strategy.Value.ID { wrappedValue.id }
}

public extension KeyedDecodingContainer {
    func decode<S, P>(_ type: FallbackValue<S, P>.Type, forKey key: Key) throws -> FallbackValue<S, P> {
        let value: FallbackValue<S, P>?
        do {
            value = try decodeIfPresent(type, forKey: key)
        } catch {
            guard P.handlesErrors else { throw error }
            value = nil
        }
        return try value ?? .init(wrappedValue: S.fallback(codingPath: codingPath + [key]))
    }
}

// MARK: Fallback strategies

/// The distinct strategies used by the wrappers in `IfAbsent` and `OnError`.
public enum FallbackValues {
    /// Supplies the type's `default` value.
    public enum Default<T: Decodable & Defaultable>: FallbackStrategy {
        public typealias Value = T

        public static func fallback(codingPath _: [any CodingKey]) throws -> Value { T.default }
    }

    /// Supplies `nil`.
    public enum Nil<T: Decodable & ExpressibleByNilLiteral>: FallbackStrategy {
        public typealias Value = T

        public static func fallback(codingPath _: [any CodingKey]) throws -> Value { nil }
    }

    /// Supplies an empty collection.
    public enum Empty<T: Decodable & Emptyable>: FallbackStrategy {
        public typealias Value = T

        public static func fallback(codingPath _: [any CodingKey]) throws -> Value { .init() }
    }

    /// Supplies `false`, using strict decoding.
    public enum False<T: Decodable & ExpressibleByBooleanLiteral>: FallbackStrategy {
        public typealias Value = T

        public static func fallback(codingPath _: [any CodingKey]) throws -> Value { false }
    }

    /// Supplies `true`, using strict decoding.
    public enum True<T: Decodable & ExpressibleByBooleanLiteral>: FallbackStrategy {
        public typealias Value = T

        public static func fallback(codingPath _: [any CodingKey]) throws -> Value { true }
    }

    /// Supplies zero.
    public enum Zero<T: Decodable & AdditiveArithmetic>: FallbackStrategy {
        public typealias Value = T

        public static func fallback(codingPath _: [any CodingKey]) throws -> Value { .zero }
    }

    /// Supplies one.
    public enum One<T: Decodable & ExpressibleByIntegerLiteral>: FallbackStrategy {
        public typealias Value = T

        public static func fallback(codingPath _: [any CodingKey]) throws -> Value { 1 }
    }

    /// Supplies the first value in `allCases`.
    public enum FirstCase<T: Decodable & CaseIterable>: FallbackStrategy {
        public typealias Value = T

        public static func fallback(codingPath: [any CodingKey]) throws -> Value {
            guard let value = T.allCases.first else {
                throw DecodingError.valueNotFound(T.self, .init(
                    codingPath: codingPath,
                    debugDescription: "Cannot choose a fallback for \(T.self) because allCases is empty."
                ))
            }
            return value
        }
    }

    /// Supplies the last value in `allCases`.
    public enum LastCase<T: Decodable & CaseIterable>: FallbackStrategy {
        public typealias Value = T

        public static func fallback(codingPath: [any CodingKey]) throws -> Value {
            guard let value = T.allCases.lazy.map({ $0 }).last else {
                throw DecodingError.valueNotFound(T.self, .init(
                    codingPath: codingPath,
                    debugDescription: "Cannot choose a fallback for \(T.self) because allCases is empty."
                ))
            }
            return value
        }
    }
}
