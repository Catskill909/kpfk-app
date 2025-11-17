# Package Configuration Guide

## Core Packages Configuration

### Audio Packages

```yaml
dependencies:
  just_audio: ^0.9.34
  just_audio_background: ^0.0.1-beta.10
  audio_service: ^0.18.12
  audio_session: ^0.1.16
```

#### just_audio Configuration
```dart
final player = AudioPlayer();
await player.setAudioSource(
  AudioSource.uri(
    Uri.parse('https://streams.pacifica.org:9000/wpfw_128'),
    tag: MediaItem(
      id: 'wpfw_live',
      album: 'WPFW Live',
      title: 'Live Stream',
      artUri: Uri.parse('assets/station_logo.png'),
    ),
  ),
);
```

#### just_audio_background Setup
```dart
Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.wpfw.radio.audio',
    androidNotificationChannelName: 'WPFW Radio',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
  );
  runApp(MyApp());
}
```

### WebView Implementation

```yaml
dependencies:
  flutter_inappwebview: ^5.8.0  # Preferred over webview_flutter for advanced features
```

#### WebView Configuration
```dart
class WebViewConfig {
  static final settings = InAppWebViewSettings(
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    supportZoom: false,
    useHybridComposition: true,
    javaScriptEnabled: true,
    domStorage: true,
  );

  static final options = InAppWebViewGroupOptions(
    crossPlatform: settings,
    android: AndroidInAppWebViewOptions(
      useHybridComposition: true,
      mixedContentMode: AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    ),
    ios: IOSInAppWebViewOptions(
      allowsInlineMediaPlayback: true,
      allowsAirPlayForMediaPlayback: true,
    ),
  );
}
```

### Additional Essential Packages

```yaml
dependencies:
  path_provider: ^2.1.1
  shared_preferences: ^2.2.2
  flutter_bloc: ^8.1.3
  dio: ^5.3.3
  connectivity_plus: ^5.0.1
  device_info_plus: ^9.1.0
```

## Implementation Examples

### Audio Service Implementation

```dart
class AudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  Future<void> initialize() async {
    await _loadEmptyPlaylist();
    _notifyAudioHandlerAboutPlaybackEvents();
    _notifyAudioHandlerAboutPositionEvents();
    _listenForDurationChanges();
    _listenForCurrentSongIndexChanges();
    _listenForSequenceStateChanges();
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      print("Error: $e");
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
      ));
    });
  }
}
```

### WebView Integration Example

```dart
class RadioWebView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: Uri.parse('https://your-radio-website.com'),
      ),
      initialSettings: WebViewConfig.settings,
      onWebViewCreated: (controller) {
        // Setup JavaScript bridge
        controller.addJavaScriptHandler(
          handlerName: 'mediaMetadata',
          callback: (args) {
            // Handle metadata updates
            if (args.isNotEmpty) {
              final metadata = args.first;
              updateMediaSession(metadata);
            }
          },
        );
      },
      onLoadStop: (controller, url) async {
        // Inject custom JavaScript
        await controller.evaluateJavascript(source: '''
          // Your custom JavaScript for metadata tracking
          const observer = new MutationObserver((mutations) => {
            // Track metadata changes
            window.flutter_inappwebview.callHandler('mediaMetadata', {
              title: document.querySelector('.now-playing-title')?.textContent,
              artist: document.querySelector('.now-playing-artist')?.textContent,
            });
          });
          
          observer.observe(document.body, {
            subtree: true,
            childList: true,
            attributes: true
          });
        ''');
      },
    );
  }
}
```

### Metadata Service Implementation

```dart
class MetadataService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://streams.pacifica.org:9000';
  
  Future<StreamMetadata> fetchMetadata() async {
    try {
      final response = await _dio.get('$_baseUrl/info/index.html');
      return StreamMetadata.fromJson(response.data);
    } catch (e) {
      // Fallback to proxy
      final proxyResponse = await _dio.get('$_baseUrl/info/proxy.php');
      return StreamMetadata.fromJson(proxyResponse.data);
    }
  }
}

class StreamMetadata {
  final String currentSong;
  final String artist;
  final String showName;
  final DateTime timestamp;

  StreamMetadata({
    required this.currentSong,
    required this.artist,
    required this.showName,
    required this.timestamp,
  });

  factory StreamMetadata.fromJson(Map<String, dynamic> json) {
    return StreamMetadata(
      currentSong: json['current_song'] ?? '',
      artist: json['artist'] ?? '',
      showName: json['show_name'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
```

## Platform-Specific Configurations

### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>

    <application ...>
        <service android:name="com.ryanheise.audioservice.AudioService">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>

        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" >
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver> 
    </application>
</manifest>
```

### iOS Configuration

Add to `ios/Runner/Info.plist`:
```xml
<dict>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>fetch</string>
    </array>
</dict>
```

## Error Handling and Recovery

```dart
class StreamErrorHandler {
  static Future<void> handleError(
    AudioPlayer player,
    String streamUrl,
    Function(String) onError,
  ) async {
    try {
      await player.setUrl(streamUrl);
    } catch (e) {
      if (e is PlayerException) {
        // Handle player-specific errors
        onError('Player error: ${e.message}');
        await _attemptRecovery(player, streamUrl);
      } else {
        // Handle general errors
        onError('Stream error: $e');
      }
    }
  }

  static Future<void> _attemptRecovery(
    AudioPlayer player,
    String streamUrl,
  ) async {
    await player.stop();
    await Future.delayed(Duration(seconds: 2));
    await player.setUrl(streamUrl);
    await player.play();
  }
}
```

## Performance Optimization

### Memory Management
```dart
class CacheManager {
  static const int maxCacheSize = 50 * 1024 * 1024; // 50MB
  
  static Future<void> clearCache() async {
    final cacheDir = await getTemporaryDirectory();
    final files = cacheDir.listSync();
    
    for (var file in files) {
      if (file is File) {
        await file.delete();
      }
    }
  }
  
  static Future<void> manageCacheSize() async {
    final cacheDir = await getTemporaryDirectory();
    final files = cacheDir.listSync();
    int totalSize = 0;
    
    for (var file in files) {
      if (file is File) {
        totalSize += await file.length();
      }
    }
    
    if (totalSize > maxCacheSize) {
      await clearCache();
    }
  }
}
```

## Testing Guidelines

```dart
void main() {
  group('Audio Player Tests', () {
    late AudioPlayer player;
    late AudioHandler handler;

    setUp(() {
      player = AudioPlayer();
      handler = AudioHandler();
    });

    tearDown(() {
      player.dispose();
    });

    test('Stream initialization', () async {
      final result = await player.setUrl('https://streams.pacifica.org:9000/wpfw_128');
      expect(result, isNotNull);
    });

    test('Metadata parsing', () async {
      final metadata = await MetadataService().fetchMetadata();
      expect(metadata, isNotNull);
      expect(metadata.currentSong, isNotEmpty);
    });
  });
}