import Foundation
import MediaPlayer
import AVFoundation
import UIKit

class MetadataController {
    // Forensic: Timer to log current lockscreen metadata every second
    private var forensicLogTimer: Timer?
    
    // CRITICAL FIX: Timer to periodically reapply metadata to override just_audio_background
    private var metadataGuardTimer: Timer?
    
    // Enhanced recovery tracking
    private var recoveryAttemptCount: Int = 0
    private var lastRecoveryTime: Date?
    
    // Call this once at app startup to start forensic logging
    func startForensicMetadataLogging() {
        forensicLogTimer?.invalidate()
        forensicLogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            let session = AVAudioSession.sharedInstance()
            print("[FORENSIC] Current MPNowPlayingInfoCenter: \(info)")
            print("[FORENSIC] AVAudioSession: category=\(session.category), isOtherAudioPlaying=\(session.isOtherAudioPlaying)")
            
            // CRITICAL FIX: Check if metadata has been overridden by just_audio_background
            if let currentTitle = info[MPMediaItemPropertyTitle] as? String,
               let currentArtist = info[MPMediaItemPropertyArtist] as? String,
               let lastTitle = self.lastTitle,
               let lastArtist = self.lastArtist,
               (currentTitle != lastTitle || currentArtist != lastArtist) {
                print("[FORENSIC][OVERRIDE] Detected metadata override by just_audio_background!")
                print("[FORENSIC][OVERRIDE] Expected: '\(lastTitle)' by '\(lastArtist)'")
                print("[FORENSIC][OVERRIDE] Current: '\(currentTitle)' by '\(currentArtist)'")
                
                // Force reapply our metadata
                self.reapplyLastMetadata()
            }
        }
    }

    // Call this to stop forensic logging
    func stopForensicMetadataLogging() {
        forensicLogTimer?.invalidate()
        forensicLogTimer = nil
    }
    
    // CRITICAL FIX: Start a timer to periodically reapply metadata
    func startMetadataGuard() {
        metadataGuardTimer?.invalidate()
        // Only set up a guard if an override is detected (see forensic logging)
        // The forensic logger will call reapplyLastMetadata() if an override is detected.
        print("[GUARD] Metadata guard is now event-driven, not periodic.")
    }
    
    // CRITICAL FIX: Reapply the last known metadata
    private func reapplyLastMetadata() {
        guard let lastTitle = self.lastTitle,
              let lastArtist = self.lastArtist else {
            return
        }
        
        print("[GUARD] Reapplying metadata: '\(lastTitle)' by '\(lastArtist)'")
        self.updateMetadata(
            title: lastTitle,
            artist: lastArtist,
            artworkUrl: self.lastArtworkUrl,
            isPlaying: self.lastIsPlaying,
            forceUpdate: true
        )
    }

    static let shared = MetadataController()
    private var methodChannel: FlutterMethodChannel?
    private var lastTitle: String?
    private var lastArtist: String?
    private var lastArtworkUrl: String?
    private var lastIsPlaying: Bool = true
    private var lastForceUpdate: Bool = false
    
    // Debounce timer for lockscreen metadata updates
    private var debounceTimer: Timer?
    private var pendingMetadata: (title: String, artist: String, artworkUrl: String?, isPlaying: Bool, forceUpdate: Bool)?
    
    // Background task to keep app alive during updates
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    private init() {}
    
    func setMethodChannel(_ channel: FlutterMethodChannel) {
        self.methodChannel = channel
        // Ensure audio session is configured at startup
        configureAudioSession()
        // Start verification task to ensure lockscreen is working
        startForensicMetadataLogging()
        // CRITICAL FIX: Start metadata guard to override just_audio_background
        startMetadataGuard()
        
        // Add forensic logging for play, pause, and toggle remote command events
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { event in
            print("[REMOTE] Play command received at \(Date())")
            return .success
        }
        commandCenter.pauseCommand.addTarget { event in
            print("[REMOTE] Pause command received at \(Date())")
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { event in
            print("[REMOTE] Toggle command received at \(Date())")
            return .success
        }
    }
    
    /// Robustly configure AVAudioSession with detailed error logging and return success status
    @discardableResult
    func configureAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        var success = true
        
        do {
            print("[AUDIO] Attempting to set AVAudioSession category to .playback")
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            print("[AUDIO] Category set successfully")
        } catch {
            print("[AUDIO][ERROR] Failed to set category: \(error)")
            success = false
        }
        
        do {
            print("[AUDIO] Attempting to activate AVAudioSession")
            try session.setActive(true)
            print("[AUDIO] AVAudioSession activated successfully")
        } catch {
            print("[AUDIO][ERROR] Failed to activate AVAudioSession: \(error)")
            success = false
            
            // Implement special recovery for error -50 (session busy)
            if let error = error as NSError?, error.code == -50 {
                print("[AUDIO][RECOVERY] Error -50 detected (session busy). Attempting recovery after delay...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    do {
                        try session.setActive(true)
                        print("[AUDIO][RECOVERY] Successfully activated audio session after retry")
                    } catch {
                        print("[AUDIO][ERROR] Recovery attempt also failed: \(error)")
                    }
                }
            }
        }
        
        return success
    }
    
    /// Debounced, main-threaded lockscreen metadata update with defensive placeholder guard
    func updateMetadata(title: String, artist: String, artworkUrl: String?, isPlaying: Bool, forceUpdate: Bool) {
        // CRITICAL FIX: Store last metadata for reapplication
        self.lastTitle = title
        self.lastArtist = artist
        self.lastArtworkUrl = artworkUrl
        self.lastIsPlaying = isPlaying
        
        // EXPERT GUARD: Block placeholder metadata from ever reaching lockscreen
        let lowerTitle = title.lowercased()
        let lowerArtist = artist.lowercased()
        if lowerTitle.contains("loading stream") || lowerArtist.contains("connecting") {
            print("[EXPERT BLOCK] Ignoring placeholder metadata: title='\(title)', artist='\(artist)'")
            return
        }
        // --- DEFENSIVE PLACEHOLDER GUARD ---
        let placeholderTitles: Set<String> = ["Loading stream...", "Connecting...", "", "WPFW Radio", "WPFW Stream"]
        let placeholderArtists: Set<String> = ["Connecting...", "", "Live Stream"]
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if placeholderTitles.contains(trimmedTitle) || placeholderArtists.contains(trimmedArtist) {
            print("[BLOCKED] Placeholder metadata blocked from iOS lockscreen update: title=\"\(title)\", artist=\"\(artist)\"")
            return
        }
        // --- END PLACEHOLDER GUARD ---
        
        // Verify AVAudioSession before even attempting to update
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback {
            print("[AUDIO][PREEMPTIVE] AVAudioSession issues detected before update, fixing proactively")
            configureAudioSession()
        }
        
        // Debounce rapid updates (batch within 250ms)
        pendingMetadata = (title, artist, artworkUrl, isPlaying, forceUpdate)
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            self?.performMetadataUpdate()
        }
    }

    /// Actually perform the lockscreen metadata update (runs on main thread)
    private func performMetadataUpdate() {
        guard let meta = pendingMetadata else { return }
        pendingMetadata = nil
        
        // Start background task to ensure update completes even in background
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Cleanup if expired
            guard let self = self else { return }
            if self.backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = .invalid
            }
        }
        
        DispatchQueue.main.async {
            // Verify audio session before updating
            let session = AVAudioSession.sharedInstance()
            if session.category != .playback {
                print("[AUDIO][WARNING] AVAudioSession status incorrect, reconfiguring before update")
                if !self.configureAudioSession() {
                    print("[AUDIO][RECOVERY] Audio session configuration failed, scheduling retry")
                    // If configuration fails, retry metadata update after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.pendingMetadata = meta
                        self.performMetadataUpdate()
                    }
                    
                    // End background task if we're going to retry
                    if self.backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                        self.backgroundTaskID = .invalid
                    }
                    return
                }
            }
            
            // Only update if changed or forced
            if !meta.forceUpdate &&
                meta.title == self.lastTitle &&
                meta.artist == self.lastArtist &&
                meta.artworkUrl == self.lastArtworkUrl &&
                meta.isPlaying == self.lastIsPlaying {
                print(" No significant metadata change; skipping update.")
                
                // End background task
                if self.backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                    self.backgroundTaskID = .invalid
                }
                return
            }
            
            self.lastTitle = meta.title
            self.lastArtist = meta.artist
            self.lastArtworkUrl = meta.artworkUrl
            self.lastIsPlaying = meta.isPlaying
            self.lastForceUpdate = meta.forceUpdate

            // Forensic: Log playback state and session status
            print("[FORENSIC] performMetadataUpdate: isPlaying=\(meta.isPlaying), playbackRate=\(meta.isPlaying ? 1.0 : 0.0), AVAudioSession category=\(session.category), isOtherAudioPlaying=\(session.isOtherAudioPlaying)")
            
            // Double-check audio session settings
            // Always try to ensure session is active before updating metadata
            do {
                print("[AUDIO][RECOVERY] Ensuring AVAudioSession is active before metadata update")
                try session.setActive(true)
                print("[AUDIO][RECOVERY] AVAudioSession activation confirmed")
            } catch {
                print("[AUDIO][ERROR] Failed to activate AVAudioSession: \(error)")
            }

            // CRITICAL FIX: Include MPMediaItemPropertyPlaybackDuration
            let nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyTitle: meta.title,
                MPMediaItemPropertyArtist: meta.artist,
                MPNowPlayingInfoPropertyPlaybackRate: meta.isPlaying ? 1.0 : 0.0,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
                MPMediaItemPropertyPlaybackDuration: 0,
                MPNowPlayingInfoPropertyIsLiveStream: true,
                // CRITICAL FIX: Add a timestamp to ensure the dictionary is always different
                // This forces iOS to update the display even if content appears the same
                "_timestamp": Date().timeIntervalSince1970
            ]

            // Log update attempt
            print("[UPDATE] MPNowPlayingInfoCenter: Title=\"\(meta.title)\", Artist=\"\(meta.artist)\", isPlaying=\(meta.isPlaying), force=\(meta.forceUpdate)")

            // Artwork (asynchronously load artwork to avoid blocking the main thread)
            if let urlString = meta.artworkUrl, let url = URL(string: urlString) {
                URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                    guard let self = self else { return }
                    let updatedNowPlayingInfo = nowPlayingInfo
                    if let data = data, let image = UIImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        // Always set a fresh, complete dictionary atomically
                        var freshInfo = updatedNowPlayingInfo
                        freshInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = freshInfo
                        print("[METADATA] Atomically updated NowPlayingInfoCenter with artwork at \(Date())\nMetadata: \(freshInfo)")
                    } else if let error = error {
                        print(" ERROR: Failed to load artwork image: \(error)")
                    }
                    DispatchQueue.main.async {
                        // Verify the update worked properly
                        self.verifyMetadataUpdateSucceeded(expectedTitle: meta.title, expectedArtist: meta.artist)
                        
                        // End background task when complete
                        if self.backgroundTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                            self.backgroundTaskID = .invalid
                        }
                    }
                }.resume()
            } else {
                // No artwork URL or failed to parse URL, update without artwork
                print("[FORENSIC] Setting MPNowPlayingInfoCenter (no artwork): \(nowPlayingInfo)")
                // Always set a fresh, complete dictionary atomically
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                print("[FORENSIC] MPNowPlayingInfoCenter set (no artwork, atomic update)")
                
                // Verify the update worked properly
                self.verifyMetadataUpdateSucceeded(expectedTitle: meta.title, expectedArtist: meta.artist)
                
                // End background task when complete
                if self.backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                    self.backgroundTaskID = .invalid
                }
            }
        }
    }

    
    func clearMetadata() {
        print("[FORENSIC] Clearing MPNowPlayingInfoCenter")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        print("[FORENSIC] MPNowPlayingInfoCenter cleared")
        print(" MPNowPlayingInfoCenter cleared")
    }
    
    /// New method to verify metadata actually appeared and retry if needed
    private func verifyMetadataUpdateSucceeded(expectedTitle: String, expectedArtist: String, retryCount: Int = 0) {
        // Don't retry too many times
        if retryCount >= 3 {
            print("[FORENSIC][VERIFY] Abandoning verification after 3 retry attempts")
            return
        }
        
        // Check after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            let currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            let currentTitle = currentInfo[MPMediaItemPropertyTitle] as? String
            let currentArtist = currentInfo[MPMediaItemPropertyArtist] as? String
            let currentRate = currentInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0
            
            print("[FORENSIC][VERIFY] Expected: '\(expectedTitle)' by '\(expectedArtist)', rate=\(self.lastIsPlaying ? 1.0 : 0.0)")
            print("[FORENSIC][VERIFY] Current: '\(currentTitle ?? "nil")' by '\(currentArtist ?? "nil")' rate=\(currentRate)")
            
            // If metadata is missing or incorrect, retry with force
            if currentTitle != expectedTitle || currentArtist != expectedArtist || 
               (self.lastIsPlaying && currentRate == 0.0) || (!self.lastIsPlaying && currentRate > 0.0) {
                print("[FORENSIC][RECOVERY] Metadata verification failed - retrying update with force")
                
                // Force reconfiguration of audio session
                self.configureAudioSession()
                
                // Re-send metadata with force flag
                self.updateMetadata(title: expectedTitle, 
                                   artist: expectedArtist, 
                                   artworkUrl: self.lastArtworkUrl, 
                                   isPlaying: self.lastIsPlaying, 
                                   forceUpdate: true)
                
                // Schedule another verification
                self.verifyMetadataUpdateSucceeded(expectedTitle: expectedTitle, 
                                                expectedArtist: expectedArtist,
                                                retryCount: retryCount + 1)
            } else {
                print("[FORENSIC][VERIFY] Metadata verification successful!")
                self.recoveryAttemptCount = 0
            }
        }
    }
}
