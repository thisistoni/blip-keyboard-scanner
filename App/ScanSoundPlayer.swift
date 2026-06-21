import AVFoundation

@MainActor
final class ScanSoundPlayer {
    static let shared = ScanSoundPlayer()

    private var player: AVAudioPlayer?

    private init() {}

    func playIfEnabled(_ isEnabled: Bool) {
        guard isEnabled else { return }

        do {
            if player == nil {
                guard let url = Bundle.main.url(forResource: "blip", withExtension: "wav") else { return }
                player = try AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
            }

            player?.currentTime = 0
            player?.play()
        } catch {
            player = nil
        }
    }
}
