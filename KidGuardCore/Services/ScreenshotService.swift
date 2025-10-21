import Foundation
import CoreGraphics
import AppKit

public protocol ScreenshotServiceDelegate: AnyObject {
    func screenshotService(_ service: ScreenshotService, didCaptureScreenshot event: MonitoringEvent)
    func screenshotService(_ service: ScreenshotService, didFailWithError error: Error)
}

public class ScreenshotService: ObservableObject {
    public weak var delegate: ScreenshotServiceDelegate?
    
    private var timer: Timer?
    private let fileManager = FileManager.default
    private let screenshotsDirectory: URL
    
    @Published public var isCapturing = false
    @Published public var captureInterval: TimeInterval = 10.0
    
    public init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        screenshotsDirectory = appSupport.appendingPathComponent("KidGuardAI/Screenshots")
        
        // Create screenshots directory
        try? fileManager.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
    }
    
    public func startCapturing() {
        guard !isCapturing else { return }
        
        // Request screen recording permission
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            return
        }
        
        isCapturing = true
        
        timer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            self?.captureScreenshot()
        }
    }
    
    public func stopCapturing() {
        timer?.invalidate()
        timer = nil
        isCapturing = false
    }
    
    public func setCaptureInterval(_ interval: TimeInterval) {
        captureInterval = max(5.0, interval) // Minimum 5 seconds
        
        if isCapturing {
            stopCapturing()
            startCapturing()
        }
    }
    
    private func captureScreenshot() {
        Task {
            do {
                let screenshot = try await captureMainDisplay()
                let event = MonitoringEvent(
                    type: .screenshot,
                    screenshotPath: screenshot,
                    action: .log,
                    severity: .low
                )
                
                await MainActor.run {
                    delegate?.screenshotService(self, didCaptureScreenshot: event)
                }
            } catch {
                await MainActor.run {
                    delegate?.screenshotService(self, didFailWithError: error)
                }
            }
        }
    }
    
    private func captureMainDisplay() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ScreenshotError.captureFailed)
                    return
                }
                
                let displayID = CGMainDisplayID()
                
                guard let image = CGDisplayCreateImage(displayID) else {
                    continuation.resume(throwing: ScreenshotError.captureFailed)
                    return
                }
                
                let filename = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
                let fileURL = self.screenshotsDirectory.appendingPathComponent(filename)
                
                guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, kUTTypePNG, 1, nil) else {
                    continuation.resume(throwing: ScreenshotError.saveFailed)
                    return
                }
                
                CGImageDestinationAddImage(destination, image, nil)
                
                if CGImageDestinationFinalize(destination) {
                    continuation.resume(returning: fileURL.path)
                } else {
                    continuation.resume(throwing: ScreenshotError.saveFailed)
                }
            }
        }
    }
    
    public func cleanupOldScreenshots(olderThan days: Int = 7) {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        
        do {
            let files = try fileManager.contentsOfDirectory(at: screenshotsDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                guard file.pathExtension.lowercased() == "png" else { continue }
                
                let attributes = try fileManager.attributesOfItem(atPath: file.path)
                if let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to cleanup old screenshots: \(error)")
        }
    }
}

public enum ScreenshotError: Error {
    case captureFailed
    case saveFailed
    case permissionDenied
    
    public var localizedDescription: String {
        switch self {
        case .captureFailed:
            return "Failed to capture screenshot"
        case .saveFailed:
            return "Failed to save screenshot"
        case .permissionDenied:
            return "Screen recording permission denied"
        }
    }
}