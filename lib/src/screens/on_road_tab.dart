/// On road: the one load in his hands, and nothing else.
///
/// A rider's equivalent tab lists several drops; a driver's holds exactly one leg, because the API
/// refuses him a second. So this tab is not really a list — it is the trip, with the state of the GPS
/// above it, and it opens straight onto the leg when he taps.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../config.dart';
import '../models.dart';
import 'widgets/leg_card.dart';

class OnRoadTab extends StatelessWidget {
  const OnRoadTab({
    super.key,
    required this.data,
    required this.tracker,
    required this.onRefresh,
    required this.onOpen,
  });

  final DriverDashboard data;
  final LocationTracker tracker;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CourierJob) onOpen;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: tracker,
        builder: (context, _) => RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              if (data.active.isEmpty)
                UkoPanel(
                  padded: false,
                  child: UkoEmpty(
                    icon: Icons.local_shipping_outlined,
                    title: 'Nothing on the van',
                    subtitle: data.busy
                        ? 'You have ${data.currentJob} open in the delivery app. Finish that and this '
                            'tab is yours again.'
                        : 'Take a leg from the board and the whole trip lives here — both codes, the '
                            'shelves, and the chat.',
                  ),
                )
              else ...[
                UkoKeepPhoneOn(
                  tracker: tracker,
                  warnMinutes: data.active.first.tracking?.warnMinutes ?? Config.trackWarnMinutes,
                  missingMinutes:
                      data.active.first.tracking?.missingMinutes ?? Config.trackMissingMinutes,
                  until: 'the far shelf signs for the load',
                ),
                const SizedBox(height: 14),
                for (final j in data.active)
                  LegCard(job: j, live: true, onOpen: () => onOpen(j)),
                const SizedBox(height: 4),
                const Text(
                  'Open the leg for the hand-over codes, the shelf details and the chat.',
                  style: TextStyle(fontSize: 11.5, color: UkoColors.muted, height: 1.45),
                ),
              ],
            ],
          ),
        ),
      );
}
