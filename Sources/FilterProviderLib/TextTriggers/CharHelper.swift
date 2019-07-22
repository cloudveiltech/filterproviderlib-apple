//
//  CharHelper.swift
//  FilterProviderFramework
//
//  Created by Kent Friesen on 7/19/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

class CharHelper {
    private static var separatorList: [Bool]? = nil
    private static let customSeparatorList = "+=<>|"
    
    private static func setSeparator(list: inout [Bool], _ c: Character, _ b: Bool) {
        if let i = c.asciiValue {
            list[Int(i)] = b
        }
    }
    
    private static func initSeparatorList() {
        var separatorList = [Bool](repeating: false, count: 256)
        for i in 0..<256 {
            if let scalar = Unicode.Scalar(i) {
                let c = Character(scalar)
                separatorList[i] = c.isWhitespace || c.isNewline || c.isPunctuation
            }
        }
        
        for sep in customSeparatorList {
            setSeparator(list: &separatorList, sep, true)
        }
    }
    
    internal static func isSeparator(_ c: Character) -> Bool {
        if(CharHelper.separatorList == nil) {
            initSeparatorList()
        }
        
        if let idx = c.asciiValue, let sepList = CharHelper.separatorList {
            return sepList[Int(idx)]
        } else {
            return c.isPunctuation || c.isWhitespace || c.isNewline
        }
    }
}
