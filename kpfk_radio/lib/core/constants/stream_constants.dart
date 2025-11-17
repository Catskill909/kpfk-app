class StreamConstants {
  // Direct Icecast stream endpoint
  static const String streamUrl = 'https://streams.pacifica.org:9000/kpfk_128';

  // Legacy baseUrl kept for reference (no longer used for streaming)
  static const String baseUrl = 'https://streams.pacifica.org:9000';
  static const String legacyStreamUrl = '$baseUrl/kpfk_128';

  static const String metadataUrl = 'http://localhost:8000/proxy.php';
  static const String proxyUrl = 'http://localhost:8000/proxy.php';
  static const String hostImageUrl = 'https://confessor.kpfk.org/';

  // Audio Configuration
  static const int defaultBufferSize = 20; // seconds
  static const int preBufferSize = 5; // seconds
  static const int metadataRefreshInterval = 30; // seconds
  static const int metadataCacheDuration = 300; // seconds (5 minutes)

  // Notification Configuration
  static const String notificationChannelId = 'com.kpfkfm.radio.audio';
  static const String notificationChannelName = 'KPFK Radio';
  static const bool notificationOngoing = true;

  // Station Information
  static const String stationName = 'KPFK';
  static const String stationSlogan = 'Pacifica Radio';
  static const String stationWebsite = 'https://www.kpfk.org';
  static const String stationLogo = 'https://confessor.kpfk.org/pix/KPFK.png';

  // Menu URLs
  static const String scheduleUrl = 'https://www.kpfk.org/schedule/';
  static const String playlistUrl = 'https://www.kpfk.org/playlist/';
  static const String showArchiveUrl = 'https://archive.kpfk.org/?mob=1';
  static const String donateUrl =
      'https://docs.pacifica.org/kpfk/kpfk-privacy.php';
  static const String aboutUrl =
      'https://docs.pacifica.org/kpfk/kpfk-privacy.php';
  static const String pacificaUrl =
      'https://pacificanetwork.org/about-pacifica-foundation/pacifica-foundation/';
  static const String privacyPolicyUrl =
      'https://docs.pacifica.org/kpfk/kpfk-privacy.php';

  // Social Media URLs
  static const String facebookUrl = 'https://www.facebook.com/KPFK90.7/';
  static const String twitterUrl = 'https://x.com/KPFK/';
  static const String instagramUrl = 'https://www.instagram.com/kpfk/';
  static const String youtubeUrl = 'https://www.youtube.com/@KPFKTV/videos/';
  static const String emailAddress = 'gm@kpfk.org';

  // Error Messages
  static const String connectionError =
      'Connection lost. Attempting to reconnect...';
  static const String bufferError = 'Buffering... Please wait.';
  static const String playbackError = 'Playback error. Retrying...';
  static const String metadataError = 'Unable to fetch station information';
}
