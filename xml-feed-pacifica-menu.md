# XML Feed Pacifica Menu - Migration Guide

## Overview
This document provides complete instructions for migrating the XML feed functionality that appears under the WordPress content in the Pacifica Foundation menu. This includes the XML parser, affiliate station models, repository, and the responsive grid UI that displays Pacifica Network Affiliates.

## Core Components to Migrate

### 1. Data Models

#### AffiliateStation Model
**File**: `lib/domain/models/affiliate_station.dart`
```dart
class AffiliateStation {
  final String title;
  final String description;
  final String link;

  AffiliateStation({
    required this.title,
    required this.description,
    required this.link,
  });

  @override
  String toString() {
    return 'AffiliateStation(title: $title, description: $description, link: $link)';
  }
}
```

### 2. Data Repository with XML Parser

#### AffiliateRepository
**File**: `lib/data/repositories/affiliate_repository.dart`
```dart
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../../domain/models/affiliate_station.dart';

class AffiliateRepository {
  static const String xmlUrl = 'https://docs.pacifica.org/affiliates/pacifica_affiliates.xml';

  Future<List<AffiliateStation>> fetchAffiliates() async {
    final response = await http.get(Uri.parse(xmlUrl));
    if (response.statusCode != 200) throw Exception('Failed to load affiliates');
    final document = XmlDocument.parse(response.body);
    return document.findAllElements('item').map((node) {
      return AffiliateStation(
        title: node.getElement('title')?.innerText ?? '',
        description: node.getElement('description')?.innerText ?? '',
        link: node.getElement('link')?.innerText ?? '',
      );
    }).toList();
  }
}
```

### 3. UI Component - Affiliate Buttons Section

#### AffiliateButtonsSection Widget
**File**: `lib/presentation/widgets/affiliate_buttons_section.dart`
```dart
import 'package:flutter/material.dart';
import '../theme/font_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/affiliate_repository.dart';
import '../../domain/models/affiliate_station.dart';

class AffiliateButtonsSection extends StatelessWidget {
  const AffiliateButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AffiliateStation>>(
      future: AffiliateRepository().fetchAffiliates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Failed to load affiliates', style: TextStyle(color: Colors.red))));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final affiliates = snapshot.data!;
        
        // Determine column count based on screen width (same logic as main grid)
        final width = MediaQuery.of(context).size.width;
        final isTablet = width > 600;
        final isSmallDevice = width < 380; // Small device detection for this page only
        final crossAxisCount = isTablet ? 4 : 2;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
              child: Text(
                'Pacifica Network Affiliates',
                style: AppTextStyles.showTitle.copyWith(
                  fontSize: 20,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: affiliates.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // Much taller cards for small devices (LOWER ratio = taller cards)
                childAspectRatio: isSmallDevice ? 1.8 : 2.2,
              ),
              itemBuilder: (context, i) {
                final affiliate = affiliates[i];
                return Card(
                  color: const Color(0xFF23252B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final url = Uri.parse(affiliate.link);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Padding(
                      // Adjust padding for small devices to prevent overflow
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallDevice ? 8 : 12, 
                        horizontal: 12
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            affiliate.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: isSmallDevice ? 14 : 16, // Smaller font for small devices
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallDevice ? 2 : 4), // Less spacing for small devices
                          Text(
                            affiliate.description,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isSmallDevice ? 12 : 14, // Smaller font for small devices
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
```

### 4. Integration with Main Pacifica Page

#### Updated PacificaAppsPage with XML Feed Section
**File**: `lib/presentation/pages/pacifica_apps_page.dart` (Addition to existing code)

Add the import:
```dart
import '../widgets/affiliate_buttons_section.dart';
```

Update the ListView in `_buildPacificaAppsView()`:
```dart
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
    _buildGridView(context, state.items), // WordPress content grid
    const AffiliateButtonsSection(), // XML feed content grid
  ],
);
```

## XML Feed Structure

The XML feed follows RSS 2.0 format and is fetched from:
**URL**: `https://docs.pacifica.org/affiliates/pacifica_affiliates.xml`

### Expected XML Structure:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
<channel>
<title>Pacifica Network Affiliates</title>
<description>List of Pacifica Network affiliate stations</description>
<item>
<title>KPFK</title>
<link>https://www.kpfk.org/</link>
<description>Los Angeles, CA</description>
</item>
<item>
<title>KPFA</title>
<link>https://kpfa.org/</link>
<description>Berkeley, CA</description>
</item>
<item>
<title>Beware the Radio</title>
<link>https://bewaretheradio.com/</link>
<description>London, Great Britain</description>
</item>
</channel>
</rss>
```

### XML Parsing Process:
1. **HTTP Request**: Fetch XML content from the URL
2. **Parse Document**: Use `XmlDocument.parse()` to create XML document
3. **Extract Items**: Find all `<item>` elements in the XML
4. **Map to Models**: Convert each XML item to `AffiliateStation` object
5. **Extract Fields**:
   - `title`: Station name (e.g., "KPFK")
   - `description`: Location (e.g., "Los Angeles, CA") 
   - `link`: Website URL (e.g., "https://www.kpfk.org/")

## Required Dependencies

### pubspec.yaml additions:
```yaml
dependencies:
  # XML Processing
  xml: ^6.5.0
  
  # URL Launcher (if not already included)
  url_launcher: ^6.2.5
  
  # HTTP requests (if not already included)
  http: ^1.1.0
```

## Testing

### XML Parsing Test
**File**: `test/xml_parsing_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

void main() {
  test('XML parsing test for Pacifica affiliates', () {
    // Test XML parsing with the provided XML structure
    const xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
<channel>
<title>Pacifica Network Affiliates</title>
<description>List of Pacifica Network affiliate stations</description>
<item>
<title>KPFK</title>
<link>https://www.kpfk.org/</link>
<description>Los Angeles, CA</description>
</item>
<item>
<title>KPFA</title>
<link>https://kpfa.org/</link>
<description>Berkeley, CA</description>
</item>
<item>
<title>Beware the Radio</title>
<link>https://bewaretheradio.com/</link>
<description>London, Great Britain</description>
</item>
</channel>
</rss>''';

    final document = XmlDocument.parse(xmlContent);
    final items = document.findAllElements('item');
    
    expect(items.length, 3);
    
    final firstItem = items.first;
    expect(firstItem.getElement('title')?.innerText, 'KPFK');
    expect(firstItem.getElement('description')?.innerText, 'Los Angeles, CA');
    expect(firstItem.getElement('link')?.innerText, 'https://www.kpfk.org/');
    
    debugPrint('XML parsing test passed - structure is compatible');
  });
}
```

## Updated File Structure

```
lib/
├── main.dart
├── data/
│   └── repositories/
│       ├── pacifica_repository.dart  # WordPress API
│       └── affiliate_repository.dart # XML RSS Feed  
├── domain/
│   └── models/
│       ├── pacifica_item.dart       # WordPress content model
│       └── affiliate_station.dart   # XML feed model
├── presentation/
│   ├── bloc/
│   │   └── pacifica_bloc.dart       # WordPress content state management
│   ├── pages/
│   │   └── pacifica_apps_page.dart  # Main page with both sections
│   ├── widgets/
│   │   └── affiliate_buttons_section.dart # XML feed grid widget
│   └── theme/
│       ├── app_theme.dart
│       └── font_constants.dart
test/
└── xml_parsing_test.dart           # XML parsing unit test
```

## Key Features of XML Feed Section

1. **RSS 2.0 XML Parsing**: Robust XML parsing with error handling
2. **Responsive Grid Layout**: Matches the main WordPress content grid (2 columns on phones, 4 on tablets)
3. **Small Device Optimization**: Adjusted card ratios, fonts, and spacing for small screens
4. **External Link Handling**: Opens affiliate websites in external browser
5. **Loading States**: Loading spinner while fetching XML data
6. **Error Handling**: Graceful error display if XML fails to load
7. **Card Design**: Dark theme cards with station name and location
8. **FutureBuilder Integration**: Efficient async data loading
9. **Text Overflow Protection**: Ellipsis for long station names/descriptions
10. **Consistent Styling**: Matches the overall Pacifica Foundation theme

## Implementation Steps

1. **Add XML dependency**: Update `pubspec.yaml` with `xml: ^6.5.0`
2. **Create affiliate model**: Implement `AffiliateStation` class
3. **Create XML repository**: Implement `AffiliateRepository` with XML parsing
4. **Create affiliate widget**: Implement `AffiliateButtonsSection` grid
5. **Update main page**: Add affiliate section to `PacificaAppsPage`
6. **Test XML parsing**: Run the unit test to verify XML compatibility
7. **Test responsive design**: Verify grid layout on different screen sizes
8. **Test external links**: Verify affiliate links open correctly
9. **Handle edge cases**: Test network errors and malformed XML
10. **Polish styling**: Fine-tune card design and spacing

## Usage Example

The XML feed section automatically appears below the WordPress content grid when you include the `AffiliateButtonsSection` widget in your ListView. It will:

- Fetch affiliate data from the XML feed
- Display a "Pacifica Network Affiliates" header in red
- Show affiliate stations in a responsive grid
- Allow users to tap cards to visit affiliate websites
- Handle loading and error states gracefully

This provides a complete secondary content section that complements the WordPress API content, giving users access to both Pacifica Foundation sister stations and network affiliates in a unified interface.