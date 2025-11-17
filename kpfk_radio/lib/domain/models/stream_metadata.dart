import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../core/utils/string_utils.dart';

class ShowInfo extends Equatable {
  final String showName;
  final String host;
  final String time;
  final String? songTitle;
  final String? songArtist;
  final String? hostImage;

  const ShowInfo({
    required this.showName,
    required this.host,
    required this.time,
    this.songTitle,
    this.songArtist,
    this.hostImage,
  });

  factory ShowInfo.fromJson(Map<String, dynamic> json) {
    return ShowInfo(
      showName: StringUtils.decodeHtmlEntities(json['sh_name'] ?? ''),
      host: StringUtils.decodeHtmlEntities(json['sh_djname'] ?? ''),
      time: '${json['cur_start'] ?? ''}${json['cur_end'] != null ? ' - ${json['cur_end']}' : ''}',
      songTitle: json['pl_song'] != null ? StringUtils.decodeHtmlEntities(json['pl_song']) : null,
      songArtist: json['pl_artist'] != null ? StringUtils.decodeHtmlEntities(json['pl_artist']) : null,
      hostImage: json['sh_photo'],
    );
  }

  /// Returns true if this show has song information
  bool get hasSongInfo => 
      songTitle != null && 
      songTitle!.isNotEmpty &&
      songArtist != null && 
      songArtist!.isNotEmpty;

  /// Returns true if there is a host image available
  bool get hasHostImage => 
      hostImage != null && 
      hostImage!.isNotEmpty;

  @override
  List<Object?> get props => [showName, host, time, songTitle, songArtist, hostImage];

  @override
  String toString() {
    return 'ShowInfo(name: $showName, time: $time${hasSongInfo ? ', song: $songTitle by $songArtist' : ''})';
  }
}

class StreamMetadata extends Equatable {
  final ShowInfo previous;
  final ShowInfo current;
  final ShowInfo next;

  const StreamMetadata({
    required this.previous,
    required this.current,
    required this.next,
  });

  factory StreamMetadata.fromJson(dynamic jsonData) {
    if (jsonData is String) {
      jsonData = json.decode(jsonData);
    }
    
    if (jsonData is! List || jsonData.length < 3) {
      throw FormatException('Invalid API response format');
    }
    
    return StreamMetadata(
      previous: ShowInfo.fromJson({}),  // We don't use previous show info
      current: ShowInfo.fromJson(jsonData[1]['current']),
      next: ShowInfo.fromJson(jsonData[2]['next']),
    );
  }

  /// Returns true if the current show has song information
  bool get hasSongInfo => 
      current.songTitle != null && 
      current.songTitle!.isNotEmpty &&
      current.songArtist != null && 
      current.songArtist!.isNotEmpty;

  /// Returns true if there is a host image available
  bool get hasHostImage => 
      current.hostImage != null && 
      current.hostImage!.isNotEmpty;

  @override
  List<Object?> get props => [previous, current, next];

  @override
  String toString() {
    return 'StreamMetadata(current: $current, next: $next)';
  }
}
