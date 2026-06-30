import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/stream_constants.dart';
import '../theme/font_constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: StreamConstants.emailAddress,
    );
    if (!await launchUrl(emailLaunchUri)) {
      throw Exception('Could not launch email');
    }
  }

  Widget _buildSocialIcons(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallPhone = size.shortestSide < 380;
    final iconSize =
        isSmallPhone ? 20.0 : 28.0; // Smaller icons for small devices
    final horizontalPadding = isSmallPhone ? 12.0 : 24.0;
    final verticalPadding =
        isSmallPhone ? 6.0 : 16.0; // Much less vertical padding

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(Icons.facebook, size: iconSize, color: Colors.white),
            tooltip: 'Facebook',
            onPressed: () => _launchUrl(StreamConstants.facebookUrl),
          ),
          IconButton(
            icon: Icon(Icons.camera_alt, size: iconSize, color: Colors.white),
            tooltip: 'Instagram',
            onPressed: () => _launchUrl(StreamConstants.instagramUrl),
          ),
          IconButton(
            icon: Icon(Icons.play_circle_filled,
                size: iconSize, color: Colors.white),
            tooltip: 'YouTube',
            onPressed: () => _launchUrl(StreamConstants.youtubeUrl),
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/x_logo.svg',
              width: iconSize,
              height: iconSize,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            tooltip: 'X',
            onPressed: () => _launchUrl(StreamConstants.twitterUrl),
          ),
          IconButton(
            icon: Icon(Icons.email, size: iconSize, color: Colors.white),
            tooltip: 'Email Us',
            onPressed: _launchEmail,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallPhone = size.shortestSide < 380;
    final headerPadding =
        isSmallPhone ? 4.0 : 16.0; // Much smaller padding for small devices
    final iconSize = isSmallPhone ? 24.0 : 28.0;
    final listTileHorizontalPadding = isSmallPhone ? 12.0 : 24.0;
    final listTileVerticalPadding =
        isSmallPhone ? 2.0 : 4.0; // Tighter spacing between drawer items

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: const Color.fromARGB(1, 255, 255, 255),
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: isSmallPhone
                  ? SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Image.asset(
                            'assets/images/header.png',
                            fit: BoxFit.contain,
                            height: 52.0, // Larger logo with breathing room
                          ),
                        ),
                      ),
                    )
                  : DrawerHeader(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(headerPadding),
                          child: Image.asset(
                            'assets/images/header.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.home, size: iconSize),
                      title: Text(
                        'Home',
                        style: AppTextStyles.drawerMenuItemForDevice(size)
                            .copyWith(
                          fontSize: isSmallPhone
                              ? 16.0
                              : 18.0, // Readable font for small devices
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: listTileHorizontalPadding,
                          vertical: listTileVerticalPadding),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.calendar_month, size: iconSize),
                      title: Text(
                        'Program Schedule',
                        style: AppTextStyles.drawerMenuItemForDevice(size)
                            .copyWith(
                          fontSize: isSmallPhone
                              ? 16.0
                              : 18.0, // Readable font for small devices
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: listTileHorizontalPadding,
                          vertical: listTileVerticalPadding),
                      onTap: () {
                        Navigator.pop(context);
                        _launchUrl(StreamConstants.scheduleUrl);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.radio, size: iconSize),
                      title: Text(
                        'Show Archive',
                        style: AppTextStyles.drawerMenuItemForDevice(size)
                            .copyWith(
                          fontSize: isSmallPhone
                              ? 16.0
                              : 18.0, // Readable font for small devices
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: listTileHorizontalPadding,
                          vertical: listTileVerticalPadding),
                      onTap: () {
                        Navigator.pop(context);
                        _launchUrl(StreamConstants.showArchiveUrl);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.podcasts, size: iconSize),
                      title: Text(
                        'Podcasts',
                        style: AppTextStyles.drawerMenuItemForDevice(size)
                            .copyWith(
                          fontSize: isSmallPhone
                              ? 16.0
                              : 18.0, // Readable font for small devices
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: listTileHorizontalPadding,
                          vertical: listTileVerticalPadding),
                      onTap: () {
                        Navigator.pop(context);
                        _launchUrl(StreamConstants.podcastsUrl);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.attach_money, size: iconSize),
                      title: Text(
                        'Donate',
                        style: AppTextStyles.drawerMenuItemForDevice(size)
                            .copyWith(
                          fontSize: isSmallPhone
                              ? 16.0
                              : 18.0, // Readable font for small devices
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: listTileHorizontalPadding,
                          vertical: listTileVerticalPadding),
                      onTap: () {
                        Navigator.pop(context);
                        _launchUrl(StreamConstants.donateUrl);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.language, size: iconSize),
                      title: Text(
                        'KPFK Website',
                        style: AppTextStyles.drawerMenuItemForDevice(size)
                            .copyWith(
                          fontSize: isSmallPhone
                              ? 16.0
                              : 18.0, // Readable font for small devices
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: listTileHorizontalPadding,
                          vertical: listTileVerticalPadding),
                      onTap: () {
                        Navigator.pop(context);
                        _launchUrl(StreamConstants.aboutUrl);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.info, size: iconSize),
                      title: Text(
                        'About Pacifica',
                        style: AppTextStyles.drawerMenuItemForDevice(size)
                            .copyWith(
                          fontSize: isSmallPhone
                              ? 16.0
                              : 18.0, // Readable font for small devices
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: listTileHorizontalPadding,
                          vertical: listTileVerticalPadding),
                      onTap: () {
                        Navigator.pop(context);
                        _launchUrl(StreamConstants.pacificaUrl);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.privacy_tip, size: iconSize),
                      title: Text(
                        'Privacy Policy',
                        style: AppTextStyles.drawerMenuItemForDevice(size)
                            .copyWith(
                          fontSize: isSmallPhone
                              ? 16.0
                              : 18.0, // Readable font for small devices
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: listTileHorizontalPadding,
                          vertical: listTileVerticalPadding),
                      onTap: () {
                        Navigator.pop(context);
                        _launchUrl(StreamConstants.privacyPolicyUrl);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: Colors.black,
              child: Column(
                children: [
                  const Divider(height: 1, color: Colors.white24),
                  _buildSocialIcons(context),
                  SizedBox(
                      height: isSmallPhone
                          ? 4.0
                          : 16.0), // Minimal bottom padding for small devices
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
