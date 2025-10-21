import Foundation

public protocol LLMServiceProtocol {
    func parseRule(from text: String) async throws -> Rule
    func analyzeContent(_ content: String, against rules: [Rule]) async throws -> AnalysisResult
    func analyzeScreenshot(at path: String, against rules: [Rule]) async throws -> AnalysisResult
    func queryStatus(_ query: String) async throws -> String
}

public class LLMService: LLMServiceProtocol {
    private let ollamaURL: URL
    private let modelName: String
    private let visionModelName: String
    
    public init(
        ollamaURL: URL = URL(string: "http://localhost:11434")!,
        modelName: String = "mistral:7b-instruct",
        visionModelName: String = "llava:7b"
    ) {
        self.ollamaURL = ollamaURL
        self.modelName = modelName
        self.visionModelName = visionModelName
    }
    
    public func parseRule(from text: String) async throws -> Rule {
        let prompt = """
        Parse this parental control rule into structured data. Return JSON with categories (array of strings) and actions (array from: block, alert, log, redirect).
        
        Rule: "\(text)"
        
        Respond only with valid JSON in this format:
        {
            "description": "original rule text",
            "categories": ["category1", "category2"],
            "actions": ["block"],
            "severity": "medium"
        }
        """
        
        let response = try await sendRequest(prompt: prompt, model: modelName)
        return try parseRuleFromJSON(response)
    }
    
    public func analyzeContent(_ content: String, against rules: [Rule]) async throws -> AnalysisResult {
        let activeRules = rules.filter { $0.isActive }
        let ruleDescriptions = activeRules.map { $0.description }.joined(separator: "\n- ")
        
        let prompt = """
        Analyze this content against parental control rules. Respond with JSON only.
        
        Rules:
        - \(ruleDescriptions)
        
        Content: "\(content)"
        
        Respond with:
        {
            "violation": true/false,
            "severity": "low/medium/high/critical",
            "explanation": "brief explanation",
            "categories": ["matched categories"],
            "recommendedAction": "block/alert/log"
        }
        """
        
        let response = try await sendRequest(prompt: prompt, model: modelName)
        return try parseAnalysisResult(response)
    }
    
    public func analyzeScreenshot(at path: String, against rules: [Rule]) async throws -> AnalysisResult {
        let activeRules = rules.filter { $0.isActive }
        let ruleDescriptions = activeRules.map { $0.description }.joined(separator: "\n- ")
        
        let prompt = """
        Analyze this screenshot for any violations of parental control rules. Respond with JSON only.
        
        Rules to check against:
        - \(ruleDescriptions)
        
        Describe what you see and check for violations. Respond with:
        {
            "violation": true/false,
            "severity": "low/medium/high/critical",
            "explanation": "what you see and why it violates rules",
            "categories": ["matched categories"],
            "recommendedAction": "block/alert/log"
        }
        """
        
        let response = try await sendVisionRequest(prompt: prompt, imagePath: path, model: visionModelName)
        return try parseAnalysisResult(response)
    }
    
    public func queryStatus(_ query: String) async throws -> String {
        let prompt = """
        You are KidGuard AI assistant. Answer this parental monitoring query briefly and helpfully.
        
        Query: "\(query)"
        
        Provide a concise, helpful response.
        """
        
        return try await sendRequest(prompt: prompt, model: modelName)
    }
    
    private func sendRequest(prompt: String, model: String) async throws -> String {
        let url = ollamaURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let response = json?["response"] as? String else {
            throw LLMError.invalidResponse
        }
        
        return response
    }
    
    private func sendVisionRequest(prompt: String, imagePath: String, model: String) async throws -> String {
        // Convert image to base64
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        let base64Image = imageData.base64EncodedString()
        
        let url = ollamaURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "images": [base64Image],
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let response = json?["response"] as? String else {
            throw LLMError.invalidResponse
        }
        
        return response
    }
    
    private func parseRuleFromJSON(_ json: String) throws -> Rule {
        guard let data = json.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let description = parsed["description"] as? String,
              let categories = parsed["categories"] as? [String],
              let actionStrings = parsed["actions"] as? [String],
              let severityString = parsed["severity"] as? String else {
            throw LLMError.invalidResponse
        }
        
        let actions = actionStrings.compactMap { RuleAction(rawValue: $0) }
        let severity = RuleSeverity(rawValue: severityString) ?? .medium
        
        return Rule(
            description: description,
            categories: categories,
            actions: actions,
            severity: severity
        )
    }
    
    private func parseAnalysisResult(_ json: String) throws -> AnalysisResult {
        guard let data = json.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let violation = parsed["violation"] as? Bool,
              let severityString = parsed["severity"] as? String,
              let explanation = parsed["explanation"] as? String,
              let categories = parsed["categories"] as? [String],
              let actionString = parsed["recommendedAction"] as? String else {
            throw LLMError.invalidResponse
        }
        
        let severity = RuleSeverity(rawValue: severityString) ?? .medium
        let action = RuleAction(rawValue: actionString) ?? .alert
        
        return AnalysisResult(
            violation: violation,
            severity: severity,
            explanation: explanation,
            categories: categories,
            recommendedAction: action
        )
    }
}

public struct AnalysisResult {
    public let violation: Bool
    public let severity: RuleSeverity
    public let explanation: String
    public let categories: [String]
    public let recommendedAction: RuleAction
    
    public init(violation: Bool, severity: RuleSeverity, explanation: String, categories: [String], recommendedAction: RuleAction) {
        self.violation = violation
        self.severity = severity
        self.explanation = explanation
        self.categories = categories
        self.recommendedAction = recommendedAction
    }
}

public enum LLMError: Error {
    case invalidResponse
    case networkError
    case modelNotAvailable
}