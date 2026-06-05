import AVFoundation
import Foundation

@MainActor
final class LiveCoachingSpeechCoach: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var promptQueue: [String] = []
    private var activeSignature: String?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start(prompts: [String]) {
        let normalized = prompts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else { return }

        let signature = normalized.joined(separator: "|")
        guard activeSignature != signature else { return }

        activeSignature = signature
        promptQueue = normalized
        synthesizer.stopSpeaking(at: .immediate)
        configureAudioSession()
        speakNext()
    }

    func stop() {
        promptQueue = []
        activeSignature = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func speakNext() {
        guard !promptQueue.isEmpty, !synthesizer.isSpeaking else { return }
        let prompt = promptQueue.removeFirst()
        let utterance = AVSpeechUtterance(string: prompt)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.46
        utterance.pitchMultiplier = 1.02
        utterance.volume = 1.0
        utterance.postUtteranceDelay = 0.25
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // Speech still works with the default session on most devices; keep coaching non-blocking.
        }
        #endif
    }
}

extension LiveCoachingSpeechCoach: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.speakNext()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.promptQueue = []
        }
    }
}
