//
//  ScoutTests.swift
//  ScoutTests
//
//  Created by Brian Gerstle on 6/10/19.
//  Copyright © 2019 Brian Gerstle. All rights reserved.
//

import XCTest
@testable import Scout

protocol Example {
    var foo: String { get }
    var bar: Int { get }

    func baz() -> String
}

class MockExample : Example, Mockable {
    let mock = Mock()

    var foo: String {
        get {
            return mock.get.foo
        }
    }

    var bar: Int {
        get {
            return mock.get.bar
        }
    }

    func baz() -> String {
        // for some reason, swiftc segfaults if dynamicallyCall() is generic. if it was
        // generic, you wouldn't need the `as! String`, but at least you don't need to cast
        // the function type for baz...
        return mock.call.baz() as! String
    }

    func buz(_ value: Int) {
        mock.call.buz(value)
    }
}

class ScoutTests: XCTestCase {
    var mockExample: MockExample!
    var assertTestFailureBlock: ((String) -> Void)! = nil

    override func setUp() {
        mockExample = MockExample()
        continueAfterFailure = false
        assertTestFailureBlock = nil
    }

    override func tearDown() {
        mockExample = nil
    }

    override func recordFailure(withDescription description: String,
                                inFile filePath: String,
                                atLine lineNumber: Int,
                                expected: Bool) {
        if let block = assertTestFailureBlock {
            assertTestFailureBlock = nil
            block(description)
        } else {
            super.recordFailure(withDescription: description,
                                inFile: filePath,
                                atLine: lineNumber,
                                expected: expected)
        }
    }

    func captureTestFailure(_ expression: @autoclosure () -> Void,
                            _ assertion: @escaping (String) -> Void) {
        assertTestFailureBlock = assertion
        expression()
    }

    func testReturningVarForMember() {
        mockExample
            .expect.foo
            .toReturn("bar")
            .and.toReturn("baz")

        XCTAssertEqual(mockExample.foo, "bar")
        XCTAssertEqual(mockExample.foo, "baz")
    }

    func testReturningValuesFromSequence() {
        let range = Array(0..<5)
        mockExample.expect.bar.toReturn(valuesFrom: range)

        XCTAssertEqual(range.map { _ in mockExample.bar }, [0,1,2,3,4])
    }

    func testReturningValueFromFunctionCall() {
        mockExample.expect.baz().andDo { _ in "baz return" }
        XCTAssertEqual(mockExample.baz(), "baz return")
    }

    func testWrongNumberOfArgs() {
        mockExample.expect.buz(equalTo(0)).andDo { _ in }

        captureTestFailure(mockExample.buz(1)) { failureDescription in
            XCTAssert(failureDescription.contains("Arguments to buz didn't match"))
        }
    }
}
