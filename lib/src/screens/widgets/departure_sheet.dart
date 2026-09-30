/// "When do you plan to leave?" — the sheet that turns an offer into an accepted leg.
///
/// Shared by the board and the leg screen, because a driver who opens an offer to read the manifest
/// before deciding must be able to decide *there*. Sending him back to the board to find the card
/// again is how an offer expires under him.
///
/// The API takes `depart_at` and tells the origin shelf, so an owner knows whether to expect him this
/// afternoon or on Thursday. It is optional, and the sheet offers "now" as one tap, because a driver
/// standing at the shelf should not have to operate a date picker to say so.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../../models.dart';

/// A chosen departure. Wrapped rather than passed as a bare `DateTime?` so that "leaving now" (null)
/// can be told apart from "he closed the sheet" (no result at all).
class Departure {
  const Departure(this.at);
  final DateTime? at;
}

class DepartureSheet extends StatefulWidget {
  const DepartureSheet({super.key, required this.job});

  final CourierJob job;

  @override
  State<DepartureSheet> createState() => _DepartureSheetState();
}

class _DepartureSheetState extends State<DepartureSheet> {
  DateTime? _picked;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Take ${job.waybillNo}?',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            '${job.route} · ${km(job.distanceKm)} · ${job.className.toLowerCase()}',
            style: const TextStyle(fontSize: 12.5, color: UkoColors.ink2),
          ),
          const SizedBox(height: 16),
          UkoKeyValue('You earn', ksh(job.driverEarns), strong: true),
          const Divider(height: 18),
          UkoKeyValue('Collect at', job.origin?.name ?? job.originWard),
          const Divider(height: 18),
          UkoKeyValue('Deliver to', job.destinationShelf?.name ?? job.destinationWard),
          const SizedBox(height: 18),
          const Text(
            'When do you plan to leave? The shelf is told, so the owner knows whether to have the load '
            'ready this afternoon or on Thursday.',
            style: TextStyle(fontSize: 12, color: UkoColors.ink2, height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(_picked == null ? 'Pick a time (optional)' : fmtDate(_picked)),
            onPressed: _pick,
          ),
          const SizedBox(height: 16),
          AsyncButton(
            label: _picked == null ? 'Take it — leaving now' : 'Take it',
            onPressed: () async => Navigator.pop(context, Departure(_picked)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(hours: 1)),
      lastDate: now.add(const Duration(days: 14)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    setState(() => _picked = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }
}
