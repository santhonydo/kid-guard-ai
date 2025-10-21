import Foundation

/// Improved LLM Service with robust JSON parsing and validation
public class LLMServiceImproved: LLMServiceProtocol {
    private let ollamaURL: URL
    private let modelName: String
    private let visionModelName: String
    private let maxRetries: Int

    public init(
        ollamaURL: URL = URL(string: "http://localhost:11434")!,
        modelName: String = "mistral:7b-instruct",
        visionModelName: String = "llava:7b",
        maxRetries: Int = 3
    ) {
        self.ollamaURL = ollamaURL
        self.modelName = modelName
        self.visionModelName = visionModelName
        self.maxRetries = maxRetries
    }

    public func parseRule(from text: String) async throws -> Rule {
        // Improved prompt with explicit JSON requirements
        let prompt = """
        You are a JSON-only API. Parse this parental control rule into valid JSON.

        CRITICAL: Return ONLY valid JSON with NO markdown, NO explanation, NO extra text.

        Rule: "\(text)"

        Required JSON format (copy this structure exactly):
        {
          "description": "the rule text",
          "categories": ["violence", "adult", "social_media", "gaming", "drugs", etc],
          "actions": ["block", "alert", "log", "redirect"],
          "severity": "low"
        }

        SEVERITY MUST BE EXACTLY ONE OF: "low", "medium", "high", "critical"

        JSON:
        """

        // Retry logic for robustness
        for attempt in 1...maxRetries {
            do {
                let response = try await sendRequest(prompt: prompt, model: modelName)
                let rule = try parseRuleFromJSON(response)

                // Validate rule has required fields
                guard !rule.categories.isEmpty else {
                    throw LLMError.invalidResponse("Empty categories")
                }
                guard !rule.actions.isEmpty else {
                    throw LLMError.invalidResponse("Empty actions")
                }

                return rule
            } catch {
                if attempt == maxRetries {
                    throw error
                }
                print("Retry \(attempt)/\(maxRetries): \(error)")
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            }
        }

        throw LLMError.invalidResponse("Max retries exceeded")
    }

    public func analyzeContent(_ content: String, against rules: [Rule]) async throws -> AnalysisResult {
        let activeRules = rules.filter { $0.isActive }
        let ruleDescriptions = activeRules.map { $0.description }.joined(separator: "\\n- ")

        let prompt = """
        You are a JSON-only API. Analyze content for rule violations.

        CRITICAL: Return ONLY valid JSON with NO markdown, NO explanation.

        Rules:
        - \(ruleDescriptions)

        Content: "\(content)"

        Required JSON format (copy exactly):
        {
          "violation": true,
          "severity": "high",
          "explanation": "brief reason",
          "categories": ["violence"],
          "recommendedAction": "block"
        }

        FIELDS:
        - violation: boolean (true/false)
        - severity: MUST BE "low", "medium", "high", or "critical"
        - explanation: string
        - categories: array of strings
        - recommendedAction: MUST BE "block", "alert", "log", or "redirect"

        JSON:
        """

        for attempt in 1...maxRetries {
            do {
                let response = try await sendRequest(prompt: prompt, model: modelName)
                return try parseAnalysisResult(response)
            } catch {
                if attempt == maxRetries {
                    throw error
                }
                print("Retry \(attempt)/\(maxRetries): \(error)")
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        throw LLMError.invalidResponse("Max retries exceeded")
    }

    public func analyzeScreenshot(at path: String, against rules: [Rule]) async throws -> AnalysisResult {
        let activeRules = rules.filter { $0.isActive }
        let ruleDescriptions = activeRules.map { $0.description }.joined(separator: "\\n- ")

        let prompt = """
        You are a JSON-only API. Analyze this screenshot for rule violations.

        CRITICAL: Return ONLY valid JSON with NO markdown, NO explanation.

        Rules:
        - \(ruleDescriptions)

        Describe what you see and check against rules.

        Required JSON format:
        {
          "violation": false,
          "severity": "low",
          "explanation": "what you see and why",
          "categories": [],
          "recommendedAction": "log"
        }

        JSON:
        """

        for attempt in 1...maxRetries {
            do {
                let response = try await sendVisionRequest(prompt: prompt, imagePath: path, model: visionModelName)
                return try parseAnalysisResult(response)
            } catch {
                if attempt == maxRetries {
                    throw error
                }
                print("Retry \(attempt)/\(maxRetries): \(error)")
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        throw LLMError.invalidResponse("Max retries exceeded")
    }

    public func queryStatus(_ query: String) async throws -> String {
        let prompt = """
        You are KidGuard AI assistant. Answer briefly and helpfully.

        Query: "\(query)"

        Response:
        """

        return try await sendRequest(prompt: prompt, model: modelName)
    }

    // MARK: - Private Methods

    private func sendRequest(prompt: String, model: String) async throws -> String {
        let url = ollamaURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "temperature": 0.1  // Lower temperature for more consistent responses
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let response = json?["response"] as? String else {
            throw LLMError.invalidResponse("No response from model")
        }

        return response
    }

    private func sendVisionRequest(prompt: String, imagePath: String, model: String) async throws -> String {
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
            "stream": false,
            "temperature": 0.1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let response = json?["response"] as? String else {
            throw LLMError.invalidResponse("No response from model")
        }

        return response
    }

    private func parseRuleFromJSON(_ response: String) throws -> Rule {
        // Clean response: remove markdown, extract JSON
        let cleaned = cleanJSONResponse(response)

        guard let data = cleaned.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse("Cannot parse JSON: \(cleaned)")
        }

        guard let description = parsed["description"] as? String else {
            throw LLMError.invalidResponse("Missing 'description' field")
        }

        guard let categories = parsed["categories"] as? [String] else {
            throw LLMError.invalidResponse("Missing 'categories' field")
        }

        guard let actionStrings = parsed["actions"] as? [String] else {
            throw LLMError.invalidResponse("Missing 'actions' field")
        }

        guard let severityString = parsed["severity"] as? String,
              !severityString.isEmpty else {
            throw LLMError.invalidResponse("Missing or empty 'severity' field")
        }

        let actions = actionStrings.compactMap { RuleAction(rawValue: $0.lowercased()) }
        guard !actions.isEmpty else {
            throw LLMError.invalidResponse("No valid actions found")
        }

        let severity = RuleSeverity(rawValue: severityString.lowercased()) ?? .medium

        return Rule(
            description: description,
            categories: categories,
            actions: actions,
            severity: severity
        )
    }

    private func parseAnalysisResult(_ response: String) throws -> AnalysisResult {
        let cleaned = cleanJSONResponse(response)

        guard let data = cleaned.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse("Cannot parse JSON: \(cleaned)")
        }

        guard let violation = parsed["violation"] as? Bool else {
            throw LLMError.invalidResponse("Missing 'violation' field")
        }

        guard let severityString = parsed["severity"] as? String,
              !severityString.isEmpty else {
            throw LLMError.invalidResponse("Missing or empty 'severity' field")
        }

        guard let explanation = parsed["explanation"] as? String else {
            throw LLMError.invalidResponse("Missing 'explanation' field")
        }

        guard let categories = parsed["categories"] as? [String] else {
            throw LLMError.invalidResponse("Missing 'categories' field")
        }

        guard let actionString = parsed["recommendedAction"] as? String,
              !actionString.isEmpty else {
            throw LLMError.invalidResponse("Missing 'recommendedAction' field")
        }

        let severity = RuleSeverity(rawValue: severityString.lowercased()) ?? .medium
        let action = RuleAction(rawValue: actionString.lowercased()) ?? .alert

        return AnalysisResult(
            violation: violation,
            severity: severity,
            explanation: explanation,
            categories: categories,
            recommendedAction: action
        )
    }

    private func cleanJSONResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract JSON object
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIndex...endIndex])
        }

        return cleaned
    }
}
