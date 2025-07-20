import Foundation

struct Environment {
    static let serverUrl: String = {
        if let url = Bundle.main.object(forInfoDictionaryKey: "SERVER_URL") as? String {
            return url
        }
        return "https://cloudcopier-production.up.railway.app"
    }()
    
    static let apiKey: String = {
        if let key = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String {
            return key
        }
        return "your-api-key-here"
    }()
    
    static let pollingInterval: TimeInterval = {
        if let interval = Bundle.main.object(forInfoDictionaryKey: "POLLING_INTERVAL") as? String,
           let intervalValue = TimeInterval(interval) {
            return intervalValue
        }
        return 2.0
    }()
}