//
//  ExpectDSL.swift
//  Scout
//
//  Created by Brian Gerstle on 6/12/19.
//  Copyright © 2019 Brian Gerstle. All rights reserved.
//

import Foundation

// DSL for setting expectations on a mock, either as member vars or function calls.
@dynamicMemberLookup
public struct ExpectDSL {
    let mock: Mock

    public struct MemberActionDSL {
        let mock: Mock
        let member: String

        @discardableResult
        public func toReturn(_ value: Any?) -> MemberActionDSL {
            mock.append(expectation: SingleValueExpectation(value: value), for: member)
            return self
        }

        @discardableResult
        public func toReturn<S: Sequence>(valuesFrom values: S) -> MemberActionDSL where S.Element: Any {
            mock.append(expectation: MultiValueExpectation(values: Array(values)), for: member)
            return self
        }

        public var and:  MemberActionDSL {
            return self
        }
    }

    @dynamicCallable
    public class FuncArgRecorder {
        let mock: Mock
        let funcName: String

        // Declared as var because `args` are set after the recorder is returned as a
        // dynamicMemmber of ExpectDSL.
        var argMatchers: [Matcher]! = nil

        init(mock: Mock, funcName: String) {
            self.mock = mock
            self.funcName = funcName
        }

        internal func checkArgs(args: [Any?]) {
            fail(unless: args.count == self.argMatchers.count,
                 "Expected \(self.argMatchers.count) arguments, but got \(args.count)")
            let mistmatchedArgsAndMatchers = zip(args, self.argMatchers).filter { (arg, matcher) in
                return !matcher.matches(arg: arg)
            }
            fail(unless: mistmatchedArgsAndMatchers.count == 0,
                 "Arguments to \(funcName) didn't match: \(mistmatchedArgsAndMatchers)")
        }

        public struct FuncDSL {
            let mock: Mock
            let argRecorder: FuncArgRecorder

            @discardableResult
            public func toReturn(_ value: Any?) -> FuncDSL {
                return andDo { args in
                    value
                }
            }

            // TODO: use some code generator to make polyvariadic version of `andDo` which
            // constrains its type parameters to Equatable? Or, some sort of AnyEquatable
            // wrapper that allows for comparison?
            @discardableResult
            public func andDo(_ block: @escaping ([Any?]) -> Any?) -> FuncDSL {
                mock.append(expectation: FuncExpectation { args in
                    self.argRecorder.checkArgs(args: args)
                    return block(args)
                }, for: argRecorder.funcName)
                return self
            }
        }

        public func dynamicallyCall(withArguments matchers: [Matcher]) -> FuncDSL {
            self.argMatchers = matchers
            return FuncDSL(mock: mock, argRecorder: self)
        }
    }

    public subscript(dynamicMember member: String) -> MemberActionDSL {
        get {
            return MemberActionDSL(mock: mock, member: member)
        }
    }

    public subscript(dynamicMember member: String) -> FuncArgRecorder {
        get {
            return FuncArgRecorder(mock: mock, funcName: member)
        }
    }
}

public protocol Matcher {
    func matches(arg: Any?) -> Bool
}

func equalTo<T: Equatable>(_ value: T?) -> Matcher {
    return EqualityMatcher(value: value)
}

public class EqualityMatcher<T: Equatable>: Matcher, CustomStringConvertible {
    let value: T?

    init(value: T?) {
        self.value = value
    }

    public func matches(arg: Any?) -> Bool {
        return value == nil && arg == nil || (arg as? T) == value
    }

    public var description: String {
        return "Equal to \(String(describing: value))"
    }
}

class SingleValueExpectation : Expectation {
    private var consumed: Bool = false
    let value: Any?

    init(value: Any?) {
        self.value = value
    }

    func hasNext() -> Bool {
        return !consumed
    }

    func nextValue() -> Any? {
        consumed = true
        return value
    }
}

class MultiValueExpectation : Expectation {
    var values: [Any] = []

    init(values: [Any]) {
        self.values = values
    }

    func hasNext() -> Bool {
        return values.count > 0
    }

    func nextValue() -> Any? {
        return values.removeFirst()
    }
}

class PersistentVarValue : Expectation {
    let value: Any

    init(value: Any) {
        self.value = value
    }

    func hasNext() -> Bool {
        return true
    }

    func nextValue() -> Any? {
        return value
    }
}

class GetterExpectation : Expectation {
    let getter: () -> Any?

    init(getter: @escaping () -> Any?) {
        self.getter = getter
    }

    func hasNext() -> Bool {
        return true
    }

    func nextValue() -> Any? {
        return getter()
    }
}

class FuncExpectation: Expectation {
    let action: ([Any?]) -> Any?

    init(action: @escaping ([Any?]) -> Any?) {
        self.action = action
    }

    func hasNext() -> Bool {
        return false
    }

    func nextValue() -> Any? {
        return action
    }
}

// Sugar for any test class that has an embedded mock to add the "expect" DSL.
public protocol Mockable {
    var mock: Mock { get }
}

public extension Mockable {
    var expect: ExpectDSL {
        return ExpectDSL(mock: mock)
    }
}
