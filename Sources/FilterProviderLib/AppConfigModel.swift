//
//  AppConfigModel.swift
//  FilterProviderLib
//
//  Created by Kent Friesen on 8/20/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

public class AppConfigModel {
    public static let DefaultUpdateFrequency: Int = 30
    
    public var configuredLists: [ListConfigurationModel]
    
    public var updateFrequency: Int
    
    public var customTriggerBlacklist: [String?]
    public var customWhitelist: [String?]
    public var selfModeration: [String?]
    
    public init?(json: Any) {
        if let json = json as? [String: Any?] {
            guard let configuredListsJson = json["ConfiguredLists"] as? [[String: Any?]?]
                else {
                    return nil
            }
            
            if let updateFrequency = json["UpdateFrequency"] as? Int {
                self.updateFrequency = updateFrequency
            } else {
                self.updateFrequency = AppConfigModel.DefaultUpdateFrequency
            }

            if let customTriggerBlacklist = json["CustomTriggerBlacklist"] as? [String?] {
                self.customTriggerBlacklist = customTriggerBlacklist
            } else {
                self.customTriggerBlacklist = []
            }
            
            if let customWhitelist = json["CustomWhitelist"] as? [String?] {
                self.customWhitelist = customWhitelist
            } else {
                self.customWhitelist = []
            }
            
            if let selfModeration = json["SelfModeration"] as? [String?] {
                self.selfModeration = selfModeration
            } else {
                self.selfModeration = []
            }
            
            self.configuredLists = AppConfigModel.buildConfiguredLists(configuredListsJson)
            
        } else {
            return nil
        }
    }
    
    private static func buildConfiguredLists(_ listsJson: [[String: Any?]?]) -> [ListConfigurationModel] {
        var configuredLists: [ListConfigurationModel] = []
        for listJson in listsJson {
            if let list = ListConfigurationModel(json: listJson) {
                configuredLists.append(list)
            }
        }
    
        return configuredLists
    }
}
