//
//  ListConfigurationModel.swift
//  FilterProviderLib
//
//  Created by Kent Friesen on 8/20/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

public class ListConfigurationModel {
    public let listType: String
    public let relativeListPath: String
    
    public init?(json: [String: Any]?) {
        if let json = json {
            guard let listType = json["ListType"] as? String else { return nil }
            guard let relativeListPath = json["RelativeListPath"] as? String else { return nil }
            
            self.listType = listType
            self.relativeListPath = relativeListPath
        } else {
            return nil
        }
    }
}
