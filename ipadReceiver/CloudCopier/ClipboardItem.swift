import Foundation

struct ClipboardItem: Identifiable {
    let id = UUID()
    let formats: [String: String]
    let source: String
    let timestamp: Date
    
    init(formats: [String: String], source: String) {
        self.formats = formats
        self.source = source
        self.timestamp = Date()
    }
    
    var primaryFormat: String {
        // Prioritize formats for display
        if formats.keys.contains("text") { return "text" }
        if formats.keys.contains("html") { return "html" }
        if formats.keys.contains("rtf") { return "rtf" }
        if formats.keys.contains("image") { return "image" }
        if formats.keys.contains("files") { return "files" }
        return formats.keys.first ?? "unknown"
    }
    
    var previewText: String {
        switch primaryFormat {
        case "text":
            return formats["text"]?.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines) ?? "Empty text"
            
        case "html":
            // Strip HTML tags for preview
            let html = formats["html"] ?? ""
            let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            return stripped.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
            
        case "rtf":
            // Extract plain text from RTF for preview
            let rtf = formats["rtf"] ?? ""
            // Simple RTF text extraction (basic)
            let text = rtf.replacingOccurrences(of: "\\\\[a-z0-9]+\\s?", with: "", options: .regularExpression)
                         .replacingOccurrences(of: "[{}]", with: "", options: .regularExpression)
            return text.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
            
        case "image":
            return "📸 Image copied"
            
        case "files":
            let files = formats["files"] ?? ""
            let fileCount = files.components(separatedBy: "\n").count
            return "📁 \(fileCount) file(s)"
            
        default:
            return "Unknown clipboard format"
        }
    }
}