//
//  Environment+Authenticate.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 8/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LocalAuthentication
import Security
import SwiftUI

public typealias AuthenticationChallenge = (_ description: String, _ completion: @escaping (Result<Void, Error>) -> Void) -> Void

fileprivate struct UnknownError: Swift.Error { }

public struct LocalAuthentication {
    public static let deviceOwnerCheck: AuthenticationChallenge = { authenticationChallengeDescription, completion in
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                   localizedReason: authenticationChallengeDescription,
                                   reply: { (success, error) in
                                    DispatchQueue.main.async {
                                        assert(success || error != nil)
                                        completion(success ? .success(()) : .failure(error ?? UnknownError()))
                                    }
            })
        } else {
            // The logic here is to not fail to execute completion just because there is no authentication set up on the iPhone
            completion(.success(()))
        }
    }

    /// Asks for the device passcode, without trying Face ID or Touch ID first.
    ///
    /// `deviceOwnerCheck` evaluates biometry first and only falls back to the
    /// keypad once it has failed — twice, in practice. Whoever is holding the
    /// phone is often not the person it was set up for, and making them wait out
    /// two rejected face scans before they can type the code is a poor thing to
    /// do at dosing time. Insulin delivery therefore asks for the passcode
    /// directly. Settings keep `deviceOwnerCheck`, where biometry is a
    /// convenience rather than an obstacle.
    public static let devicePasscodeCheck: AuthenticationChallenge = { authenticationChallengeDescription, completion in
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode is set on the device. As with deviceOwnerCheck, do not
            // let the absence of a lock stop the dose from being given.
            completion(.success(()))
            return
        }

        guard let passcodeOnly = SecAccessControlCreateWithFlags(nil,
                                                                 kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                                 .devicePasscode,
                                                                 nil) else {
            // Better to prompt the usual way than to refuse to authenticate at all.
            deviceOwnerCheck(authenticationChallengeDescription, completion)
            return
        }

        context.evaluateAccessControl(passcodeOnly,
                                      operation: .useItem,
                                      localizedReason: authenticationChallengeDescription,
                                      reply: { (success, error) in
                                        DispatchQueue.main.async {
                                            completion(success ? .success(()) : .failure(error ?? UnknownError()))
                                        }
        })
    }
}

private struct AuthenticationChallengeKey: EnvironmentKey {
    static let defaultValue: AuthenticationChallenge = LocalAuthentication.deviceOwnerCheck
}

extension EnvironmentValues {
    public var authenticate: AuthenticationChallenge {
        get { self[AuthenticationChallengeKey.self] }
        set { self[AuthenticationChallengeKey.self] = newValue }
    }
}
