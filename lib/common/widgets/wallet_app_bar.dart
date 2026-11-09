import 'package:flutter/material.dart';

/// App bar for the pages behind the profile's wallet cards. The page itself
/// stays in the app's neutral look; only a small badge in the card's colour
/// ties it to the card (like the travel ID's badge). The pages open as
/// sheets (app/sheet_page.dart), so it has a drag handle and a close button
/// instead of a back arrow.
class WalletAppBar extends AppBar {
  WalletAppBar({
    super.key,
    required Color color,
    required Color onColor,
    required IconData icon,
    required String title,
    List<Widget>? actions,
  }) : super(
          automaticallyImplyLeading: false,
          actions: [...?actions, const CloseButton(), const SizedBox(width: 4)],
          toolbarHeight: 68,
          titleSpacing: 20,
          flexibleSpace: Builder(
            builder: (context) => Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          title: Builder(
            builder: (context) => Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: onColor, size: 18),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
        );
}
