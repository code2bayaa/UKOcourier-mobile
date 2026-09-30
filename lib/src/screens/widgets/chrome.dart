/// The driver's four destinations, on top of the shared wireframe chrome in `uko_core`.
///
/// The measurements — the 66px bar, the 74×36 tabs, the 26px mark — are the wireframe's and live in
/// `uko_core/src/ui/chrome`. What is the driver's own is *which* tabs, and they are not the rider's:
///
///   **Board**    the legs he is allowed to carry, with the stat row above them.
///   **On road**  the one load in his hands, which is where he spends the whole trip.
///   **Earnings** the wallet, and every finished leg as a line of money.
///   **Profile**  his vehicle, his routes, and the goods cover the fragile loads depend on.
///
/// A rider's "Jobs" is a board he dips into between drops; a driver's is a board he consults once and
/// then leaves for eight hours. Same bar, different weight — which is why On road carries the badge
/// and the tab he lands on after accepting.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

enum DriverTab { board, onRoad, earnings, profile }

extension DriverTabChrome on DriverTab {
  String get label => switch (this) {
        DriverTab.board => 'Board',
        DriverTab.onRoad => 'On road',
        DriverTab.earnings => 'Earnings',
        DriverTab.profile => 'Profile',
      };

  IconData get icon => switch (this) {
        DriverTab.board => Icons.inbox_outlined,
        DriverTab.onRoad => Icons.local_shipping_outlined,
        DriverTab.earnings => Icons.account_balance_wallet_outlined,
        DriverTab.profile => Icons.person_outline,
      };
}

class DriverBottomTabs extends StatelessWidget {
  const DriverBottomTabs({
    super.key,
    required this.current,
    required this.onSelect,
    this.badges = const {},
  });

  final DriverTab current;
  final ValueChanged<DriverTab> onSelect;
  final Map<DriverTab, int> badges;

  @override
  Widget build(BuildContext context) => UkoBottomTabs(
        current: DriverTab.values.indexOf(current),
        onSelect: (i) => onSelect(DriverTab.values[i]),
        tabs: [
          for (final tab in DriverTab.values)
            UkoTab(label: tab.label, icon: tab.icon, badge: badges[tab] ?? 0),
        ],
      );
}

class DriverTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DriverTopBar({super.key, required this.title, this.subtitle, this.actions});

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => UkoTopBar(
        title: title,
        subtitle: subtitle,
        actions: actions,
        mark: Icons.local_shipping,
      );
}
