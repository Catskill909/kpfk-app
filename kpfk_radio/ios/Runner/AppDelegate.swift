import UIKit
import Flutter
import MediaPlayer
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    // Single metadata channel
    private var metadataChannel: FlutterMethodChannel?
    
    // Single AVAudioSession configuration
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("[AUDIO] Session configured with enhanced options")
        } catch {
            print("[AUDIO] Session configuration error: \(error)")
        }
    }
    
    // Set default metadata
    private func setupDefaultMetadata() {
        let nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: "KPFK 90.7 FM",
            MPMediaItemPropertyArtist: "Pacifica Radio",
            MPMediaItemPropertyAlbumTitle: "KPFK",
            MPNowPlayingInfoPropertyPlaybackRate: 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPMediaItemPropertyMediaType: MPMediaType.anyAudio.rawValue
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 1. Configure audio session
        configureAudioSession()
        
        // 2. DISABLED: Set default metadata (was overriding artwork)
        // setupDefaultMetadata() // DISABLED - This was clearing artwork with text-only metadata
        
        // 3. Set up Flutter controller
        let controller = window?.rootViewController as! FlutterViewController
        
        // 4. Set up metadata channel
        metadataChannel = FlutterMethodChannel(name: "com.kpfkfm.radio/metadata",
                                            binaryMessenger: controller.binaryMessenger)
        
        // 4b. Set up NOW PLAYING channel for IOSLockscreenService
        let nowPlayingChannel = FlutterMethodChannel(name: "com.kpfkfm.radio/now_playing",
                                                   binaryMessenger: controller.binaryMessenger)
        
        // 5. Set up method handler for metadata channel
        metadataChannel?.setMethodCallHandler({ (call, result) in
            switch call.method {
            case "updateMetadata":
                self.handleUpdateMetadata(call: call, result: result)
            case "keepAudioSessionAlive":
                // Reconfigure audio session to ensure it stays active
                self.configureAudioSession()
                result(true)
            case "channelTest":
                print("[METADATA] Channel test received from Flutter")
                result("Channel test successful")
            case "testMessage":
                result("Test received")
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        // 5b. Set up method handler for NOW PLAYING channel (IOSLockscreenService)
        nowPlayingChannel.setMethodCallHandler({ (call, result) in
            switch call.method {
            case "updateNowPlaying":
                self.handleUpdateNowPlaying(call: call, result: result)
            case "clearNowPlaying":
                self.handleClearNowPlaying(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        // 6. Set up remote commands
        setupRemoteCommandCenter()
        
        // 7. Register plugins
        GeneratedPluginRegistrant.register(with: self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Debounce timer for metadata updates
    private var metadataDebounceTimer: Timer?
    private var lastTitle: String?
    private var lastArtist: String?
    private var lastIsPlaying: Bool?
    private var lastArtworkUrl: String?
    private var cachedArtwork: MPMediaItemArtwork?
    private var pendingMetadataUpdate: [String: Any]?
    
    /// Apply the pending metadata update on the main thread
    private func applyPendingMetadataUpdate() {
        // Must be called on main thread
        DispatchQueue.main.async {
            guard let update = self.pendingMetadataUpdate else { return }
            
            // Extract values
            guard let title = update["title"] as? String,
                  let artist = update["artist"] as? String,
                  let isPlaying = update["isPlaying"] as? Bool else {
                print("[METADATA] Invalid pending metadata update")
                return
            }
            
            // Ensure AVAudioSession is active
            self.configureAudioSession()
            
            // Create metadata dictionary with additional required properties
            var nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyTitle: title,
                MPMediaItemPropertyArtist: artist,
                MPMediaItemPropertyAlbumTitle: "KPFK 90.7 FM",
                MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
                MPNowPlayingInfoPropertyIsLiveStream: true,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
                MPMediaItemPropertyMediaType: MPMediaType.anyAudio.rawValue
            ]
            
            // CRITICAL FIX: Always preserve existing artwork to prevent override clearing
            let currentArtworkUrl = update["artworkUrl"] as? String
            
            // First, get any existing artwork from the current now playing info
            let existingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
            let existingArtwork = existingInfo?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork
            
            // Use cached artwork if same URL, or preserve existing artwork, or use existing from now playing
            if let currentUrl = currentArtworkUrl, currentUrl == self.lastArtworkUrl, let cachedArtwork = self.cachedArtwork {
                // Same artwork URL - use cached artwork immediately
                nowPlayingInfo[MPMediaItemPropertyArtwork] = cachedArtwork
                print("[METADATA] ✅ Using cached artwork for same URL: \(currentUrl)")
            } else if let existingArtwork = existingArtwork {
                // Preserve existing artwork to prevent clearing
                nowPlayingInfo[MPMediaItemPropertyArtwork] = existingArtwork
                print("[METADATA] ✅ Preserving existing artwork to prevent override clearing")
            }
            
            // Set metadata (with preserved/cached artwork)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
            // Handle artwork download only if URL changed
            if let artworkUrl = currentArtworkUrl, artworkUrl != self.lastArtworkUrl {
                print("[METADATA] New artwork URL detected: '\(artworkUrl)'")
                if let url = URL(string: artworkUrl) {
                    print("[METADATA] Starting artwork download from: \(artworkUrl)")
                    // Load artwork asynchronously with retry mechanism
                    self.downloadArtworkWithRetry(url: url, artworkUrl: artworkUrl) { [weak self] image in
                        guard let self = self, let image = image else { return }
                        
                        print("[METADATA] ✅ Successfully loaded artwork image, size: \(image.size)")
                        
                        // Create and cache the artwork
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        self.cachedArtwork = artwork
                        self.lastArtworkUrl = artworkUrl
                        
                        // Update the current now playing info with artwork
                        var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        currentInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                        print("[METADATA] ✅ Successfully updated MPNowPlayingInfoCenter with new artwork")
                    }
                } else {
                    print("[METADATA] ❌ Invalid URL for artwork: '\(artworkUrl)'")
                }
            } else if currentArtworkUrl == nil {
                // Clear cached artwork if no URL provided
                self.cachedArtwork = nil
                self.lastArtworkUrl = nil
                print("[METADATA] ⚠️ No artwork URL provided - cleared cache")
            }
        }
    }
    
    /// Downloads artwork with retry mechanism for improved reliability
    private func downloadArtworkWithRetry(url: URL, artworkUrl: String, maxRetries: Int = 2, completion: @escaping (UIImage?) -> Void) {
        func attemptDownload(attempt: Int) {
            print("[METADATA] 🔄 Artwork download attempt \(attempt + 1)/\(maxRetries + 1) for: \(artworkUrl)")
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    // Log response details for diagnostics
                    if let httpResponse = response as? HTTPURLResponse {
                        print("[METADATA] 📡 HTTP Status: \(httpResponse.statusCode)")
                    }
                    
                    if let error = error {
                        print("[METADATA] ❌ Attempt \(attempt + 1) failed: \(error.localizedDescription)")
                        
                        // Retry if we haven't exceeded max attempts
                        if attempt < maxRetries {
                            let delay = Double(attempt + 1) // Progressive delay: 1s, 2s, 3s...
                            print("[METADATA] ⏳ Retrying in \(delay)s...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptDownload(attempt: attempt + 1)
                            }
                        } else {
                            print("[METADATA] ❌ All retry attempts failed for: \(artworkUrl)")
                            completion(nil)
                        }
                        return
                    }
                    
                    guard let data = data else {
                        print("[METADATA] ❌ No data received on attempt \(attempt + 1)")
                        
                        // Retry if we haven't exceeded max attempts
                        if attempt < maxRetries {
                            let delay = Double(attempt + 1)
                            print("[METADATA] ⏳ Retrying in \(delay)s...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptDownload(attempt: attempt + 1)
                            }
                        } else {
                            print("[METADATA] ❌ No data received after all retry attempts")
                            completion(nil)
                        }
                        return
                    }
                    
                    guard let image = UIImage(data: data) else {
                        print("[METADATA] ❌ Failed to create UIImage from \(data.count) bytes on attempt \(attempt + 1)")
                        
                        // Retry if we haven't exceeded max attempts
                        if attempt < maxRetries {
                            let delay = Double(attempt + 1)
                            print("[METADATA] ⏳ Retrying in \(delay)s...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptDownload(attempt: attempt + 1)
                            }
                        } else {
                            print("[METADATA] ❌ Failed to create image after all retry attempts")
                            completion(nil)
                        }
                        return
                    }
                    
                    // Success!
                    print("[METADATA] ✅ Artwork download successful on attempt \(attempt + 1)")
                    completion(image)
                }
            }.resume()
        }
        
        // Start the first attempt
        attemptDownload(attempt: 0)
    }
    
    private func handleUpdateMetadata(call: FlutterMethodCall, result: FlutterResult) {
        // Extract metadata from arguments
        guard let args = call.arguments as? [String: Any],
              let title = args["title"] as? String,
              let artist = args["artist"] as? String,
              let isPlaying = args["isPlaying"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGUMENTS", 
                                message: "Invalid arguments", 
                                details: nil))
            return
        }
        
        // ENHANCED PLACEHOLDER GUARD
        // Skip placeholder metadata during playback
        let placeholderTitles = ["Loading stream...", "Connecting...", "", "KPFK Radio", "KPFK Stream"]
        let placeholderArtists = ["Connecting...", "", "Live Stream"]
        let isPlaceholder = placeholderTitles.contains(title) || placeholderArtists.contains(artist)
        
        if isPlaceholder && isPlaying {
            print("[METADATA] Blocking placeholder during playback: \(title) by \(artist)")
            result(true) // Still return success
            return
        }
        
        // Skip if nothing has changed
        if title == lastTitle && artist == lastArtist && isPlaying == lastIsPlaying {
            print("[METADATA] Skipping identical update: \(title) by \(artist), playing=\(isPlaying)")
            result(true)
            return
        }
        
        // Store current values
        lastTitle = title
        lastArtist = artist
        lastIsPlaying = isPlaying
        
        // Store the entire arguments as the pending update
        pendingMetadataUpdate = args
        
        // Cancel any pending update
        metadataDebounceTimer?.invalidate()
        
        // Schedule a debounced update (250ms delay)
        metadataDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            self?.applyPendingMetadataUpdate()
        }
        
        // Log that we've queued the update
        print("[METADATA] Queued update for debouncing: \(title) by \(artist), playing=\(isPlaying)")
        
        result(true)
    }
    
    private func setupRemoteCommandCenter() {
        // Get command center
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Remove any existing handlers
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        
        // Add play handler
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.configureAudioSession()
            DispatchQueue.main.async {
                self?.metadataChannel?.invokeMethod("remotePlay", arguments: nil)
            }
            return .success
        }
        
        // Add pause handler
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.configureAudioSession()
            DispatchQueue.main.async {
                self?.metadataChannel?.invokeMethod("remotePause", arguments: nil)
            }
            return .success
        }
        
        // Add toggle handler
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.configureAudioSession()
            DispatchQueue.main.async {
                self?.metadataChannel?.invokeMethod("remoteTogglePlayPause", arguments: nil)
            }
            return .success
        }
        
        print("[REMOTE] Commands setup complete")
    }
    
    // MARK: - App Lifecycle Support
    
    // We're not using UIScene lifecycle methods as they require iOS 13+
    // Instead, we'll use the traditional app delegate methods
    
    // MARK: - App Lifecycle Methods
    
    // Called when app becomes active (either first launch or returning from background)
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        print("[LIFECYCLE] App did become active")
        // Ensure audio session is active when app becomes active
        configureAudioSession()
        
        // Refresh metadata if we have any
        if let title = lastTitle, let artist = lastArtist, let isPlaying = lastIsPlaying {
            print("[LIFECYCLE] Refreshing metadata on become active: \(title) by \(artist)")
            let metadata: [String: Any] = [
                "title": title,
                "artist": artist,
                "isPlaying": isPlaying,
                "forceUpdate": true
            ]
            pendingMetadataUpdate = metadata
            applyPendingMetadataUpdate()
        }
    }
    
    // Called when app enters foreground
    override func applicationWillEnterForeground(_ application: UIApplication) {
        super.applicationWillEnterForeground(application)
        print("[LIFECYCLE] App will enter foreground")
        // Ensure audio session is active when app comes to foreground
        configureAudioSession()
    }
    
    // Called when app enters background
    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        print("[LIFECYCLE] App did enter background")
        // No need to deactivate audio session as we want background audio
    }
    
    // Called when app is about to terminate
    override func applicationWillTerminate(_ application: UIApplication) {
        super.applicationWillTerminate(application)
        print("[LIFECYCLE] App will terminate")
        // Clean up any resources if needed
    }
    
    // MARK: - NOW PLAYING Channel Handlers (IOSLockscreenService)
    
    /// Handle updateNowPlaying method from IOSLockscreenService
    private func handleUpdateNowPlaying(call: FlutterMethodCall, result: FlutterResult) {
        // Extract metadata from arguments
        guard let args = call.arguments as? [String: Any],
              let title = args["title"] as? String,
              let artist = args["artist"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", 
                                message: "Invalid arguments for updateNowPlaying", 
                                details: nil))
            return
        }
        
        // Extract optional parameters
        let album = args["album"] as? String ?? "KPFK 90.7 FM"
        let artworkUrl = args["artworkUrl"] as? String
        let isPlaying = args["isPlaying"] as? Bool ?? true
        let duration = args["duration"] as? Int
        let position = args["position"] as? Int
        
        print("[NOW_PLAYING] Received updateNowPlaying: title='\(title)', artist='\(artist)', artworkUrl='\(artworkUrl ?? "nil")'")
        
        // ENHANCED PLACEHOLDER GUARD
        let placeholderTitles = ["Loading stream...", "Connecting...", "", "KPFK Radio", "KPFK Stream"]
        let placeholderArtists = ["Connecting...", "", "Live Stream"]
        let isPlaceholder = placeholderTitles.contains(title) || placeholderArtists.contains(artist)
        
        if isPlaceholder && isPlaying {
            print("[NOW_PLAYING] Blocking placeholder during playback: \(title) by \(artist)")
            result(true) // Still return success
            return
        }
        
        // Ensure AVAudioSession is active
        configureAudioSession()
        
        // Create metadata dictionary with required properties
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position != nil ? Double(position!) / 1000.0 : 0,
            MPMediaItemPropertyMediaType: MPMediaType.anyAudio.rawValue
        ]
        
        // Add duration if provided
        if let duration = duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(duration) / 1000.0
        }
        
        // CRITICAL FIX: Always preserve existing artwork to prevent clearing
        let existingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let existingArtwork = existingInfo?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork
        if let existingArtwork = existingArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = existingArtwork
            print("[NOW_PLAYING] ✅ Preserving existing artwork to prevent clearing")
        }
        
        // Set metadata (with preserved artwork if available)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("[NOW_PLAYING] Set metadata with preserved artwork")
        
        // Handle artwork asynchronously if provided
        if let artworkUrlString = artworkUrl, !artworkUrlString.isEmpty, let url = URL(string: artworkUrlString) {
            print("[NOW_PLAYING] Loading artwork from: \(artworkUrlString)")
            
            self.downloadArtworkWithRetry(url: url, artworkUrl: artworkUrlString) { image in
                guard let image = image else {
                    print("[NOW_PLAYING] ⚠️ Failed to load artwork after all retry attempts")
                    return
                }
                
                // Create artwork and update metadata
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                print("[NOW_PLAYING] ✅ Successfully updated metadata with artwork")
            }
        } else {
            print("[NOW_PLAYING] No artwork URL provided or empty")
        }
        
        result(true)
    }
    
    /// Handle clearNowPlaying method from IOSLockscreenService
    private func handleClearNowPlaying(result: FlutterResult) {
        print("[NOW_PLAYING] Clearing lockscreen metadata")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        result(true)
    }
}
