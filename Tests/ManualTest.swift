import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Manual test script to verify KidGuard AI services
/// Run with: swift run ManualTest

@main
struct ManualTest {
    static func main() async throws {
        print("🧪 KidGuard AI - Manual Testing Suite")
        print("=" + String(repeating: "=", count: 50))
        print()

        await testOllamaConnection()
        await testRuleParsing()
        await testContentAnalysis()

        print()
        print("✅ All tests completed!")
    }

    // MARK: - Test 1: Ollama Connection

    static func testOllamaConnection() async {
        print("📡 Test 1: Ollama Connection")
        print("-" + String(repeating: "-", count: 50))

        do {
            let url = URL(string: "http://localhost:11434/api/tags")!
            let (data, _) = try await URLSession.shared.data(from: url)

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                print("✅ Ollama is running")
                print("📦 Installed models:")
                for model in models {
                    if let name = model["name"] as? String,
                       let size = model["size"] as? Int {
                        let sizeGB = Double(size) / 1_000_000_000
                        print("   - \(name) (\(String(format: "%.1f", sizeGB)) GB)")
                    }
                }
            }
        } catch {
            print("❌ Failed to connect to Ollama: \(error)")
            print("   Make sure Ollama is running: ollama serve")
        }

        print()
    }

    // MARK: - Test 2: Rule Parsing

    static func testRuleParsing() async {
        print("📝 Test 2: AI Rule Parsing")
        print("-" + String(repeating: "-", count: 50))

        let testRules = [
            "Block all violent content and alert me immediately",
            "Log when my child visits social media sites",
            "Block adult content and redirect to safe search",
            "Alert me if someone searches for weapons or drugs"
        ]

        for (index, ruleText) in testRules.enumerated() {
            print("Test \(index + 1): \"\(ruleText)\"")

            do {
                let result = try await parseRule(ruleText)
                print("✅ Parsed successfully:")
                print("   Categories: \(result.categories.joined(separator: ", "))")
                print("   Actions: \(result.actions.joined(separator: ", "))")
                print("   Severity: \(result.severity)")
            } catch {
                print("❌ Failed: \(error)")
            }
            print()
        }
    }

    // MARK: - Test 3: Content Analysis

    static func testContentAnalysis() async {
        print("🔍 Test 3: Content Analysis")
        print("-" + String(repeating: "-", count: 50))

        let testContents = [
            "How to build a birdhouse - woodworking tutorial",
            "First-person shooter gameplay with graphic violence",
            "Explicit adult content - NSFW warning",
            "Educational documentary about ancient civilizations"
        ]

        for (index, content) in testContents.enumerated() {
            print("Test \(index + 1): \"\(content)\"")

            do {
                let isViolation = try await analyzeContent(content)
                if isViolation {
                    print("⚠️  Violation detected")
                } else {
                    print("✅ Content is safe")
                }
            } catch {
                print("❌ Failed: \(error)")
            }
            print()
        }
    }

    // MARK: - Helper Functions

    static func parseRule(_ text: String) async throws -> (categories: [String], actions: [String], severity: String) {
        let prompt = """
        Parse this parental control rule into structured data. Return ONLY valid JSON, no other text.

        Rule: "\(text)"

        Required JSON format:
        {
            "categories": ["violence", "adult", "social media", etc],
            "actions": ["block", "alert", "log", "redirect"],
            "severity": "low" or "medium" or "high" or "critical"
        }
        """

        let response = try await sendOllamaRequest(model: "mistral:7b-instruct", prompt: prompt)

        // Extract JSON from response (AI might include markdown formatting)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let categories = json["categories"] as? [String],
              let actions = json["actions"] as? [String],
              let severity = json["severity"] as? String else {
            throw TestError.invalidResponse("Failed to parse JSON from AI response")
        }

        return (categories, actions, severity)
    }

    static func analyzeContent(_ content: String) async throws -> Bool {
        let prompt = """
        Analyze if this content violates parental control rules. Return ONLY valid JSON.

        Content: "\(content)"

        Rules to check:
        - Block violent content
        - Block adult/NSFW content
        - Block drug/weapon related content

        Required JSON format:
        {
            "violation": true or false,
            "reason": "brief explanation"
        }
        """

        let response = try await sendOllamaRequest(model: "mistral:7b-instruct", prompt: prompt)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let violation = json["violation"] as? Bool else {
            throw TestError.invalidResponse("Failed to parse JSON from AI response")
        }

        return violation
    }

    static func sendOllamaRequest(model: String, prompt: String) async throws -> String {
        let url = URL(string: "http://localhost:11434/api/generate")!
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

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? String else {
            throw TestError.invalidResponse("No response from Ollama")
        }

        return response
    }

    static func extractJSON(from text: String) -> String {
        // Remove markdown code blocks if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        } else if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }

        // Find first { and last }
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            return String(cleaned[startIndex...endIndex])
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum TestError: Error {
        case invalidResponse(String)
    }
}
