//
//  TextTriggerTree.swift
//  FilterProviderFramework
//
//  Created by Kent Friesen on 7/19/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

public class TextTriggerTree {
    public var root: TextTriggerNode
    
    public init() {
        root = TextTriggerNode(type: .root, data: Character("\0"))
    }
    
    private func forwardPastSeparator(contents: String, _ idx: String.Index) -> String.Index {
        var i = idx
        
        var foundSeparator = false
        
        while i < contents.endIndex {
            let currentIsSeparator = CharHelper.isSeparator(contents[i])
            
            if currentIsSeparator {
                foundSeparator = true
            }
            
            if foundSeparator && !currentIsSeparator {
                return i;
            }
            
            i = contents.index(after: i)
        }
        
        return i
    }
    
    public func containsTrigger(contents: String) -> [Int]? {
        var categories: [Int]? = nil
        
        var current: TextTriggerNode? = self.root
        
        var i = contents.startIndex
        while i < contents.endIndex {
            let c = Character(contents[i].lowercased())
            
            if CharHelper.isSeparator(c) {
                if let separator = current?.findChild(c) {
                    current = separator
                } else {
                    current = self.root
                    i = forwardPastSeparator(contents: contents, i)
                    continue
                }
            } else {
                current = current?.findChild(c)
            }
            
            if current == nil {
                current = self.root
                i = forwardPastSeparator(contents: contents, i)
                continue
            }
            
            // Does current node have categories attached?
            if let current = current, current.matchingCategories.count > 0 {
                // If yes, check to see if next character is a separator character or end of content
                if contents.endIndex < i || CharHelper.isSeparator(contents[contents.index(after: i)]) {
                    // We have a match!
                    return current.matchingCategories
                }
            }
            
            // No match was found or no categories are attached.
            
            // If this is a leaf node, reset tree traversal
            if (current?.children.count ?? 0) == 0 {
                current = self.root
                i = forwardPastSeparator(contents: contents, i)
                continue
            }
            
            // Not a leaf node. Increment search and continue to next tree node.
            i = contents.index(after: i)
        }
        
        return nil;
    }
    
    public func sortTree() {
        self.root.sortChildren()
    }
    
    public func addTrigger(trigger: String, category: Int) -> Bool {
        // trigger[trigger.startIndex...] is the only way to convert a String type to a Substring type, AFAIK
        return self.root.addTrigger(trigger: trigger[trigger.startIndex...], category: category)
    }
    
    public func loadTriggers(fileContents: String, category: Int) -> Int {
        var loaded: Int = 0
        
        for line in fileContents.components(separatedBy: .newlines) {
            if(addTrigger(trigger: line, category: category)) {
                loaded += 1;
            }
        }
        
        return loaded;
    }
}
