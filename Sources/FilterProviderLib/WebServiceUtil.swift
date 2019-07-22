//
//  FilterProviderLib.swift
//  FilterProviderLib
//
//  Created by Kent Friesen on 5/23/19.
//  Copyright © 2019 CloudVeil Technology, Inc. All rights reserved.
//

import Foundation

public class WebServiceUtil {
    var authStorage: AuthenticationStorage
    var apiBaseUrl: URL
    
    static let serviceResourceMap: [ServiceResource: String] = [
        ServiceResource.getToken: "/api/v2/user/gettoken",
        ServiceResource.userDataSumCheck: "/api/v2/me/data/check",
        ServiceResource.userConfigSumCheck: "/api/v2/me/config/check",
        ServiceResource.userConfigRequest: "/api/v2/me/config/get",
        ServiceResource.ruleDataSumCheck: "/api/v2/rules/check",
        ServiceResource.ruleDataRequest: "/api/v2/rules/get"
    ]
    
    public init() {
        self.authStorage = AuthenticationStorage()
        self.authStorage.load()
        
        apiBaseUrl = Hardcoded.baseApiUrl!
    }
    
    private func getBaseRequest(requestPath: String, options: ResourceOptions?) -> URLRequest {
        let url = apiBaseUrl.appendingPathComponent(requestPath)
        var request = URLRequest(url: url)
        
        request.httpMethod = options?.method ?? "POST"
        request.timeoutInterval = 5000
        request.setValue(options?.contentType ?? "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Bot/CloudVeil", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    private func getBaseRequest(resource: ServiceResource) -> URLRequest? {
        // Can't create a URLRequest with a nullable URL.
        if let requestPath = WebServiceUtil.serviceResourceMap[resource] {
            return getBaseRequest(requestPath: requestPath, options: nil)
        } else {
            return nil
        }
    }
    
    public func authenticate(username: String, password: String, completionHandler: @escaping (Error?, AuthenticationResultStatus) -> Void) -> Void {
        let deviceName = Hardcoded.deviceName
        let deviceId = Hardcoded.deviceId
        
        // This is an anti-pattern, I know. I'm not sure how to do unwrapping on mutable objects.
        // I should figure out how to do this with 100% immutable objects.
        if var authRequest = self.getBaseRequest(resource: .getToken) {
            
            let formData = "email=\(Hardcoded.userEmail)&identifier=\(deviceId)&device_id=\(deviceName)"
            
            let credentials = "\(username):\(password)".data(using: String.Encoding.isoLatin1)?.base64EncodedString()
            
            if let credentials = credentials {
                authRequest.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            }
            
            authRequest.httpBody = formData.data(using: .utf8)
            
            let task = URLSession.shared.dataTask(with: authRequest) { (data: Data?, response: URLResponse?, err: Error?) in
                if let err = err {
                    NSLog("cloudveil: Error occurred while attempting authentication: %@", err as NSError)
                    completionHandler(nil, .Failure)
                    return
                }
                
                if let response = response {
                    guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse
                        else {
                            completionHandler(NSError(domain: "", code: 0, userInfo: nil), .Failure)
                            return
                    }
                    
                    if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                        completionHandler(nil, .Failure)
                        return
                    }
                }
                
                if let data = data {
                    self.authStorage.authToken = String(data: data, encoding: .utf8)
                    self.authStorage.userEmail = username
                    self.authStorage.save()
                    
                    completionHandler(nil, .Success)
                }
                
                completionHandler(nil, .Failure)
            }
            
            task.resume()
        } else {
            completionHandler(NSError(domain: "", code: 0, userInfo: nil), .Failure)
        }
    }
    
    public func requestResource(serviceResource: ServiceResource, completionHandler: @escaping (Error?, Int, Bool, Data?) -> Void) {
        self.requestResource(serviceResource: serviceResource, options: nil, completionHandler: completionHandler)
    }
    
    public func requestResource(serviceResource: ServiceResource, options: ResourceOptions?, completionHandler: @escaping (Error?, Int, Bool, Data?) -> Void) {
        guard let resourceUri = WebServiceUtil.serviceResourceMap[serviceResource]
            else {
                completionHandler(NSError(domain: "NoServiceResource", code: 0, userInfo: nil), 0, false, nil)
                return
        }
        
        self.requestResource(serviceResource: serviceResource, resourceUri: resourceUri, options: options, completionHandler: completionHandler)
    }
    
    public func requestResource(serviceResource: ServiceResource, resourceUri: String, options: ResourceOptions?, completionHandler: @escaping (Error?, Int, Bool, Data?) -> Void) {
        var parameters: [String: Any] = [:]
        
        // TODO: Get deviceName from computer.
        let deviceName = Hardcoded.deviceName
        
        // try { deviceName = Environment.MachineName } catch { deviceName = "Unknown"; }
        
        guard let accessToken = self.authStorage.authToken
            else {
                completionHandler(NSError(domain: "auth", code: 401, userInfo: nil), 401, false, nil)
                return
        }
        
        parameters["identifier"] = Hardcoded.deviceId
        parameters["device_id"] = deviceName
        
        if let optionParams = options?.parameters {
            for (key, val) in optionParams {
                parameters[key] = val
            }
        }
        
        let httpMethod = options?.method ?? "GET"
        
        let version = Hardcoded.version
        
        if(serviceResource == ServiceResource.userDataSumCheck) {
            parameters["app_version"] = version
        }
        
        // TODO: Add ResourceOptions and switch on that contentType instead.
        let contentType = options?.contentType ?? "application/x-www-form-urlencoded"
        
        let postData: Data?
        
        switch contentType {
        case "application/x-www-form-urlencoded":
            var parametersArr: [String] = []
            for (key, val) in parameters {
                let pair = "\(key)=\(val)"
                parametersArr.append(pair)
            }
            
            let postString = parametersArr.joined(separator: "&")
            postData = postString.data(using: .utf8)
            break
            
        case "application/json":
            do {
                postData = try JSONSerialization.data(withJSONObject: parameters, options: JSONSerialization.WritingOptions())
            } catch {
                completionHandler(NSError(domain: "json-serialization", code: 0, userInfo: nil), 0, false, nil)
                return
            }
            
        default:
            return
        }
        
        let uri: String
        if httpMethod == "GET" || httpMethod == "DELETE" {
            let postString: String
                
            if let postData = postData {
                postString = String(data: postData, encoding: .utf8) ?? ""
            } else {
                postString = ""
            }
            
            uri =  "\(resourceUri)?\(postString)"
        } else {
            uri = ""
        }
        
        var request = self.getBaseRequest(requestPath: uri, options: options)
        
        if httpMethod != "GET" && httpMethod != "DELETE" {
            request.httpBody = postData
        }
        
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, err: Error?) in
            if let err = err {
                NSLog("cloudveil: Error occurred while attempting resource fetch: %@", err as NSError)
                completionHandler(err, 0, false, nil)
                return
            }
            
            var statusCode = 0
            
            if let response = response {
                guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse
                    else {
                        completionHandler(NSError(domain: "", code: 0, userInfo: nil), 0, data != nil ? true : false, data)
                        return
                }
                
                statusCode = httpResponse.statusCode
                
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    completionHandler(NSError(domain: "auth", code: httpResponse.statusCode, userInfo: nil), httpResponse.statusCode, data != nil ? true : false, data)
                    return
                }
            }
            
            completionHandler(nil, statusCode, data != nil ? true : false, data)
        }
        
        task.resume()
    }
    
    public func getFilterLists(toFetch: [ListConfigurationModel], completionHandler: @escaping (Data?) -> Void) {
        let paths = toFetch.map { (listConfig) -> String in
            return listConfig.relativeListPath
        }
        
        var parameters: [String: Any] = [String: Any]()
        parameters["lists"] = paths
        
        var resourceOptions = ResourceOptions(contentType: "application/json", method: "POST", parameters: parameters)
        
        self.requestResource(serviceResource: .ruleDataRequest, options: resourceOptions) { (err, code, received, data) in
            if !received {
                completionHandler(nil)
                return
            }
            
            if code < 200 || code > 399 {
                completionHandler(nil)
                return
            }
            
            completionHandler(data)
        }
    }
}
