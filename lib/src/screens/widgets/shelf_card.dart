/// A shelf at one end of a leg: where it is, when it is open, and the two things a driver actually
/// wants when he gets there — directions and a phone number.
///
/// Opening hours are on here for a reason a rider never has: a driver arriving in another county at
/// 8pm to a shelf that shut at six has wasted the whole day, and there is no second shelf to try.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../../models.dart';

class ShelfCard extends StatelessWidget {
  const ShelfCard({
    super.key,
    required this.shelf,
    required this.heading,
    this.done = false,
    this.muted = false,
  });

  final Shelf shelf;
  final String heading;

  /// Already dealt with — the load has left this shelf.
  final bool done;

  /// Not his problem yet: shown, but without the border that says "go here now".
  final bool muted;

  @override
  Widget build(BuildContext context) => UkoPanel(
        borderColor: done || muted ? UkoColors.border : UkoColors.primary300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 17,
                  color: done || muted ? UkoColors.muted : UkoColors.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${heading.toUpperCase()} · SHELF',
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: UkoColors.muted),
                ),
                const Spacer(),
                if (done) const Icon(Icons.check_circle, size: 17, color: UkoColors.success),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              shelf.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: UkoColors.ink),
            ),
            if (shelf.where.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(shelf.where,
                  style: const TextStyle(fontSize: 12.5, color: UkoColors.ink2, height: 1.4)),
            ],
            if (shelf.hours.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: UkoColors.muted),
                  const SizedBox(width: 5),
                  Text('Open ${shelf.hours}',
                      style: const TextStyle(fontSize: 11.5, color: UkoColors.muted)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (shelf.lat != null && shelf.lng != null)
                  Expanded(
                    child: AsyncButton(
                      label: 'Directions',
                      icon: Icons.navigation_outlined,
                      outlined: true,
                      onPressed: () => openDirections(shelf.lat!, shelf.lng!),
                    ),
                  ),
                if (shelf.lat != null && shelf.lng != null && shelf.phone.isNotEmpty)
                  const SizedBox(width: 8),
                if (shelf.phone.isNotEmpty)
                  Expanded(
                    child: AsyncButton(
                      label: 'Call',
                      icon: Icons.call_outlined,
                      outlined: true,
                      onPressed: () => dial(shelf.phone),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}
