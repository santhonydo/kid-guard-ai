import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP proxy service for monitoring and filtering web traffic
public class ProxyService {
    private let llmService: LLMService
    private let storageService: StorageService
    private var server: HTTPProxyServer?
    private let port: Int

    public init(llmService: LLMService, storageService: StorageService, port: Int = 8080) {
        self.llmService = llmService
        self.storageService = storageService
        self.port = port
    }

    public func start() throws {
        guard server == nil else {
            throw ProxyError.alreadyRunning
        }

        server = HTTPProxyServer(port: port, llmService: llmService, storageService: storageService)
        try server?.start()

        print("Proxy service started on port \(port)")
    }

    public func stop() {
        server?.stop()
        server = nil
        print("Proxy service stopped")
    }
}

/// Simple HTTP proxy server implementation
class HTTPProxyServer {
    private let port: Int
    private let llmService: LLMService
    private let storageService: StorageService
    private var isRunning = false

    init(port: Int, llmService: LLMService, storageService: StorageService) {
        self.port = port
        self.llmService = llmService
        self.storageService = storageService
    }

    func start() throws {
        guard !isRunning else { return }

        // Start HTTP server in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runServer()
        }

        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    private func runServer() {
        // Create socket
        let serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("Failed to create socket")
            return
        }

        // Allow socket reuse
        var yes: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        // Bind to port
        var serverAddress = sockaddr_in()
        serverAddress.sin_family = sa_family_t(AF_INET)
        serverAddress.sin_port = UInt16(port).bigEndian
        serverAddress.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &serverAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult >= 0 else {
            print("Failed to bind to port \(port)")
            close(serverSocket)
            return
        }

        // Listen for connections
        guard listen(serverSocket, 5) >= 0 else {
            print("Failed to listen on socket")
            close(serverSocket)
            return
        }

        print("HTTP Proxy Server listening on port \(port)")

        // Accept connections
        while isRunning {
            var clientAddress = sockaddr_in()
            var clientAddressLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let clientSocket = withUnsafeMutablePointer(to: &clientAddress) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &clientAddressLen)
                }
            }

            guard clientSocket >= 0 else { continue }

            // Handle request in background
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleRequest(clientSocket: clientSocket)
            }
        }

        close(serverSocket)
    }

    private func handleRequest(clientSocket: Int32) {
        defer { close(clientSocket) }

        // Read request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)

        guard bytesRead > 0 else { return }

        let requestData = Data(buffer[0..<bytesRead])
        guard let requestString = String(data: requestData, encoding: .utf8) else { return }

        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }

        let method = parts[0]
        let path = parts[1]

        // Handle different endpoints
        if path.hasPrefix("/api/") {
            handleAPIRequest(method: method, path: path, socket: clientSocket, body: requestString)
        } else if method == "CONNECT" {
            handleConnectRequest(host: path, socket: clientSocket)
        } else {
            handleProxyRequest(method: method, url: path, socket: clientSocket)
        }
    }

    private func handleAPIRequest(method: String, path: String, socket: Int32, body: String) {
        var response = ""
        var statusCode = 200
        var responseBody = ""

        switch (method, path) {
        case ("GET", "/api/health"):
            responseBody = "{\"status\":\"ok\",\"service\":\"kidguard-proxy\"}"

        case ("GET", "/api/rules"):
            let rules = storageService.loadRules()
            if let jsonData = try? JSONEncoder().encode(rules),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                responseBody = jsonString
            } else {
                statusCode = 500
                responseBody = "{\"error\":\"Failed to encode rules\"}"
            }

        case ("POST", "/api/analyze"):
            // Extract body from request
            if let bodyStart = body.range(of: "\r\n\r\n")?.upperBound {
                let requestBody = String(body[bodyStart...])
                responseBody = handleAnalyzeRequest(requestBody: requestBody)
            } else {
                statusCode = 400
                responseBody = "{\"error\":\"No request body\"}"
            }

        default:
            statusCode = 404
            responseBody = "{\"error\":\"Not found\"}"
        }

        response = "HTTP/1.1 \(statusCode) OK\r\n"
        response += "Content-Type: application/json\r\n"
        response += "Content-Length: \(responseBody.utf8.count)\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"
        response += "\r\n"
        response += responseBody

        response.withCString { bytes in
            write(socket, bytes, strlen(bytes))
        }
    }

    private func handleAnalyzeRequest(requestBody: String) -> String {
        struct AnalyzeRequest: Codable {
            let url: String?
            let content: String
        }

        struct AnalyzeResponse: Codable {
            let violated: Bool
            let violatedRules: [String]
            let analysis: String
            let action: String
        }

        guard let jsonData = requestBody.data(using: .utf8),
              let request = try? JSONDecoder().decode(AnalyzeRequest.self, from: jsonData) else {
            return "{\"error\":\"Invalid request format\"}"
        }

        // Load active rules
        let rules = storageService.loadRules().filter { $0.isActive }

        // Analyze content with AI
        Task {
            do {
                let result = try await llmService.analyzeContent(request.content, against: rules)

                // Create monitoring event
                let event = MonitoringEvent(
                    timestamp: Date(),
                    type: .webRequest,
                    url: request.url,
                    content: request.content,
                    screenshotPath: nil,
                    ruleViolated: result.violation ? rules.first?.id : nil,
                    action: result.recommendedAction,
                    severity: result.severity,
                    processed: true
                )

                storageService.saveEvent(event)

                let response = AnalyzeResponse(
                    violated: result.violation,
                    violatedRules: result.categories,
                    analysis: result.explanation,
                    action: result.recommendedAction.rawValue
                )

                if let responseData = try? JSONEncoder().encode(response),
                   let responseString = String(data: responseData, encoding: .utf8) {
                    return responseString
                } else {
                    return "{\"violated\":false,\"violatedRules\":[],\"analysis\":\"Failed to encode response\",\"action\":\"log\"}"
                }
            } catch {
                print("Analysis failed: \(error)")
                return "{\"violated\":false,\"violatedRules\":[],\"analysis\":\"Error analyzing content\",\"action\":\"log\"}"
            }
        }

        // Return synchronous response (async analysis happens in background)
        return "{\"violated\":false,\"violatedRules\":[],\"analysis\":\"Analyzing...\",\"action\":\"log\"}"
    }

    private func handleConnectRequest(host: String, socket: Int32) {
        // For HTTPS CONNECT requests, we would normally establish a tunnel
        // For now, just return connection established
        let response = "HTTP/1.1 200 Connection Established\r\n\r\n"
        response.withCString { bytes in
            write(socket, bytes, strlen(bytes))
        }
    }

    private func handleProxyRequest(method: String, url: String, socket: Int32) {
        // Forward the request and analyze the response
        guard let requestURL = URL(string: url) else {
            sendErrorResponse(socket: socket, message: "Invalid URL")
            return
        }

        // Create request
        var request = URLRequest(url: requestURL)
        request.httpMethod = method

        // Forward request (simplified - in production would preserve headers)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.sendErrorResponse(socket: socket, message: error.localizedDescription)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                self.sendErrorResponse(socket: socket, message: "No response")
                return
            }

            // Analyze response content
            if let content = String(data: data, encoding: .utf8) {
                Task {
                    await self.analyzeAndLogContent(url: url, content: content)
                }
            }

            // Forward response
            var responseString = "HTTP/1.1 \(httpResponse.statusCode) OK\r\n"
            for (key, value) in httpResponse.allHeaderFields {
                responseString += "\(key): \(value)\r\n"
            }
            responseString += "\r\n"

            responseString.withCString { bytes in
                write(socket, bytes, strlen(bytes))
            }

            data.withUnsafeBytes { bytes in
                write(socket, bytes.baseAddress, data.count)
            }
        }

        task.resume()
    }

    private func sendErrorResponse(socket: Int32, message: String) {
        let response = "HTTP/1.1 500 Internal Server Error\r\n"
            + "Content-Type: text/plain\r\n"
            + "Content-Length: \(message.utf8.count)\r\n"
            + "\r\n"
            + message

        response.withCString { bytes in
            write(socket, bytes, strlen(bytes))
        }
    }

    private func analyzeAndLogContent(url: String, content: String) async {
        let rules = storageService.loadRules().filter { $0.isActive }

        do {
            let result = try await llmService.analyzeContent(content, against: rules)

            let event = MonitoringEvent(
                timestamp: Date(),
                type: .webRequest,
                url: url,
                content: content,
                screenshotPath: nil,
                ruleViolated: result.violation ? rules.first?.id : nil,
                action: result.recommendedAction,
                severity: result.severity,
                processed: true
            )

            storageService.saveEvent(event)

            if result.violation {
                print("⚠️ Rule violation detected for \(url)")
                print("   Categories: \(result.categories.joined(separator: ", "))")
                print("   Action: \(result.recommendedAction.rawValue)")
            }
        } catch {
            print("Failed to analyze content: \(error)")
        }
    }
}

public enum ProxyError: Error {
    case alreadyRunning
    case failedToStart
    case bindError

    public var localizedDescription: String {
        switch self {
        case .alreadyRunning:
            return "Proxy service is already running"
        case .failedToStart:
            return "Failed to start proxy service"
        case .bindError:
            return "Failed to bind to port"
        }
    }
}
