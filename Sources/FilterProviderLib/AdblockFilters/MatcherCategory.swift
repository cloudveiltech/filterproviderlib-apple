//
//  MatcherCategory.swift
//  FilterProviderFramework
//
//  Created by Kent Friesen on 7/20/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation
import adblock_swift

public class MatcherCategory {
    let categoryId: Int
    let listType: ListType
    
    var matchers: [RuleMatcher] = []
    
    init(categoryId: Int, listType: ListType) {
        self.categoryId = categoryId
        self.listType = listType
    }
}
