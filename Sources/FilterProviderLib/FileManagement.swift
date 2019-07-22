//
//  FileManagement.swift
//  FilterProviderLib
//
//  Created by Kent Friesen on 6/12/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation
import CommonCrypto

public class FileManagement {
    public static var instance: FileManagement = FileManagement()
    
    private var fileManager: FileManager
    
    init() {
        self.fileManager = FileManager.default
    }
    
    func getFileUrl(fileName: String) -> URL {
        let pathUrl = self.fileManager.urls(for: FileManager.SearchPathDirectory.libraryDirectory, in: .userDomainMask).first!
        
        let fileUrl = pathUrl.appendingPathComponent(fileName)
        
        return fileUrl
    }
    
    func getSHA1Hash(fileUrl: URL) -> String? {
        do {
            let fileData = try Data(contentsOf: fileUrl)
            
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            fileData.withUnsafeBytes {
                _ = CC_SHA1($0.baseAddress, CC_LONG(fileData.count), &digest)
            }
            
            let hexBytes = digest.map { (b) -> String in
                return String(format: "%02hhx", b)
            }
            
            return hexBytes.joined()
        } catch {
            return nil
        }
    }
    
    func exists(_ fileUrl: URL) -> Bool {
        // Need to unit test swift?
        return self.fileManager.fileExists(atPath: fileUrl.absoluteString)
    }
}
