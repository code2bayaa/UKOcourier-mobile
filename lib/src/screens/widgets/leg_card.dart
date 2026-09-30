/// One leg on a list — on the board, or in his hands.
///
/// A driver picks between legs on four things and in this order: where it goes, what is in it, what it
/// pays, and when it stops being available. So the route is the headline, the class sits beside the
/// kind as a chip (because "fragile" changes whether he can take it at all), the money is large, and
/// the offer clock is the only thing allowed to be red.
///
/// When the API says he may *not* take a leg it also says why — a road he does not run, a class he is
/// not cleared for, cover that has lapsed, weight past his capacity. That reason is printed where the
/// buttons would be rather than the offer being hidden, because a driver who cannot see the work he is
/// missing cannot fix the reason he is missing it.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../../models.dart';

class LegCard extends StatelessWidget {
  const LegCard({
    super.key,
    required this.job,
    required this.onOpen,
    this.onAccept,
    this.onDecline,
    this.live = false,
  });

  final CourierJob job;
  final VoidCallback onOpen;

  /// Present only on the board, and only on a leg he may actually take.
  final Future<void> Function()? onAccept;

  /// Present only on an accepted leg whose load is still on the shelf.
  final Future<void> Function()? onDecline;

  /// In his hands: the card gets the primary border so it reads as the live one.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final blocked = onAccept == null && job.offered && !job.eligible;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UkoPanel(
        borderColor: live ? UkoColors.primary300 : UkoColors.border,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(UkoRadius.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UkoChip(
                    job.isReturn ? 'Item going home' : 'A buyer\'s order',
                    tone: job.isReturn ? UkoTone.secondary : UkoTone.primary,
                  ),
                  const SizedBox(width: 6),
                  UkoChip(job.className, tone: _classTone(job.parcelClass)),
                  const Spacer(),
                  if (job.offered && job.expiresIn > 0)
                    Text(
                      '${(job.expiresIn / 3600).ceil()}h left',
                      style: const TextStyle(fontSize: 11, color: UkoColors.warning),
                    )
                  else if (!job.offered)
                    StatusPill(job.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                job.route,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: UkoColors.ink),
              ),
              const SizedBox(height: 3),
              Text(
                [
                  job.waybillNo,
                  if (job.origin != null) 'from ${job.origin!.name}',
                  if (job.distanceKm > 0) km(job.distanceKm),
                  if (job.weightKg > 0) '${job.weightKg.toStringAsFixed(job.weightKg % 1 == 0 ? 0 : 1)} kg',
                ].join(' · '),
                style: const TextStyle(fontSize: 11.5, color: UkoColors.ink2, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ksh(job.driverEarns),
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800, color: UkoColors.primary),
                      ),
                      Text(
                        'you earn · ${ksh(job.fee)} leg fee, UKO keeps 10%',
                        style: const TextStyle(fontSize: 10.5, color: UkoColors.muted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (onAccept == null && onDecline == null)
                    const Icon(Icons.chevron_right, color: UkoColors.borderStrong),
                ],
              ),
              // Why he cannot have it. The API's sentence, unchanged — it already names the gate.
              if (blocked && job.reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                UkoNotice(job.reason, tone: UkoTone.neutral, icon: Icons.block),
              ],
              if (onAccept != null || onDecline != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onDecline != null) ...[
                      Expanded(
                        child: AsyncButton(
                          label: job.offered ? 'Not for me' : 'Give it back',
                          outlined: true,
                          onPressed: onDecline,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (onAccept != null)
                      Expanded(child: AsyncButton(label: 'Take it', onPressed: onAccept)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  UkoTone _classTone(String parcelClass) => switch (parcelClass) {
        'fragile' => UkoTone.danger,
        'bulky' => UkoTone.warning,
        _ => UkoTone.neutral,
      };
}
