//
//  AuthenticationResult.swift
//  FilterProviderLib
//
//  Created by Kent Friesen on 5/23/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

class AuthenticationResult {
    var authStatus: AuthenticationResultStatus
    
    init(authStatus: AuthenticationResultStatus) {
        self.authStatus = authStatus
    }
}
