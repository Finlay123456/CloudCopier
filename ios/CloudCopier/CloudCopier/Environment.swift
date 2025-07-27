//
//  Environment.swift
//  CloudCopier
//
//  Created by Finlay Cooper on 2025-07-27.
//

import Foundation

struct Environment {
    private static var environmentPlist: [String: Any]? = {
        guard let path = Bundle.main.path(forResource: "Environment", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return plist
    }()
    
    static let serverUrl: String = {
        if let url = environmentPlist?["SERVER_URL"] as? String {
            return url
        }
        if let url = Bundle.main.object(forInfoDictionaryKey: "SERVER_URL") as? String {
            return url
        }
        return "https://cloudcopier-production.up.railway.app"
    }()
    
    static let apiKey: String = {
        if let key = environmentPlist?["API_KEY"] as? String {
            return key
        }
        if let key = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String {
            return key
        }
        return "your-api-key-here"
    }()
    
    static let pollingInterval: TimeInterval = {
        if let interval = environmentPlist?["POLLING_INTERVAL"] as? String,
           let intervalValue = TimeInterval(interval) {
            return intervalValue
        }
        if let interval = Bundle.main.object(forInfoDictionaryKey: "POLLING_INTERVAL") as? String,
           let intervalValue = TimeInterval(interval) {
            return intervalValue
        }
        return 2.0
    }()
}
