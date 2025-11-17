# Pacifica Network Affiliates Section – Flutter App Architecture Plan

## Objective
Add a new section to the app that displays Pacifica Network Affiliates as a text-only button grid/list, using data from the XML feed at https://starkey.digital/pacifica/pacifica_affiliates.xml. This must not affect the existing "Sister Stations" grid.

---

## 1. Data Model

Create a model for an affiliate station:
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
}
```

---

## 2. Data Fetching & Parsing
- Use the `http` package to fetch the XML.
- Use the `xml` package to parse the feed.
- Extract `<title>`, `<description>`, and `<link>` from each `<item>`.

---

## 3. Repository

Create a repository/service class to fetch and parse the XML:
```dart
class AffiliateRepository {
  Future<List<AffiliateStation>> fetchAffiliates() async {
    final response = await http.get(Uri.parse('https://starkey.digital/pacifica/pacifica_affiliates.xml'));
    if (response.statusCode != 200) throw Exception('Failed to load affiliates');
    final document = XmlDocument.parse(response.body);
    return document.findAllElements('item').map((node) {
      return AffiliateStation(
        title: node.getElement('title')?.text ?? '',
        description: node.getElement('description')?.text ?? '',
        link: node.getElement('link')?.text ?? '',
      );
    }).toList();
  }
}
```

---

## 4. State Management
- Use a `FutureBuilder` or a minimal Cubit/BLoC if desired for consistency.
- States: loading, error, loaded.

---

## 5. UI
- Section header: `Pacifica Network Affiliates` (styled in red, as in screenshot)
- Use a `ListView` or `GridView` (2 columns on mobile, more on tablet if desired)
- Each item is a button/card:
  - Title (bold, white)
  - Description (subtitle, gray)
  - On tap: open link with `url_launcher`

Example:
```dart
ListView.builder(
  itemCount: affiliates.length,
  itemBuilder: (context, i) {
    final affiliate = affiliates[i];
    return Card(
      color: Color(0xFF23252B),
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListTile(
        title: Text(affiliate.title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(affiliate.description, style: TextStyle(color: Colors.white70)),
        onTap: () async {
          final url = Uri.parse(affiliate.link);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  },
)
```

---

## 6. Integration
- Place this new section below the existing "Sister Stations" grid.
- Do not modify or touch the existing grid code.

---

## 7. Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.2.1
  xml: ^6.3.0
  url_launcher: ^6.2.5
```

---

## 8. File Structure
- `lib/domain/models/affiliate_station.dart` – model
- `lib/data/repositories/affiliate_repository.dart` – fetch & parse logic
- `lib/presentation/widgets/affiliate_buttons_section.dart` – UI section

---

## 9. Example Integration

In your main page (e.g., `pacifica_apps_page.dart`):
```dart
Column(
  children: [
    SisterStationsGrid(), // existing, untouched
    AffiliateButtonsSection(), // new section
  ],
)
```

---

## 10. Notes
- The existing "Sister Stations" grid (with images) must remain untouched.
- This new section is for text-only affiliate station buttons, matching the second screenshot provided.
- The XML feed is parsed for title, description, and link only.
- Tapping a button opens the affiliate's link in the external browser.
