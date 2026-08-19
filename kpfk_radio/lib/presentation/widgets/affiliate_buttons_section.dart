import 'package:flutter/material.dart';
import '../theme/font_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/affiliate_repository.dart';
import '../../domain/models/affiliate_station.dart';

/// Affiliates tab: sticky search field pinned above a scannable list of
/// stations, with an intro blurb + live result count inside the scroll.
/// Phones get flat rows with hairline dividers (fast to scan for ~60 items);
/// tablets get a two-column grid of bordered cards.
class AffiliateButtonsSection extends StatefulWidget {
  const AffiliateButtonsSection({super.key});

  @override
  State<AffiliateButtonsSection> createState() =>
      _AffiliateButtonsSectionState();
}

class _AffiliateButtonsSectionState extends State<AffiliateButtonsSection> {
  // Cache the future so typing in the search field doesn't refetch the list.
  late final Future<List<AffiliateStation>> _future =
      AffiliateRepository().fetchAffiliates();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
      cursorColor: Colors.white70,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search stations\u2026',
        hintStyle: AppTextStyles.bodyMedium
            .copyWith(color: Colors.white38, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: const Color(0xFF232529),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AffiliateStation>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load affiliates',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final affiliates = snapshot.data!;
        final filtered = _query.isEmpty
            ? affiliates
            : affiliates
                .where((a) =>
                    a.title.toLowerCase().contains(_query) ||
                    a.description.toLowerCase().contains(_query))
                .toList();
        final isTablet = MediaQuery.of(context).size.width > 600;
        final bottomPad = 24 + MediaQuery.of(context).padding.bottom;

        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beyond its five sister stations, Pacifica programming reaches '
              'listeners through independent affiliate stations across the '
              'U.S. and around the world.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _query.isEmpty
                  ? '${affiliates.length} stations \u00b7 tap one to visit its website'
                  : '${filtered.length} of ${affiliates.length} stations',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white38),
            ),
            const SizedBox(height: 12),
          ],
        );

        final Widget results;
        if (filtered.isEmpty) {
          results = ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
            children: [
              intro,
              const SizedBox(height: 36),
              const Center(
                child: Icon(Icons.search_off, color: Colors.white24, size: 40),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'No stations match "${_searchController.text.trim()}"',
                  style:
                      AppTextStyles.bodyMedium.copyWith(color: Colors.white54),
                ),
              ),
            ],
          );
        } else if (isTablet) {
          results = ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
            children: [
              intro,
              // Two columns of rows that size themselves to their contents.
              // A GridView's childAspectRatio would pin each row's height to
              // the tile width, so at accessibility text sizes the two lines
              // of text grew past it and spilled out. IntrinsicHeight lets a
              // row grow with the text and keeps both cards in it equal.
              for (var i = 0; i < filtered.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _AffiliateTile(
                              affiliate: filtered[i], bordered: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: i + 1 < filtered.length
                              ? _AffiliateTile(
                                  affiliate: filtered[i + 1], bordered: true)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        } else {
          results = ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
            itemCount: filtered.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return intro;
              return _AffiliateTile(
                  affiliate: filtered[i - 1], bordered: false);
            },
          );
        }

        // Sticky search: pinned above the scrollable results.
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _buildSearchField(),
            ),
            Expanded(child: results),
          ],
        );
      },
    );
  }
}

class _AffiliateTile extends StatelessWidget {
  final AffiliateStation affiliate;
  final bool bordered;

  const _AffiliateTile({required this.affiliate, required this.bordered});

  Future<void> _open() async {
    final url = Uri.parse(affiliate.link);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                affiliate.title,
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                affiliate.description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white54,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.open_in_new, size: 15, color: Colors.white30),
      ],
    );

    if (bordered) {
      // Tablet: rounded hairline card.
      return Material(
        color: const Color(0xFF202226),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _open,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: content,
          ),
        ),
      );
    }

    // Phone: flat row with a hairline bottom divider.
    return InkWell(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: content,
      ),
    );
  }
}
