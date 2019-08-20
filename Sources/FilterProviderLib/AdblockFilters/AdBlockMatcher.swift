//
//  adblock.swift
//  FilterProviderFramework
//
//  Created by Kent Friesen on 7/20/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation
import adblock_swift

public class AdBlockMatcher {
    let MaxRulesPerMatcher = 1000
    
    var matcherCategories: [MatcherCategory] = []
    var bypassMatcherCategories: [MatcherCategory] = []
    var lastMatcher: RuleMatcher? = nil
    
    var rulesCount: Int
    var bypassEnabled: Bool
    
    init() {
        self.rulesCount = 0
        self.bypassEnabled = false
    }
    
    func addMatcher(categoryId: Int, listType: ListType, bypass: Bool) {
        var matcher = RuleMatcher()
        
        var matcherCategory: MatcherCategory? = nil
        for element in self.matcherCategories {
            if element.categoryId == categoryId {
                matcherCategory = element
                break
            }
        }
        
        
        if matcherCategory == nil {
            matcherCategory = MatcherCategory(categoryId: categoryId, listType: listType)
            
            if bypass {
                self.bypassMatcherCategories.append(matcherCategory!)
            } else {
                self.matcherCategories.append(matcherCategory!)
            }
        }
        
        if var matcherCategory = matcherCategory {
            matcherCategory.matchers.append(matcher)
            self.lastMatcher = matcher
        }
    }
    
    func testUrl(url: String, host: String, headers: [String: [String]]) -> [MatcherCategory] {
        let res = self.matchRulesCategories(categories: self.matcherCategories, url: url, host: host, headers: headers)
        
        if res.count > 0 {
            return res
        }
        
        if self.bypassEnabled {
            return []
        }
        
        return self.matchRulesCategories(categories: self.bypassMatcherCategories, url: url, host: host, headers: headers)
    }
    
    func matchRulesCategories(categories: [MatcherCategory], url: String, host: String, headers: [String: [String]]) -> [MatcherCategory] {
        var req = AdBlockRequest(url: url)
        req.domain = host
        req.headers = headers
        
        var matchedCategories: [MatcherCategory] = []
        
        for category in categories {
            for matcher in category.matchers {
                let (matched, _, err) = matcher.match(req: req)
                if let err = err {
                    NSLog("Error matching rule %s", err.localizedDescription)
                }
                
                if matched {
                    matchedCategories.append(category)
                }
            }
        }
        
        return matchedCategories
    }
    
    func addRule(rule ruleRaw: String, categoryId: Int, listType: ListType) -> Bool {
        let bypass = listType == .bypassList
        
        let (rule, err) = parseRule(rawRuleString: ruleRaw)
        
        if let err = err {
            NSLog("Error parsing rule %s %s", ruleRaw, err.localizedDescription)
            return false
        }
        
        if let rule = rule {
            if (self.rulesCount % MaxRulesPerMatcher) == 0 {
                self.addMatcher(categoryId: categoryId, listType: listType, bypass: bypass)
            }
            
            self.lastMatcher?.addRule(rule: rule, ruleId: self.rulesCount)
            self.rulesCount += 1
            
            return true
        } else {
            return false
        }
    }
    
    func parseRuleFile(fileUrl: URL, categoryId: Int, listType: ListType) -> (Int, Int) {
        let bypass = listType == .bypassList
        
        var totalLoaded = 0
        var totalFailed = 0
        
        if let fileContents = try? String(contentsOf: fileUrl) {
            self.addMatcher(categoryId: categoryId, listType: listType, bypass: bypass)
            NSLog("Opening rules %s", fileUrl.absoluteString)
            
            for line in fileContents.components(separatedBy: .newlines) {
                let ruleAdded = self.addRule(rule: line, categoryId: categoryId, listType: listType)
                if ruleAdded {
                    totalLoaded += 1
                } else {
                    totalLoaded += 1
                }
            }
        }
        
        return (totalLoaded, totalFailed)
    }
}
