//
//  CalLDSL.swift
//  Scout
//
//  Created by Brian Gerstle on 6/12/19.
//  Copyright © 2019 Brian Gerstle. All rights reserved.
//

import Foundation

// DSL for invoking expected function calls on a mock.
@dynamicMemberLookup
public struct CallDSL {
    let mock: Mock

    @dynamicCallable
    public struct MockCall {
        let mock: Mock
        let member: String

        // TODO: Make this generic once the Swift compiler stops segfaulting.
        public func dynamicallyCall(withArguments args: [Any?]) -> Any! {
            let expectationValue = mock.next(expectationFor: member)
            guard let action = expectationValue as? ([Any?]) -> Any? else {
                fatalError("Failed to cast action of function expectation for \(member)")
            }
            return action(args)
        }
    }

    public subscript(dynamicMember member: String) -> MockCall {
        get {
            return MockCall(mock: mock, member: member)
        }
    }
}