/// One leg, from the board to the far shelf's signature.
///
/// The screen shows exactly one action at a time, because at any moment there is exactly one thing a
/// driver can do — and a screen offering him three buttons on a highway is a screen that gets the wrong
/// one pressed:
///
///   **offered**     take it (with when he plans to leave), or leave it
///   **accepted**    the origin shelf owner reads out *his* pickup code; the driver types it in.
///                   This is also the only state he can hand the leg back from.
///   **collected**   the load is on the van and has not moved. One button: set off.
///   **in_transit**  the far shelf owner reads out *his* delivery code; the driver types it in.
///   **delivered**   what he was paid, and how long the road took.
///
/// Neither code is ever his to give, and neither is ever shown. That is the whole security model of a
/// UKO hand-over: the man letting the load go reads his code out loud, and the man taking it types it
/// in. A driver who could see the pickup code could collect a load nobody agreed to give him.
///
/// **Departing is a deliberate tap, not a guess.** `departed_at` starts the clock that becomes
/// `travel_minutes`, which is what UKO's route times are built from — so it is the driver who says he
/// has left, rather than the app inferring it from the first GPS fix that moves.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../models.dart';
import 'chat.dart';
import 'widgets/departure_sheet.dart';
import 'widgets/shelf_card.dart';

class LegScreen extends StatefulWidget {
  const LegScreen({
    super.key,
    required this.api,
    required this.tracker,
    required this.jobId,
  });

  final CourierApi api;
  final LocationTracker tracker;
  final int jobId;

  @override
  State<LegScreen> createState() => _LegScreenState();
}

class _LegScreenState extends State<LegScreen> {
  CourierJob? _job;
  String _error = '';
  String _code = '';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // A shelf owner can reply on a thread, and the courier desk can move a leg from under him. Thirty
    // seconds keeps the screen honest without being the reason his battery died.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final data = await widget.api.dashboard();
      final all = [...data.active, ...data.offered, ...data.completed];
      final job = all.where((j) => j.id == widget.jobId).firstOrNull;
      if (!mounted) return;
      setState(() {
        _job = job ?? _job;
        _error = '';
      });
    } on ApiException catch (e) {
      if (!mounted || e.unauthorised) return;
      if (!quiet || _job == null) setState(() => _error = e.message);
    }
  }

  Future<void> _run(Future<void> Function() call, String done) async {
    try {
      await call();
      setState(() => _code = '');
      await _load();
      if (mounted) showUkoMessage(context, done);
    } on ApiException catch (e) {
      if (mounted) showUkoMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return Scaffold(
      appBar: AppBar(
        title: Text(job?.waybillNo ?? 'Leg'),
        actions: [
          if (job != null && job.mine)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Messages',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(api: widget.api, job: job),
              )),
            ),
        ],
      ),
      body: job == null
          ? Center(
              child: _error.isEmpty
                  ? const CircularProgressIndicator()
                  : UkoEmpty(icon: Icons.error_outline, title: 'Could not load', subtitle: _error),
            )
          : AnimatedBuilder(
              animation: widget.tracker,
              builder: (context, _) => RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    _header(job),
                    const SizedBox(height: 16),
                    if (job.mine) ...[
                      UkoKeepPhoneOn(
                        tracker: widget.tracker,
                        warnMinutes: job.tracking?.warnMinutes ?? 20,
                        missingMinutes: job.tracking?.missingMinutes ?? 60,
                        until: 'the far shelf signs for the load',
                      ),
                      const SizedBox(height: 14),
                    ],
                    ..._action(job),
                    ..._shelves(job),
                    if (job.items.isNotEmpty) ...[
                      UkoPanel(
                        title: 'What you are carrying',
                        subtitle: _loadLine(job),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final item in job.items)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Text(item.line,
                                    style: const TextStyle(fontSize: 13, color: UkoColors.ink)),
                              ),
                            if (job.classNote.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                job.classNote,
                                style: const TextStyle(
                                    fontSize: 11.5, color: UkoColors.muted, height: 1.45),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (job.events.isNotEmpty) ...[
                      UkoPanel(
                        title: 'What has happened',
                        child: JobTimeline(
                          events: [
                            for (final e in job.events) (title: e.title, sub: e.sub, at: e.at),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    UkoTrackingLinkCard(
                      url: job.tracking?.url ?? '',
                      reference: job.waybillNo,
                      watchers: job.isReturn
                          ? 'the shelves and the seller waiting for'
                          : 'the shelves and the buyer waiting for',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _loadLine(CourierJob job) {
    final bits = [
      if (job.weightKg > 0) '${job.weightKg.toStringAsFixed(job.weightKg % 1 == 0 ? 0 : 1)} kg',
      job.className.toLowerCase(),
      if (job.reference.isNotEmpty) job.reference,
    ];
    return bits.join(' · ');
  }

  Widget _header(CourierJob job) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UkoChip(job.carrying.isEmpty ? 'A buyer\'s order' : job.carrying,
                  tone: job.isReturn ? UkoTone.secondary : UkoTone.primary),
              const SizedBox(width: 6),
              StatusPill(job.status),
              const Spacer(),
              Text(ksh(job.driverEarns),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: UkoColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(job.route,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: UkoColors.ink)),
          const SizedBox(height: 3),
          Text(
            [
              job.waybillNo,
              if (job.reference.isNotEmpty) job.reference,
              if (job.distanceKm > 0) km(job.distanceKm),
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: UkoColors.ink2),
          ),
        ],
      );

  // ---------------------------------------------------------------- the one thing he can do now
  List<Widget> _action(CourierJob job) {
    if (job.offered) return [_answerOffer(job), const SizedBox(height: 14)];
    if (job.waitingToCollect) return [_collect(job), const SizedBox(height: 14)];
    if (job.loaded) return [_depart(job), const SizedBox(height: 14)];
    if (job.onTheRoad) return [_arrive(job), const SizedBox(height: 14)];
    if (job.finished) return [_finished(job), const SizedBox(height: 14)];
    return const [];
  }

  /// A driver who opens an offer to read the manifest before deciding must be able to decide *here*.
  /// Sending him back to the board to find the card again is how an offer expires under him.
  ///
  /// When he may not take it, the API's own reason stands in place of the button — the same sentence
  /// the board prints, so the two screens never disagree about why.
  Widget _answerOffer(CourierJob job) {
    if (!job.eligible) {
      return UkoNotice(
        job.reason.isEmpty
            ? 'This leg is not open to you. The board says why.'
            : job.reason,
        tone: UkoTone.neutral,
        title: 'Not one you can take',
        icon: Icons.block,
      );
    }
    return UkoPanel(
      title: 'Take this one?',
      subtitle: 'You carry one load at a time. Accepting closes the board until the far shelf signs '
          'for it.',
      child: AsyncButton(
        label: 'Take it',
        onPressed: () async {
          final when = await showModalBottomSheet<Departure>(
            context: context,
            backgroundColor: UkoColors.bg,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(UkoRadius.lg)),
            ),
            builder: (_) => DepartureSheet(job: job),
          );
          if (when == null || !mounted) return;   // he backed out — it stays on the board
          await _run(
            () => widget.api.acceptJob(job.id, departAt: when.at),
            'Yours · collect at ${job.origin?.name ?? 'the shelf'}',
          );
        },
      ),
    );
  }

  Widget _collect(CourierJob job) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UkoPanel(
            title: 'Collect at ${job.origin?.name ?? 'the origin shelf'}',
            subtitle: 'The shelf owner reads out his 4-digit pickup code. Type it in once the load is '
                'actually on the van — it is his proof that he handed it to you.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (job.departAt != null) ...[
                  UkoKeyValue('You said you would leave', fmtDate(job.departAt)),
                  const Divider(height: 18),
                ],
                Center(child: CodeInput(onChanged: (v) => setState(() => _code = v))),
                const SizedBox(height: 16),
                AsyncButton(
                  label: 'The load is on the van',
                  icon: Icons.inventory_2_outlined,
                  enabled: _code.length == 4,
                  onPressed: _code.length == 4
                      ? () => _run(() => widget.api.collect(job.id, _code),
                          'Collected · ${job.waybillNo}')
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // The last moment this is a button rather than a phone call, so it says so.
          UkoPanel(
            title: 'Changed your mind?',
            subtitle: 'You can still put this leg back on the board — but only until the load is on '
                'the van. After that it is a call to the courier desk on 0700 000 222.',
            child: AsyncButton(
              label: 'Give it back',
              outlined: true,
              onPressed: () => _run(() async {
                await widget.api.declineJob(job.id);
                if (mounted) Navigator.pop(context);
              }, 'Back on the board for another driver'),
            ),
          ),
        ],
      );

  Widget _depart(CourierJob job) => UkoPanel(
        title: 'Ready to leave?',
        subtitle: 'The load is on the van. Tapping this starts the clock UKO measures the road by, and '
            'tells the far shelf you are coming.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UkoKeyValue('Heading for',
                job.destinationShelf?.name ?? '${job.destinationWard}, ${job.destinationCounty}'),
            const Divider(height: 18),
            UkoKeyValue('Distance', km(job.distanceKm)),
            const SizedBox(height: 16),
            AsyncButton(
              label: 'On the road',
              icon: Icons.navigation_outlined,
              tone: UkoTone.secondary,
              onPressed: () =>
                  _run(() => widget.api.depart(job.id), 'Safe trip · UKO is following the van'),
            ),
          ],
        ),
      );

  Widget _arrive(CourierJob job) => UkoPanel(
        title: 'Hand over at ${job.destinationShelf?.name ?? 'the far shelf'}',
        // No Markdown here: this is a plain Text, so asterisks would be read out as asterisks.
        subtitle: 'The receiving shelf owner reads out his own delivery code — a different code from '
            'the one you collected against. Type it in when the load is off the van.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (job.onRoadFor != null) ...[
              UkoKeyValue('On the road', countdown(job.onRoadFor!)),
              const Divider(height: 18),
            ],
            Center(child: CodeInput(onChanged: (v) => setState(() => _code = v))),
            const SizedBox(height: 16),
            AsyncButton(
              label: 'Confirm hand-over',
              icon: Icons.check_circle_outline,
              tone: UkoTone.secondary,
              enabled: _code.length == 4,
              onPressed: _code.length == 4
                  ? () => _run(() => widget.api.arrive(job.id, _code),
                      'Delivered · ${ksh(job.driverEarns)} added to your wallet')
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              'This finishes your half of the job and pays you ${ksh(job.driverEarns)}. '
              '${job.isReturn ? 'The seller\'s item is then either back on this shelf or waiting for a rider to bring it the last mile.' : 'The buyer collects here with his own shelve code, or books a rider for the last mile.'}',
              style: const TextStyle(fontSize: 11.5, color: UkoColors.muted, height: 1.45),
            ),
          ],
        ),
      );

  Widget _finished(CourierJob job) => UkoNotice(
        'Handed over${job.travelMinutes > 0 ? ' after ${job.travelMinutes ~/ 60}h ${job.travelMinutes % 60}m on the road' : ''}. '
        '${ksh(job.driverEarns)} is in your wallet.',
        tone: UkoTone.success,
        title: 'Finished',
      );

  // ---------------------------------------------------------------- the two ends
  List<Widget> _shelves(CourierJob job) {
    if (job.finished) return const [];
    final collected = !job.waitingToCollect && !job.offered;
    return [
      if (job.origin != null) ...[
        ShelfCard(
          shelf: job.origin!,
          heading: 'Collect from',
          done: collected,
        ),
        const SizedBox(height: 10),
      ],
      if (job.destinationShelf != null) ...[
        ShelfCard(
          shelf: job.destinationShelf!,
          heading: 'Deliver to',
          // Directions to the far shelf are only useful once he is actually going there.
          muted: !collected,
        ),
        const SizedBox(height: 14),
      ],
    ];
  }
}
