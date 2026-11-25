import AVFoundation
import Flutter
import OSLog
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "HolidayAudio") {
      HolidayAudio.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private final class HolidayAudio: NSObject, FlutterPlugin, AVAudioPlayerDelegate {
  private static let trackAssets = [
    "assets/audio/workshop_lights.mp3",
    "assets/audio/sleigh_route.mp3",
    "assets/audio/snowfall_at_the_pole.mp3",
  ]
  private static let bellAsset = "assets/audio/sleigh_bells.mp3"
  private let log = OSLog(subsystem: "com.ozyunus.santasGiftRush", category: "HolidayAudio")

  private var trackIndex = 0
  private var musicPlayer: AVAudioPlayer?
  private var bellPlayer: AVAudioPlayer?
  private var musicEnabled = false
  private var interrupted = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "santas_gift_rush/holiday_audio",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(HolidayAudio(), channel: channel)
  }

  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(interruptionChanged(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setMusicPlaying":
      guard let playing = call.arguments as? Bool else {
        result(FlutterError(code: "invalid_argument", message: "Expected a playback flag.", details: nil))
        return
      }
      musicEnabled = playing
      if playing {
        startMusic()
      } else {
        musicPlayer?.pause()
        bellPlayer?.stop()
      }
      result(nil)
    case "playSleighBells":
      playBells()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    guard musicPlayer === player else { return }
    musicPlayer = nil
    trackIndex = (trackIndex + 1) % Self.trackAssets.count
    startMusic()
  }

  @objc private func interruptionChanged(_ notification: Notification) {
    guard
      let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType)
    else { return }
    if type == .began {
      interrupted = true
      musicPlayer?.pause()
      bellPlayer?.stop()
    } else {
      interrupted = false
      let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
      if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
        startMusic()
      }
    }
  }

  private func startMusic() {
    guard musicEnabled && !interrupted else { return }
    guard musicPlayer?.isPlaying != true else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.ambient, mode: .default)
      try session.setActive(true)
    } catch {
      os_log("Unable to activate holiday audio: %{public}@", log: log, type: .error, error.localizedDescription)
      return
    }

    if let current = musicPlayer, current.play() { return }
    musicPlayer = nil
    for _ in Self.trackAssets {
      let asset = Self.trackAssets[trackIndex]
      if let player = audioPlayer(for: asset, volume: 0.28), player.play() {
        player.delegate = self
        musicPlayer = player
        os_log("Playing %{public}@", log: log, type: .default, asset)
        return
      }
      trackIndex = (trackIndex + 1) % Self.trackAssets.count
    }
  }

  private func playBells() {
    guard musicEnabled && !interrupted else { return }
    bellPlayer = bellPlayer ?? audioPlayer(for: Self.bellAsset, volume: 0.38)
    bellPlayer?.currentTime = 0
    bellPlayer?.play()
  }

  private func audioPlayer(for asset: String, volume: Float) -> AVAudioPlayer? {
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    guard let url = Bundle.main.url(forResource: key, withExtension: nil) else {
      os_log("Missing holiday audio asset: %{public}@", log: log, type: .error, asset)
      return nil
    }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = volume
      return player
    } catch {
      os_log("Unable to load %{public}@: %{public}@", log: log, type: .error, asset, error.localizedDescription)
      return nil
    }
  }
}
