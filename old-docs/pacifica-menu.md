# Pacifica Foundation Menu Application - Migration Guide

## Overview
This document provides complete instructions for migrating ONLY the Pacifica Foundation menu functionality from the existing WPFW radio application to create a standalone Pacifica Foundation menu application. This includes the WordPress content reader, grid layout system, WebView integration, and associated UI components.

## Core Components to Migrate

### 1. Data Models

#### PacificaItem Model
**File**: `lib/domain/models/pacifica_item.dart`
```dart
class PacificaItem {
  final String title;
  final String link;
  final String excerpt;
  final String content;
  final String? imageUrl;

  PacificaItem({
    required this.title,
    required this.link,
    required this.excerpt,
    required this.content,
    this.imageUrl,
  });

  factory PacificaItem.fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    
    // Parse the featured media from _embedded data
    if (json['_embedded'] != null && 
        json['_embedded']['wp:featuredmedia'] != null && 
        json['_embedded']['wp:featuredmedia'].isNotEmpty) {
      final media = json['_embedded']['wp:featuredmedia'][0];
      imageUrl = media['media_details']?['sizes']?['medium']?['source_url'];
    }

    return PacificaItem(
      title: json['title']['rendered'] ?? '',
      link: json['link'] ?? '',
      excerpt: json['excerpt']['rendered'] ?? '',
      content: json['content']['rendered'] ?? '',
      imageUrl: imageUrl,
    );
  }

  @override
  String toString() {
    return 'PacificaItem(title: $title, link: $link, imageUrl: $imageUrl)';
  }
}
```

### 2. Data Repository

#### PacificaRepository
**File**: `lib/data/repositories/pacifica_repository.dart`
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/pacifica_item.dart';

class PacificaRepository {
  final client = http.Client();
  final String apiUrl = 'https://starkey.digital/wp-json/wp/v2/posts?_embed';

  Future<List<PacificaItem>> fetchItems() async {
    try {
      final response = await client.get(Uri.parse(apiUrl));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((item) => PacificaItem.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching items: $e');
    }
  }
}
```

### 3. State Management (BLoC)

#### PacificaBloc
**File**: `lib/presentation/bloc/pacifica_bloc.dart`
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/pacifica_repository.dart';
import '../../domain/models/pacifica_item.dart';

// Events
abstract class PacificaEvent extends Equatable {
  const PacificaEvent();

  @override
  List<Object> get props => [];
}

class FetchPacificaItems extends PacificaEvent {}
class RefreshPacificaItems extends PacificaEvent {}

// States
class PacificaState extends Equatable {
  final List<PacificaItem> items;
  final bool isLoading;
  final String? error;

  const PacificaState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  PacificaState copyWith({
    List<PacificaItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return PacificaState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [items, isLoading, error];
}

// BLoC
class PacificaBloc extends Bloc<PacificaEvent, PacificaState> {
  final PacificaRepository repository;

  PacificaBloc({required this.repository}) : super(const PacificaState(isLoading: true)) {
    on<FetchPacificaItems>(_onFetchItems);
    on<RefreshPacificaItems>(_onRefreshItems);
  }

  Future<void> _onFetchItems(FetchPacificaItems event, Emitter<PacificaState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final items = await repository.fetchItems();
      emit(state.copyWith(items: items, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onRefreshItems(RefreshPacificaItems event, Emitter<PacificaState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final items = await repository.fetchItems();
      emit(state.copyWith(items: items, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }
}
```

### 4. UI Components

#### Main Pacifica Apps Page
**File**: `lib/presentation/pages/pacifica_apps_page.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import '../bloc/pacifica_bloc.dart';
import '../../data/repositories/pacifica_repository.dart';
import '../../domain/models/pacifica_item.dart';
import '../theme/font_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PacificaAppsPage extends StatelessWidget {
  const PacificaAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PacificaBloc(
        repository: PacificaRepository(),
      )..add(FetchPacificaItems()),
      child: const _PacificaAppsView(),
    );
  }
}

class _PacificaAppsView extends StatelessWidget {
  const _PacificaAppsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF18191A),
      appBar: AppBar(
        backgroundColor: Color(0xFF18191A),
        title: Text(
          'Pacifica Foundation',
          style: AppTextStyles.drawerTitle,
        ),
      ),
      body: BlocBuilder<PacificaBloc, PacificaState>(
        builder: (context, state) {
          if (state.isLoading && state.items.isEmpty) {
            return _buildLoadingView();
          } else if (state.error != null && state.items.isEmpty) {
            return _buildErrorView(context, state.error!);
          } else {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    "Pacifica Foundation's Sister Stations",
                    style: AppTextStyles.showTitle.copyWith(
                      fontSize: 20,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildGridView(context, state.items),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 60),
          const SizedBox(height: 16),
          Text(
            'Failed to load content',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Colors.white,
              fontFamily: 'Oswald',
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              context.read<PacificaBloc>().add(FetchPacificaItems());
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(BuildContext context, List<PacificaItem> items) {
    // Determine column count based on screen width
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;
    final crossAxisCount = isTablet ? 4 : 2;
    
    return RefreshIndicator(
      onRefresh: () async {
        context.read<PacificaBloc>().add(RefreshPacificaItems());
      },
      color: Colors.white,
      backgroundColor: Colors.black87,
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.0,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildGridItem(context, items[index]);
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, PacificaItem item) {
    // Helper method to detect small phones for this page only
    bool isSmallDevice = MediaQuery.of(context).size.shortestSide < 380;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PacificaItemDetail(item: item),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSmallDevice ? Border.all(
            color: Colors.transparent,
            width: 0,
          ) : Border.all(
            color: Colors.white.withValues(red: 255, green: 255, blue: 255, alpha: 40),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 76),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSmallDevice ? 12 : 10),
          child: item.imageUrl != null
              ? Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 50,
                      ),
                    );
                  },
                )
              : Container(
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.image,
                    color: Colors.white54,
                    size: 50,
                  ),
                ),
        ),
      ),
    );
  }
}

// Detail page with WebView
class PacificaItemDetail extends StatelessWidget {
  final PacificaItem item;

  const PacificaItemDetail({super.key, required this.item});
  
  String _removeHtmlTags(String htmlString) {
    return htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF18191A),
      appBar: AppBar(
        backgroundColor: Color(0xFF18191A),
        title: Text(
          'Pacifica Foundation',
          style: AppTextStyles.drawerTitle,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(Uri.dataFromString(
          _wrapHtmlContent(item),
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8')!,
        ))),
        initialSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
          transparentBackground: true,
          useHybridComposition: true,
          allowsInlineMediaPlayback: true,
        ),
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final uri = navigationAction.request.url;
          if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
            await launchUrl(Uri.parse(uri.toString()));
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }

  String _wrapHtmlContent(PacificaItem item) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Oswald:wght@400;500;600&display=swap">
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: #121212;
            color: #ffffff;
            padding: 16px;
            max-width: 100%;
            word-wrap: break-word;
          }
          h1, h2, h3, h4, h5, h6 {
            font-family: 'Oswald', sans-serif;
            color: #ffffff;
          }
          h1 {
            font-size: 28px;
            margin-bottom: 16px;
            font-weight: 500;
          }
          img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
          }
          a {
            color: #4fc3f7;
            text-decoration: none;
          }
          p {
            line-height: 1.6;
            color: #e0e0e0;
          }
        </style>
      </head>
      <body>
        <h1>${_removeHtmlTags(item.title)}</h1>
        ${item.imageUrl != null ? '<img src="${item.imageUrl}" alt="${_removeHtmlTags(item.title)}">' : ''}
        ${item.content}
      </body>
      </html>
    ''';
  }
}
```

### 5. Theme and Styling

#### Font Constants
**File**: `lib/presentation/theme/font_constants.dart`
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  // Oswald font family for headers and important text
  static TextStyle get drawerTitle => GoogleFonts.oswald(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle get showTitle => GoogleFonts.oswald(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static TextStyle get sectionTitle => GoogleFonts.oswald(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
  );

  // System font for body text
  static TextStyle get bodyLarge => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.white,
    height: 1.5,
  );

  static TextStyle get bodyMedium => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.white70,
    height: 1.4,
  );
}
```

#### App Theme
**File**: `lib/presentation/theme/app_theme.dart`
```dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.red,
      primaryColor: const Color(0xFF0F0404),
      scaffoldBackgroundColor: const Color(0xFF18191A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF18191A),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF0F0404),
        secondary: Colors.red,
        surface: Color(0xFF18191A),
        background: Color(0xFF18191A),
      ),
    );
  }
}
```

## Required Dependencies

### pubspec.yaml
```yaml
name: pacifica_foundation
description: "Pacifica Foundation Menu Application"
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ^3.6.2

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_bloc: ^9.1.0
  equatable: ^2.0.7

  # Network & HTTP
  http: ^1.1.0

  # WebView
  flutter_inappwebview: ^6.1.8

  # URL Launcher
  url_launcher: ^6.2.5

  # UI & Fonts
  google_fonts: ^6.2.1
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

## Application Entry Point

### main.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'presentation/pages/pacifica_apps_page.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const PacificaFoundationApp());
}

class PacificaFoundationApp extends StatelessWidget {
  const PacificaFoundationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pacifica Foundation',
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const PacificaAppsPage(),
    );
  }
}
```

## File Structure

```
lib/
├── main.dart
├── data/
│   └── repositories/
│       └── pacifica_repository.dart
├── domain/
│   └── models/
│       └── pacifica_item.dart
├── presentation/
│   ├── bloc/
│   │   └── pacifica_bloc.dart
│   ├── pages/
│   │   └── pacifica_apps_page.dart
│   └── theme/
│       ├── app_theme.dart
│       └── font_constants.dart
```

## Key Features

1. **WordPress API Integration**: Fetches content from `https://starkey.digital/wp-json/wp/v2/posts?_embed`
2. **Responsive Grid Layout**: 2 columns on phones, 4 columns on tablets
3. **Image Loading with Error Handling**: Network images with fallback icons
4. **WebView Content Display**: Full HTML content rendering with custom CSS
5. **Pull-to-Refresh**: Refresh content with pull gesture
6. **Dark Theme**: Consistent dark theme throughout the app
7. **External Link Handling**: Opens external links in system browser
8. **Error States**: Proper error handling and retry functionality
9. **Loading States**: Loading indicators during data fetching
10. **Small Device Optimization**: Adjusted styling for small screens

## WordPress API Response Format

The application expects WordPress REST API responses with the following structure:

```json
[
  {
    "title": {
      "rendered": "Post Title"
    },
    "link": "https://example.com/post-url",
    "excerpt": {
      "rendered": "Post excerpt..."
    },
    "content": {
      "rendered": "<p>Full HTML content...</p>"
    },
    "_embedded": {
      "wp:featuredmedia": [
        {
          "media_details": {
            "sizes": {
              "medium": {
                "source_url": "https://example.com/image.jpg"
              }
            }
          }
        }
      ]
    }
  }
]
```

## Implementation Steps

1. **Create Flutter Project**: `flutter create pacifica_foundation`
2. **Add Dependencies**: Update `pubspec.yaml` with required dependencies
3. **Create File Structure**: Set up the directory structure as shown above
4. **Implement Data Layer**: Create models and repository
5. **Implement State Management**: Set up BLoC for state management
6. **Implement UI Layer**: Create pages and themes
7. **Test API Integration**: Verify WordPress API connectivity
8. **Test Responsive Design**: Test on various screen sizes
9. **Handle Edge Cases**: Implement error handling and offline states
10. **Polish UI/UX**: Fine-tune styling and user experience

This migration guide contains all the necessary components to recreate the Pacifica Foundation menu functionality as a standalone application.