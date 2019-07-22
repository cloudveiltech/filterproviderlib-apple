//
//  AuthenticationStorage.swift
//  FilterProviderLib
//
//  Created by Kent Friesen on 5/23/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

class AuthenticationStorage {
    var userEmail: String?
    var authToken: String?
    
    private var fileManager: FileManager
    
    init() {
        self.fileManager = FileManager.default
    }
    
    func load() {
        let fileUrl = FileManagement.instance.getFileUrl(fileName: "auth.storage")
        var fileData: Data?
        
        if(self.fileManager.fileExists(atPath: fileUrl.path)) {
            do {
                try fileData = Data(contentsOf: fileUrl)
            } catch {
                fileData = nil
            }
        }
        
        if let fileData = fileData {
            let json: [String: Any]?
            do {
                json = try JSONSerialization.jsonObject(with: fileData, options: JSONSerialization.ReadingOptions()) as? [String: Any]
            } catch {
                json = nil
            }
            
            if let json = json {
                self.userEmail = json["userEmail"] as? String
                self.authToken = json["authToken"] as? String
                return
            }
        }
    }
    
    func save() {
        let fileUrl = FileManagement.instance.getFileUrl(fileName: "auth.storage")
        
        let json = ["userEmail": self.userEmail, "authToken": self.authToken]
        
        do {
            let fileData = try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions())
            try fileData.write(to: fileUrl)
        } catch {
            
        }
    }
}
