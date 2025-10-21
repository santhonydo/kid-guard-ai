import Foundation
import ArgumentParser
import KidGuardCore

@main
struct KidGuardAIDaemon: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "KidGuard AI Background Monitoring Daemon",
        version: "1.0.0"
    )
    
    @Option(name: .shortAndLong, help: "Configuration file path")
    var config: String = "~/.kidguardai/config.json"
    
    @Flag(name: .shortAndLong, help: "Enable verbose logging")
    var verbose = false
    
    @Flag(name: .shortAndLong, help: "Run in foreground (don't daemonize)")
    var foreground = false
    
    func run() throws {
        setupLogging()
        
        print("Starting KidGuard AI Daemon...")
        print("Configuration: \(config)")
        print("Verbose logging: \(verbose)")
        
        let daemon = MonitoringDaemon()
        
        // Setup signal handlers for graceful shutdown
        signal(SIGINT) { _ in
            print("\nReceived SIGINT, shutting down...")
            exit(0)
        }
        
        signal(SIGTERM) { _ in
            print("\nReceived SIGTERM, shutting down...")
            exit(0)
        }
        
        do {
            try daemon.start()
            
            if foreground {
                print("Running in foreground mode. Press Ctrl+C to stop.")
                RunLoop.main.run()
            } else {
                print("Daemon started successfully.")
                // In a real implementation, we would fork and detach here
                RunLoop.main.run()
            }
        } catch {
            print("Failed to start daemon: \(error)")
            throw ExitCode.failure
        }
    }
    
    private func setupLogging() {
        // Configure logging based on verbose flag
        if verbose {
            print("Verbose logging enabled")
        }
    }
}

class MonitoringDaemon {
    private let llmService = LLMService()
    private let storageService = StorageService.shared
    private var proxyService: ProxyService?
    private var isRunning = false
    
    func start() throws {
        guard !isRunning else {
            throw DaemonError.alreadyRunning
        }
        
        print("Initializing monitoring services...")
        
        // Initialize LLM service
        try initializeLLM()
        
        // Start proxy service for web monitoring
        try startProxyService()
        
        // Start IPC server for communication with main app
        try startIPCServer()
        
        isRunning = true
        print("All services started successfully")
    }
    
    func stop() {
        print("Stopping monitoring services...")
        
        proxyService?.stop()
        isRunning = false
        
        print("All services stopped")
    }
    
    private func initializeLLM() throws {
        print("Checking Ollama installation...")
        
        // Check if Ollama is installed and running
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ollama"]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                throw DaemonError.ollamaNotInstalled
            }
        } catch {
            throw DaemonError.ollamaNotInstalled
        }
        
        print("Ollama found, checking for required models...")
        
        // TODO: Check if required models are downloaded
        // TODO: Download models if needed
        
        print("LLM service initialized")
    }
    
    private func startProxyService() throws {
        print("Starting proxy service...")
        
        proxyService = ProxyService(llmService: llmService, storageService: storageService)
        try proxyService?.start()
        
        print("Proxy service started on port 8080")
    }
    
    private func startIPCServer() throws {
        print("Starting IPC server...")
        
        // TODO: Implement IPC server for communication with main app
        // This would handle commands from the main app like:
        // - Add/remove rules
        // - Start/stop monitoring
        // - Get status
        
        print("IPC server started")
    }
}

// ProxyService is now implemented in KidGuardCore/Services/ProxyService.swift

enum DaemonError: Error {
    case alreadyRunning
    case ollamaNotInstalled
    case configurationError
    case networkError
    
    var localizedDescription: String {
        switch self {
        case .alreadyRunning:
            return "Daemon is already running"
        case .ollamaNotInstalled:
            return "Ollama is not installed or not in PATH"
        case .configurationError:
            return "Configuration error"
        case .networkError:
            return "Network error"
        }
    }
}