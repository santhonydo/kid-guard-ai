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
    private let audioEngine = AVAudioEngine()
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
        guard isAuthorized else {
            throw VoiceError.notAuthorized
        }
        
        guard !audioEngine.isRunning else {
            throw VoiceError.alreadyListening
        }
        
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                let recognizedText = result.bestTranscription.formattedString
                
                if result.isFinal {
                    self?.delegate?.voiceService(self!, didRecognize: recognizedText)
                    self?.stopListening()
                }
            }
            
            if let error = error {
                self?.delegate?.voiceService(self!, didFailWithError: error)
                self?.stopListening()
            }
        }
        
        // Configure microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isListening = true
        }
    }
    
    public func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
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
    case alreadyListening
    case unableToCreateRequest
    
    public var localizedDescription: String {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .alreadyListening:
            return "Already listening"
        case .unableToCreateRequest:
            return "Unable to create speech recognition request"
        }
    }
}