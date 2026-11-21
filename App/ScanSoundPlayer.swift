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

    /// A code added to a batch always vibrates: the scanner stays open, so with
    /// the sound off the haptic is the only hands-free sign. The sound still
    /// follows the setting.
    func playBatchAddition(soundEnabled: Bool) {
        guard soundEnabled else {
            haptic.notificationOccurred(.success)
            haptic.prepare()
            return
        }
        playIfEnabled(true)
    }

    /// A code that was seen but skipped as a duplicate: a different haptic and
    /// no sound, so it is not mistaken for an addition.
    func playBatchDuplicate() {
        haptic.notificationOccurred(.warning)
        haptic.prepare()
    }

    private func prepareAudioPlayer() {
        guard player == nil,
              let url = Bundle.main.url(forResource: "blip", withExtension: "mp3")
        else {
            return
        }

        do {
            // prepareToPlay activates audio too; establish mixing before preloading.
            try configureAudioSession()
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
