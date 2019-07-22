//
//  CategoryMap.swift
//  FilterProviderFramework
//
//  Created by Kent Friesen on 7/20/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

class ListCategory {
    public let listType: ListType
    public let listName: String
    public let listFullName: String
    public let categoryId: Int
    
    public init(listType: ListType, listName: String, listFullName: String, categoryId: Int) {
        self.listType = listType
        self.listName = listName
        self.listFullName = listFullName
        self.categoryId = categoryId
    }
}

// TODO: Needs mutex protection
class CategoryMap {
    private var categoryMap: [String: ListCategory] = [:]
    
    public func fetchOrCreateCategory(categoryName: String, listType: ListType) -> ListCategory {
        let category: ListCategory
        
        if categoryMap[categoryName] == nil {
            category = ListCategory(listType: listType, listName: categoryName, listFullName: categoryName, categoryId: categoryMap.count + 1)
            
            categoryMap[categoryName] = category
        } else {
            category = categoryMap[categoryName]!
        }
        
        return category
    }
}
