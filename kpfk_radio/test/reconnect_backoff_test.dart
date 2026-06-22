import 'package:flutter_test/flutter_test.dart';
import 'package:kpfk_radio/services/audio_service/kpfk_audio_handler.dart';

void main() {
  group('KPFKAudioHandler.reconnectBackoff', () {
    test('grows exponentially: 2s, 4s, 8s, 16s', () {
      expect(KPFKAudioHandler.reconnectBackoff(1), const Duration(seconds: 2));
      expect(KPFKAudioHandler.reconnectBackoff(2), const Duration(seconds: 4));
      expect(KPFKAudioHandler.reconnectBackoff(3), const Duration(seconds: 8));
      expect(KPFKAudioHandler.reconnectBackoff(4), const Duration(seconds: 16));
    });

    test('caps at 30s', () {
      expect(KPFKAudioHandler.reconnectBackoff(5), const Duration(seconds: 30));
      expect(KPFKAudioHandler.reconnectBackoff(10), const Duration(seconds: 30));
    });

    test('never returns less than 2s', () {
      expect(KPFKAudioHandler.reconnectBackoff(0), const Duration(seconds: 2));
    });
  });
}
