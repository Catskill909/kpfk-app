class StreamConstants {
  // Use HTTPS M3U playlist - CONFIRMED WORKING on Android by user
  static const String streamUrl = 'https://docs.pacifica.org/wpfw/wpfw.m3u';

  // Legacy baseUrl kept for reference (no longer used for streaming)
  static const String baseUrl = 'https://streams.pacifica.org:9000';
  static const String legacyStreamUrl = '$baseUrl/wpfw_128';

  static const String metadataUrl = 'http://localhost:8000/proxy.php';
  static const String proxyUrl = 'http://localhost:8000/proxy.php';
  static const String hostImageUrl = 'https://confessor.wpfwfm.org/';

  // Audio Configuration
  static const int defaultBufferSize = 20; // seconds
  static const int preBufferSize = 5; // seconds
  static const int metadataRefreshInterval = 30; // seconds
  static const int metadataCacheDuration = 300; // seconds (5 minutes)

  // Notification Configuration
  static const String notificationChannelId = 'com.wpfw.radio.audio';
  static const String notificationChannelName = 'WPFW Radio';
  static const bool notificationOngoing = true;

  // Station Information
  static const String stationName = 'WPFW';
  static const String stationSlogan = 'Jazz and Justice';
  static const String stationWebsite = 'https://www.wpfwfm.org';
  static const String stationLogo = 'https://confessor.wpfwfm.org/pix/WPFW.png';

  // Menu URLs
  static const String scheduleUrl =
      'https://confessor.wpfwfm.org/playlist/pub_sched.php';
  static const String playlistUrl =
      'https://confessor.wpfwfm.org/playlist/pl_shows.php';
  static const String showArchiveUrl = 'https://archive.wpfwfm.org/?mob=1';
  static const String donateUrl = 'https://pledge.wpfwfm.org/index.php';
  static const String aboutUrl = 'https://wpfwfm.org/';
  static const String pacificaUrl =
      'https://pacificanetwork.org/about-pacifica-foundation/pacifica-foundation/';
  static const String privacyPolicyUrl = 'https://docs.pacifica.org/wpfw/wpfw-privacy.php';

  // Social Media URLs
  static const String facebookUrl = 'https://www.facebook.com/wpfwdc/';
  static const String twitterUrl = 'https://x.com/wpfwdc?lang=en';
  static const String instagramUrl = 'https://www.instagram.com/wpfwdc/?hl=en';
  static const String youtubeUrl =
      'https://www.youtube.com/channel/UCGojlOAfo0AEqNyIrILh8iw';
  static const String emailAddress = 'contact@wpfwdc.org';

  // Error Messages
  static const String connectionError =
      'Connection lost. Attempting to reconnect...';
  static const String bufferError = 'Buffering... Please wait.';
  static const String playbackError = 'Playback error. Retrying...';
  static const String metadataError = 'Unable to fetch station information';
}
