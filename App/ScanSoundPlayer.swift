import AVFoundation
import UIKit

@MainActor
final class ScanSoundPlayer {
    static let shared = ScanSoundPlayer()

    private var player: AVAudioPlayer?
    private let haptic = UINotificationFeedbackGenerator()

    private init() {}

    func prepareIfEnabled(_ isEnabled: Bool) {
        guard isEnabled else { return }

        haptic.prepare()
        prepareAudioPlayer()
    }

    func playIfEnabled(_ isEnabled: Bool) {
        guard isEnabled else { return }

        haptic.notificationOccurred(.success)
        prepareAudioPlayer()

        do {
            try configureAudioSession()
            player?.currentTime = 0
            player?.play()
        } catch {
            player = nil
        }
    }

    private func prepareAudioPlayer() {
        guard player == nil,
              let url = Bundle.main.url(forResource: "blip", withExtension: "mp3")
        else {
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 1
            player?.prepareToPlay()
        } catch {
            player = nil
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
    }
}
