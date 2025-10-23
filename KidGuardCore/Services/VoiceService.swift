import Speech
import AVFoundation

public protocol VoiceServiceDelegate: AnyObject {
    func voiceService(_ service: VoiceService, didRecognize text: String)
    func voiceService(_ service: VoiceService, didFailWithError error: Error)
}

public class VoiceService: NSObject, ObservableObject {
    public weak var delegate: VoiceServiceDelegate?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    @Published public var isListening = false
    @Published public var isAuthorized = false
    
    public override init() {
        super.init()
        checkAuthorization()
    }
    
    public func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAuthorized = status == .authorized
            }
        }
    }
    
    public func startListening() throws {
        print("🎤 Starting voice input...")
        print("🎤 Speech authorized: \(isAuthorized)")
        print("🎤 Audio engine running: \(audioEngine.isRunning)")

        guard isAuthorized else {
            print("❌ Speech recognition not authorized")
            throw VoiceError.notAuthorized
        }

        // Stop if already running and reset audio engine
        if audioEngine.isRunning {
            print("🎤 Audio engine already running, stopping first...")
            stopListening()
            // Give it a moment to fully stop
            Thread.sleep(forTimeInterval: 0.2)
        }

        // If still running, recreate the audio engine entirely
        if audioEngine.isRunning {
            print("🎤 Recreating audio engine...")
            audioEngine = AVAudioEngine()
        }

        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session (iOS only)
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var shouldStop = false

            if let result = result {
                let recognizedText = result.bestTranscription.formattedString

                if result.isFinal {
                    self?.delegate?.voiceService(self!, didRecognize: recognizedText)
                    shouldStop = true
                }
            }

            if let error = error {
                let nsError = error as NSError
                // Ignore "no speech detected" error - just means user hasn't spoken yet
                if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 1107 {
                    self?.delegate?.voiceService(self!, didFailWithError: error)
                    shouldStop = true
                }
            }

            if shouldStop {
                self?.stopListening()
            }
        }

        // Auto-stop after 5 seconds of listening
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if self?.isListening == true {
                self?.stopListening()
                // Trigger final recognition if we got any partial results
                self?.recognitionRequest?.endAudio()
            }
        }
        
        // Configure microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()

        do {
            try audioEngine.start()
            print("✅ Audio engine started successfully")
            print("🎤 Listening for speech...")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            throw VoiceError.microphoneNotAuthorized
        }

        DispatchQueue.main.async {
            self.isListening = true
        }
    }
    
    public func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            if audioEngine.inputNode.numberOfInputs > 0 {
                audioEngine.inputNode.removeTap(onBus: 0)
            }
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    public func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)
    }
    
    private func checkAuthorization() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            isAuthorized = true
        case .denied, .restricted, .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
}

public enum VoiceError: Error {
    case notAuthorized
    case microphoneNotAuthorized
    case alreadyListening
    case unableToCreateRequest

    public var localizedDescription: String {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please grant permission in System Settings > Privacy & Security > Speech Recognition"
        case .microphoneNotAuthorized:
            return "Microphone access not authorized. Please grant permission in System Settings > Privacy & Security > Microphone"
        case .alreadyListening:
            return "Already listening"
        case .unableToCreateRequest:
            return "Unable to create speech recognition request"
        }
    }
}