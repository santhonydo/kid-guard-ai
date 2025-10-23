import Foundation

public protocol LLMServiceProtocol {
    func parseRule(from text: String) async throws -> Rule
    func analyzeContent(_ content: String, against rules: [Rule]) async throws -> AnalysisResult
    func analyzeScreenshot(at path: String, against rules: [Rule]) async throws -> AnalysisResult
    func queryStatus(_ query: String) async throws -> String
}

public class LLMService: LLMServiceProtocol {
    private let ollamaURL: URL
    private var modelName: String
    private var visionModelName: String

    public init(
        ollamaURL: URL = URL(string: "http://localhost:11434")!,
        modelName: String = "mistral:7b-instruct",
        visionModelName: String = "llava:7b"
    ) {
        self.ollamaURL = ollamaURL
        self.modelName = modelName
        self.visionModelName = visionModelName
    }

    public func setModel(name: String) {
        self.modelName = name
        print("🤖 Switched to AI model: \(name)")
    }

    public func setVisionModel(name: String) {
        self.visionModelName = name
        print("👁️ Switched to vision model: \(name)")
    }
    
    public func parseRule(from text: String) async throws -> Rule {
        let prompt = """
        Parse this parental control rule. Return ONLY valid JSON, no extra text.

        Rule: "\(text)"

        Return this exact format:
        {"description": "\(text)", "categories": ["category"], "actions": ["block"], "severity": "medium"}

        Use: actions (block/alert/log/redirect), severity (low/medium/high/critical)
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
        let ruleDescriptions = activeRules.map { $0.description }.joined(separator: ", ")

        let prompt = """
        Analyze this screenshot for parental control rule violations. Return ONLY valid JSON, no other text.

        Rules: \(ruleDescriptions)

        Return this exact format:
        {"violation": true, "severity": "low", "explanation": "brief description", "categories": ["category"], "recommendedAction": "log"}

        Use: violation (true/false), severity (low/medium/high/critical), recommendedAction (block/alert/log)
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
            throw LLMError.invalidResponse("No response from Ollama API")
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
            throw LLMError.invalidResponse("Empty response from vision model")
        }
        
        return response
    }
    
    private func parseRuleFromJSON(_ json: String) throws -> Rule {
        // Try to extract JSON from the response (in case there's extra text)
        let jsonString = extractJSON(from: json)

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert to data: \(jsonString)")
            throw LLMError.invalidResponse("Invalid rule JSON format")
        }

        guard let parsed = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] else {
            print("❌ Failed to parse JSON: \(jsonString)")
            throw LLMError.invalidResponse("Invalid rule JSON format")
        }

        var description = parsed["description"] as? String ?? "Unknown rule"
        let categories = parsed["categories"] as? [String] ?? []
        let actionStrings = parsed["actions"] as? [String] ?? ["log"]
        let severityString = parsed["severity"] as? String ?? "medium"

        // Clean up description if it has "original rule text:" prefix
        if description.contains("original rule text:") {
            description = description.replacingOccurrences(of: "original rule text:", with: "").trimmingCharacters(in: .whitespaces)
        }

        let actions = actionStrings.compactMap { RuleAction(rawValue: $0) }
        let severity = RuleSeverity(rawValue: severityString) ?? .medium

        print("✅ Parsed rule: \(description)")

        return Rule(
            description: description,
            categories: categories,
            actions: actions.isEmpty ? [.log] : actions,
            severity: severity
        )
    }
    
    private func parseAnalysisResult(_ json: String) throws -> AnalysisResult {
        // Try to extract JSON from the response (in case there's extra text)
        let jsonString = extractJSON(from: json)

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert to data: \(jsonString)")
            throw LLMError.invalidResponse("Invalid analysis JSON format")
        }

        // Try to parse with more lenient approach
        guard let parsed = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] else {
            print("❌ Failed to parse JSON object: \(jsonString)")
            throw LLMError.invalidResponse("Invalid analysis JSON format")
        }

        // Extract with defaults for missing fields
        let violation = parsed["violation"] as? Bool ?? false
        let severityString = parsed["severity"] as? String ?? "low"
        let explanation = parsed["explanation"] as? String ?? "No explanation provided"
        let categories = parsed["categories"] as? [String] ?? []
        let actionString = (parsed["recommendedAction"] as? String ?? "log").lowercased()

        let severity = RuleSeverity(rawValue: severityString) ?? .medium
        let action = RuleAction(rawValue: actionString) ?? .log

        print("✅ Parsed analysis: violation=\(violation), severity=\(severity), action=\(action)")

        return AnalysisResult(
            violation: violation,
            severity: severity,
            explanation: explanation,
            categories: categories,
            recommendedAction: action
        )
    }

    // Helper to extract JSON from text that may contain extra content
    private func extractJSON(from text: String) -> String {
        var cleanText = text

        // Remove markdown code blocks (```json ... ```)
        if cleanText.contains("```") {
            cleanText = cleanText
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Look for JSON object between { and }
        if let start = cleanText.firstIndex(of: "{"),
           let end = cleanText.lastIndex(of: "}") {
            var jsonText = String(cleanText[start...end])

            // Fix common JSON errors from AI
            // Replace newlines inside string values with escaped newlines
            jsonText = jsonText
                .replacingOccurrences(of: "\n    \"", with: ",\n    \"") // Add missing commas before new fields
                .replacingOccurrences(of: ".\n    \"", with: ".\",\n    \"") // Add missing quote+comma after strings

            return jsonText
        }
        return cleanText
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
    case invalidResponse(String)
    case networkError(String)
    case modelNotAvailable(String)
}