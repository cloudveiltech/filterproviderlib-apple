//
//  PolicyConfiguration.swift
//  FilterProviderLib
//
//  Created by Kent Friesen on 6/12/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

public enum VerificationResult {
    case fresh
    case old
    case none
    case unreachable
}

public enum DownloadResult {
    case downloaded
    case noDownloadNeeded
    case downloadFailed
}

public class PolicyConfiguration {
    let configFilePath = FileManagement.instance.getFileUrl(fileName: "cfg.json")

    let webServiceUtil = WebServiceUtil()
    
    var configuration: AppConfigModel? = nil
    
    var adBlockMatcher: AdBlockMatcher = AdBlockMatcher()
    
    var textTriggers: TextTriggerTree = TextTriggerTree()
    
    var categoryMap: CategoryMap = CategoryMap()
    
    var lastFilterListResults: [String: VerificationResult]? = nil
    
    public func verifyLists(completionHandler: @escaping (VerificationResult) -> Void) {
        var hashes: [String: String] = [:]
        
        guard let configuration = self.configuration else {
            completionHandler(.unreachable)
            return
        }
        
        if configuration.configuredLists.count == 0 {
            completionHandler(.fresh)
            return
        }
        
        let configuredLists = configuration.configuredLists
        
        for list in configuredLists {
            let listFilePath = self.getListFilePath(from: list.relativeListPath)
            hashes[list.relativeListPath] = FileManagement.instance.getSHA1Hash(fileUrl: listFilePath)
        }
        
        self.getListVerificationResults(hashes: hashes) { (hashResults) in
            guard let hashResults = hashResults else {
                completionHandler(.unreachable)
                return
            }
            
            self.lastFilterListResults = hashResults
            
            for (key, result) in hashResults {
                if result == .old {
                    completionHandler(.old)
                    return
                }
            }
            
            completionHandler(.fresh)
        }
    }
    
    private func getListVerificationResults(hashes: [String: String], completionHandler: @escaping ([String: VerificationResult]?) -> Void) {
        let options = ResourceOptions(contentType: "application/json", method: "POST", parameters: hashes)
        
        self.webServiceUtil.requestResource(serviceResource: .ruleDataSumCheck, options: options) { (err, statusCode, responseReceived, data) in
            if let err = err {
                NSLog("Error occurred while requesting the rule data sum check.")
                completionHandler(nil)
                return
            }
            
            guard let data = data else {
                NSLog("Was expecting data from the rule data sum check.")
                completionHandler(nil)
                return
            }
            
            let responseDict: [String: Bool?]?
            do {
                responseDict = try JSONSerialization.jsonObject(with: data, options: .init()) as? [String: Bool?]
            } catch {
                responseDict = nil
            }
            
            var dict: [String: VerificationResult] = [:]
            
            if let responseDict = responseDict {
                for (key, valueWrapped) in responseDict {
                    if let value = valueWrapped {
                        if value {
                            dict[key] = VerificationResult.fresh
                        } else {
                            dict[key] = VerificationResult.old
                        }
                    }
                }
            }
            
            completionHandler(dict)
        }
    }
    
    private func getListFilePath(from: String) -> URL {
        return FileManagement.instance.getFileUrl(fileName: from.replacingOccurrences(of: "/", with: "."))
    }
    
    private func getListFilePath(from: [String: Any]) -> URL? {
        guard let relativeListPath = from["RelativeListPath"] as? String
            else {
                return nil
        }
        
        return self.getListFilePath(from: relativeListPath)
    }
    
    public func verifyConfiguration(completionHandler: @escaping (VerificationResult) -> Void) {
        webServiceUtil.requestResource(serviceResource: .userConfigSumCheck) { (err, statusCode, responseReceived, data) in
            if statusCode == HttpStatusCodes.OK && data != nil {
                // Not sure how to manage filter status? TODO
                
                guard let serverConfigHash = String(data: data!, encoding: .utf8)
                    else {
                        completionHandler(.unreachable)
                        return
                }
                
                guard let localConfigHash = FileManagement.instance.getSHA1Hash(fileUrl: self.configFilePath)
                    else {
                        completionHandler(.none)
                        return
                }
                
                if serverConfigHash == localConfigHash {
                    completionHandler(.fresh)
                    return
                } else {
                    completionHandler(.old)
                }
            } else {
                completionHandler(.unreachable)
                return
            }
        }
    }
    
    public func downloadConfiguration(completionHandler: @escaping (DownloadResult) -> Void) {
        self.verifyConfiguration { (result) in
            if result == .fresh {
                completionHandler(.noDownloadNeeded)
                return
            }
            
            NSLog("Updated filtering rules because of an integrity violation or missing rules.")
            self.webServiceUtil.requestResource(serviceResource: .userConfigRequest, completionHandler: { (err, statusCode, responseReceived, data) in
                guard let data = data else {
                    completionHandler(.downloadFailed)
                    return
                }
                
                if statusCode == HttpStatusCodes.OK && data.count > 0 {
                    do {
                        try data.write(to: self.configFilePath)
                    } catch {
                        completionHandler(.downloadFailed)
                        return
                    }
                    
                    completionHandler(.downloaded)
                } else {
                    NSLog("Failed to download configuration data.");
                    completionHandler(.downloadFailed)
                }
            })
        }
    }
    
    private func createListFolderIfNotExists() {
        // TODO: Do we need this on iOS and macOS?
    }
    
    public func downloadLists(completionHandler: @escaping (DownloadResult) -> Void) {
        self.verifyLists { (result) in
            if result == .fresh {
                completionHandler(.noDownloadNeeded)
                return
            }
            
            guard let config = self.configuration else {
                completionHandler(.downloadFailed)
                return
            }
            
            // TODO: Do we need this on iOS and macOS?
            //self.createListFolderIfNotExists()
            
            NSLog("Updating filtering rules")
            
            var listsToFetch: [ListConfigurationModel] = [ListConfigurationModel]()
            for list in config.configuredLists ?? [] {
                if let lastFilterListResults = self.lastFilterListResults,
                    let listIsCurrent = lastFilterListResults[list.relativeListPath] {
                    switch listIsCurrent {
                    case .none, .old, .unreachable:
                        listsToFetch.append(list)
                        break
                        
                    default:
                        break
                    }
                }
            }
            
            self.webServiceUtil.getFilterLists(toFetch: listsToFetch, completionHandler: { (data) in
                if let data = data {
                    var rulesets = [String: String]()
                    
                    if let contents = String(data: data, encoding: .utf8) {
                        let contentLines = contents.components(separatedBy: .newlines)
                        
                        var currentList: String? = nil
                        var errorList: Bool = false
                        var fileContents: String = String([])
                        
                        for line in contentLines {
                            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                continue
                            }
                            
                            if line.contains("--startlist") {
                                NSLog("Processing list \(line)")
                                
                                let listNameIdx = line.index(line.startIndex, offsetBy: "--startlist".count)
                                currentList = String(line[listNameIdx...])
                            } else if line.starts(with: "--endlist") {
                                if errorList {
                                    errorList = false
                                } else if let currentList = currentList {
                                    rulesets[currentList] = fileContents
                                    
                                    let filePath = self.getListFilePath(from: currentList)

                                    NSLog("Writing list information for \(filePath)")
                                    
                                    do {
                                        defer {
                                            // Just going to comment here because this is the first time I've ever used
                                            // the defer syntax in any language. This syntax is confusing to me, but I think
                                            // that it's basically the same as putting a finally block after catch in another language.
                                            fileContents = String([])
                                        }
                                        
                                        try fileContents.write(to: filePath, atomically: true, encoding: .utf8)
                                    } catch {
                                        NSLog("Failed to write to rule path \(filePath)")
                                        continue
                                    }
                                    
                                }
                                
                                
                            } else {
                                if line == "http-result 404" {
                                    NSLog("404 Error was returned for category \(currentList ?? "(null)")")
                                    errorList = true
                                    continue
                                }
                                
                                fileContents.append(line)
                                fileContents.append("\n")
                            }
                        }
                    }
                    
                    completionHandler(.downloaded)
                } else {
                    completionHandler(.downloadFailed)
                }
            })
        }
    }
    
    public func loadConfiguration(configPath: URL) -> Bool {
        guard let configData = try? Data(contentsOf: configPath) else {
            return false
        }
        
        guard let configJson = try? JSONSerialization.jsonObject(with: configData, options: .init()) else {
            NSLog("Could not find valid JSON config for filter.")
            return false
        }
        
        self.configuration = AppConfigModel(json: configJson)
        // TODO: Call configuration loaded callback
        guard let configuration = self.configuration else {
            NSLog("Failed to deserialize JSON config.")
            return false
        }
        
        if configuration.updateFrequency <= 0 {
            configuration.updateFrequency = 5
        }
        
        // TODO:
        //loadAppList(BlacklistedApplications, Configuration.BlacklistedApplications, BlacklistedApplicationGlobs);
        //loadAppList(WhitelistedApplications, Configuration.WhitelistedApplications, WhitelistedApplicationGlobs);
        
        // TODO:
        /*
         TimeRestrictions = new TimeRestrictionModel[7];
 
         for(int i = 0; i < 7; i++)
         {
         DayOfWeek day = (DayOfWeek)i;
 
         string configDay = day.ToString().ToLowerInvariant();
 
         TimeRestrictionModel restriction = null;
 
         Configuration.TimeRestrictions?.TryGetValue(configDay, out restriction);
 
         TimeRestrictions[i] = restriction;
         }
 
         AreAnyTimeRestrictionsEnabled = TimeRestrictions.Any(r => r?.RestrictionsEnabled == true);
         */
        
        // No need to implement configuration.cannotTerminate
        
        return true
    }
    
    public func loadLists() -> Bool {
        guard let configuration = self.configuration else {
            return false
        }
        
        var adBlockMatcher = AdBlockMatcher()
        var textTriggers = TextTriggerTree()
        
        /* TODO:
 m_categoryIndex.SetAll(false);
 
 // Now clear all generated categories. These will be re-generated as needed.
 m_generatedCategoriesMap.Clear();
 */
        
        var totalFilterRulesLoaded = 0
        var totalFilterRulesFailed = 0
        var totalTriggersLoaded = 0
        
        for list in configuration.configuredLists ?? [] {
            let rulesetPath = self.getListFilePath(from: list.relativeListPath)
            
            if FileManagement.instance.exists(rulesetPath) {
                let startIndex = list.relativeListPath.startIndex
                let lastIndexOptional = list.relativeListPath.lastIndex { (c) -> Bool in
                    switch c {
                    case "/", "\\": return true
                    default: return false
                    }
                }
                
                guard let lastIndex = lastIndexOptional else {
                    continue
                }
                
                let listPath = URL(string: list.relativeListPath)
                guard let shortCategoryName = URL(string: list.relativeListPath)?.deletingPathExtension().lastPathComponent else {
                    continue
                }
                
                let thisListCategoryName = String(list.relativeListPath[startIndex...list.relativeListPath.index(after: lastIndex)]
                    + shortCategoryName)
                
                switch list.listType {
                case "Blacklist":
                    let categoryModel = self.categoryMap.fetchOrCreateCategory(categoryName: thisListCategoryName, listType: .blacklist)
                    
                    let (loaded, failed) = adBlockMatcher.parseRuleFile(fileUrl: rulesetPath, categoryId: categoryModel.categoryId, listType: categoryModel.listType)
                    
                    totalFilterRulesLoaded += loaded
                    totalFilterRulesFailed += failed
                    break
                    
                case "BypassList":
                    let categoryModel = self.categoryMap.fetchOrCreateCategory(categoryName: thisListCategoryName, listType: .bypassList)
                    
                    let (loaded, failed) = adBlockMatcher.parseRuleFile(fileUrl: rulesetPath, categoryId: categoryModel.categoryId, listType: categoryModel.listType)
                    
                    totalFilterRulesLoaded += loaded
                    totalFilterRulesFailed += failed
                    break
                    
                case "Whitelist":
                    let categoryModel = self.categoryMap.fetchOrCreateCategory(categoryName: thisListCategoryName, listType: .whitelist)
                    
                    let (loaded, failed) = adBlockMatcher.parseRuleFile(fileUrl: rulesetPath, categoryId: categoryModel.categoryId, listType: .whitelist)
                    
                    totalFilterRulesLoaded += loaded
                    totalFilterRulesFailed += failed
                    break
                    
                case "TextTrigger":
                    let categoryModel = self.categoryMap.fetchOrCreateCategory(categoryName: thisListCategoryName, listType: .textTriggers)
                    
                    if let fileContents = try? String(contentsOf: rulesetPath) {
                        textTriggers.loadTriggers(fileContents: fileContents, category: categoryModel.categoryId)
                    }
                    
                    break
                    
                default:
                    break
                }
                
            }
        }
        
        if configuration.customTriggerBlacklist.count > 0 {
            var customTriggerBlacklist: [String] = []
            for s in configuration.customTriggerBlacklist {
                if let s = s {
                    customTriggerBlacklist.append(s)
                }
            }
            
            let triggerFile = customTriggerBlacklist.joined(separator: "\n")
            
            let categoryModel = categoryMap.fetchOrCreateCategory(categoryName: "/user/trigger_blacklist", listType: .textTriggers)
            totalTriggersLoaded += textTriggers.loadTriggers(fileContents: triggerFile, category: categoryModel.categoryId)
        }
        
        let cleanRuleRegex = try! NSRegularExpression(pattern: #"^[a-zA-Z0-9\-_\:\.\/]+$"#, options: .init())
            
        if configuration.customWhitelist.count > 0 {
            let categoryModel = categoryMap.fetchOrCreateCategory(categoryName: "/user/custom_whitelist", listType: .whitelist)

            for s in configuration.customWhitelist {
                if let s = s {
                    if cleanRuleRegex.firstMatch(in: s, options: .init(), range: NSRange(location: 0, length: s.count)) == nil {
                        if adBlockMatcher.addRule(rule: s, categoryId: categoryModel.categoryId, listType: .whitelist) {
                            totalFilterRulesLoaded += 1
                        } else {
                            totalFilterRulesFailed += 1
                        }
                    }
                }
            }
        }
        
        if configuration.selfModeration.count > 0 {
            var sanitizedSelfModeration: [String]
            
            let categoryModel = categoryMap.fetchOrCreateCategory(categoryName: "/user/self_moderation", listType: .blacklist)
            for site in configuration.selfModeration {
                if let site = site, cleanRuleRegex.firstMatch(in: site, options: .init(), range: NSRange(location: 0, length: site.count)) == nil {
                    if adBlockMatcher.addRule(rule: site, categoryId: categoryModel.categoryId, listType: .blacklist) {
                        totalFilterRulesLoaded += 1
                    } else {
                        totalFilterRulesFailed += 1
                    }
                }
            }
        }
        
        textTriggers.sortTree()
        
        NSLog("Loaded %d rules, %d rules failed most likely due to being malformed, and %d text triggers loaded.",
              totalFilterRulesLoaded, totalFilterRulesFailed, totalTriggersLoaded)
        
        return true
    }
}
