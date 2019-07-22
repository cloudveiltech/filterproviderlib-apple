//
//  TextTriggerNode.swift
//  FilterProviderFramework
//
//  Created by Kent Friesen on 7/19/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

public enum NodeType {
    case root
    case character
    case separator
    case undefined
}

public class TextTriggerNode : Comparable {
    public let type: NodeType
    
    var children: [TextTriggerNode] = []
    
    var matchingCategories: [Int] = []
    
    var data: Character
    
    init(type: NodeType, data: Character) {
        self.type = type
        self.data = data
    }
    
    public static func create(_ c: Character) -> TextTriggerNode {
        let nodeType: NodeType
        
        if(c == " ") {
            nodeType = .separator
        } else {
            nodeType = .character
        }
        
        return TextTriggerNode(type: nodeType, data: c)
    }
    
    public func isLeafNode() -> Bool {
        return self.children.count == 0
    }
    
    private func compareChild(_ c: Character, _ n: TextTriggerNode) -> TextTriggerNode? {
        if (n.type == .separator && CharHelper.isSeparator(c)) || n.data == c {
            return n
        } else {
            return nil
        }
    }
    
    public func findChild(_ c: Character) -> TextTriggerNode? {
        if isLeafNode() {
            return nil
        }
        
        var bottom = 0
        var top = children.count - 1
        var i = (top - bottom) / 2
        
        while(true) {
            var child = children[i]
            var found = compareChild(c, child)
            
            if found != nil {
                return found
            }
            
            if c > child.data {
                top = i
            } else {
                bottom = i
            }
            
            let add = (top - bottom) / 2
            if add == 0 {
                if let child = self.compareChild(c, children[top]) {
                    return child
                }
                
                if let child = self.compareChild(c, children[bottom]) {
                    return child
                }
                
                return nil
            } else {
                i = bottom + add
            }
        }
        
        return nil
    }
    
    public func sortChildren() {
        children.sort()
        
        for child in children {
            child.sortChildren()
        }
    }
    
    public func addTrigger(trigger: Substring, category: Int) -> Bool {
        if trigger.count == 0 {
            self.matchingCategories.append(category)
            return true
        }
        
        let c = trigger[trigger.startIndex]
        
        for child in children {
            if child.data == c {
                return child.addTrigger(trigger: trigger[trigger.index(after: trigger.startIndex)...], category: category)
            }
        }
        
        let newChild = TextTriggerNode.create(c)
        
        children.append(newChild)
        return newChild.addTrigger(trigger: trigger[trigger.index(after: trigger.startIndex)...], category: category)
    }
    
    public static func < (lh: TextTriggerNode, rh: TextTriggerNode) -> Bool {
        if(lh.data < rh.data) {
            return true
        } else {
            return false
        }
    }
    
    public static func == (lh: TextTriggerNode, rh: TextTriggerNode) -> Bool {
        return lh.data == rh.data
    }
}
