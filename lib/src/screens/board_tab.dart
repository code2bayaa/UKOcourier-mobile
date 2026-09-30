/// The board: the stat row, then every leg UKO has going, with the ones he can take first.
///
/// Two things here are deliberate and easy to get wrong the other way.
///
/// **Legs he cannot take are still shown**, below the ones he can, each with the API's own reason. A
/// board filtered to what he qualifies for would be shorter and would quietly hide the fact that a
/// lapsed insurance certificate is costing him the fragile work — which is the one thing he could
/// actually go and fix.
///
/// **Accepting asks when he plans to leave.** The API takes `depart_at` and tells the origin shelf, so
/// an owner knows whether to expect him this afternoon or on Thursday. It is optional, and the sheet
/// offers "now" as one tap, because a driver standing at the shelf should not have to operate a date
/// picker to say so.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../models.dart';
import 'widgets/departure_sheet.dart';
import 'widgets/leg_card.dart';

class BoardTab extends StatelessWidget {
  const BoardTab({
    super.key,
    required this.data,
    required this.error,
    required this.onRefresh,
    required this.onOpen,
    required this.onAccept,
  });

  final DriverDashboard data;
  final String error;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CourierJob) onOpen;
  final Future<void> Function(CourierJob, DateTime?) onAccept;

  @override
  Widget build(BuildContext context) {
    final canTake = data.offered.where((j) => j.eligible).toList();
    final cannot = data.offered.where((j) => !j.eligible).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          StatCards(stats: [
            (label: 'Trips', value: '${data.trips}', trend: null),
            (label: 'This week', value: ksh(data.earningsWeek), trend: null),
            (label: 'Rating', value: data.rating.toStringAsFixed(1), trend: null),
          ]),
          const SizedBox(height: 14),
          if (error.isNotEmpty) ...[
            UkoNotice(error, tone: UkoTone.danger),
            const SizedBox(height: 14),
          ],
          if (!data.driver.active) ...[
            UkoNotice(
              'Your courier account is ${data.driver.status}. Call the UKO courier desk on 0700 000 222 '
              '— you cannot be offered work until it is active again.',
              tone: UkoTone.danger,
              title: 'Account ${data.driver.status}',
            ),
            const SizedBox(height: 14),
          ] else if (!data.driver.isOnline) ...[
            const UkoNotice(
              'You are offline. Switch on at the top of the screen to be offered legs.',
              tone: UkoTone.warning,
              title: 'Offline',
              icon: Icons.toggle_off_outlined,
            ),
            const SizedBox(height: 14),
          ],
          // Cover that has run out takes every fragile load off his board, and the board is where he
          // will notice it missing — so it is also where it should be explained.
          if (data.driver.coverLapsed) ...[
            UkoNotice(
              'Your goods-in-transit cover expired ${fmtDate(data.driver.insuranceExpires)}. Fragile and '
              'high-value loads need cover that has not lapsed, so those legs will not be offered to you '
              'until the courier desk has your new certificate.',
              tone: UkoTone.warning,
              title: 'Cover has expired',
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: 14),
          ],
          if (data.busy) ...[
            UkoNotice(
              'You have ${data.currentJob} in hand. One load at a time — and that counts a rider job if '
              'you ride for UKO too. Finish it or hand it back and the board opens again.',
              tone: UkoTone.primary,
              title: 'The board is closed for now',
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 14),
          ],
          _heading('Legs you can take', canTake.length),
          if (canTake.isEmpty)
            UkoPanel(
              padded: false,
              child: UkoEmpty(
                icon: Icons.local_shipping_outlined,
                title: data.busy ? 'Nothing while you are loaded' : 'Nothing on your roads yet',
                subtitle: data.busy
                    ? 'The board fills again the moment ${data.currentJob} is signed for.'
                    : 'Legs appear here when a paid parcel needs to cross between counties you run. '
                        'Adding a route in the courier console widens the board.',
              ),
            )
          else
            for (final j in canTake)
              LegCard(
                job: j,
                onOpen: () => onOpen(j),
                onAccept: data.busy ? null : () => _accept(context, j),
              ),
          if (cannot.isNotEmpty) ...[
            const SizedBox(height: 10),
            _heading('Not for you', cannot.length),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'These are running anyway. Each one says what is standing between you and it.',
                style: TextStyle(fontSize: 11.5, color: UkoColors.muted, height: 1.45),
              ),
            ),
            for (final j in cannot) LegCard(job: j, onOpen: () => onOpen(j)),
          ],
        ],
      ),
    );
  }

  Widget _heading(String text, int count) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(text,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800, color: UkoColors.ink)),
            const SizedBox(width: 8),
            UkoChip('$count', tone: UkoTone.neutral),
          ],
        ),
      );

  Future<void> _accept(BuildContext context, CourierJob job) async {
    final when = await showModalBottomSheet<Departure>(
      context: context,
      backgroundColor: UkoColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(UkoRadius.lg)),
      ),
      builder: (sheet) => DepartureSheet(job: job),
    );
    if (when == null) return;   // he backed out — the leg stays on the board
    await onAccept(job, when.at);
  }
}
