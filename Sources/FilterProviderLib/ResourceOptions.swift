//
//  ResourceOptions.swift
//  FilterProviderLib
//
//  Created by Kent Friesen on 6/4/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

public class ResourceOptions {
    var contentType: String?
    var method: String
    var parameters: [String: Any]?
    
    init(contentType: String?, method: String, parameters: [String: Any]?) {
        self.contentType = contentType
        self.method = method
        self.parameters = parameters
    }
}
