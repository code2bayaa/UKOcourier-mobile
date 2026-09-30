/// The driver's home: a top bar, a body, and the four bottom tabs.
///
/// One dashboard call feeds every tab. The API returns the driver, his stats, the leg in his hands, the
/// board and his completed work in a single response, so fetching it once here and handing slices to
/// the tabs means switching tabs costs nothing and never shows one tab fresher than another.
///
/// The shell lands on **On road** rather than the board when he already has a load, because that is
/// the only screen that matters while something of somebody else's is on his van — and because the
/// board is empty anyway: the API offers a busy driver nothing.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../models.dart';
import 'board_tab.dart';
import 'leg.dart';
import 'on_road_tab.dart';
import 'profile_tab.dart';
import 'wallet.dart';
import 'widgets/chrome.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({
    super.key,
    required this.auth,
    required this.api,
    required this.tracker,
  });

  final AuthController auth;
  final CourierApi api;
  final LocationTracker tracker;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  DriverTab _tab = DriverTab.board;
  DriverDashboard? _data;
  int _unread = 0;
  String _error = '';
  Timer? _poll;
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _load();
    // The board moves without him touching it: a leg is taken by another driver, an offer lapses, a
    // shelf replies on a thread. Thirty seconds feels live without eating a data bundle.
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
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = '';
        // Once, on the first load of the session: a driver who opens the app mid-trip wants the trip.
        if (!_landed) {
          _landed = true;
          if (data.active.isNotEmpty) _tab = DriverTab.onRoad;
        }
      });
      _syncTracker(data);
      await _loadUnread();
    } on ApiException catch (e) {
      // A 401 is already handled by the client: it drops the session and the gate above this screen
      // swaps it for sign-in. Nothing to show for that one.
      if (!mounted || e.unauthorised) return;
      if (!quiet || _data == null) setState(() => _error = e.message);
    }
  }

  /// The tracker follows the leg, not the screen. A driver spends a six-hour trip with his phone in his
  /// pocket and the app in the background, so starting the GPS here — where the dashboard is known —
  /// rather than on the leg screen is what makes that work.
  void _syncTracker(DriverDashboard data) {
    final live = data.active.where((j) => j.mine).firstOrNull;
    if (live != null) {
      widget.tracker.start('/courier/jobs/${live.id}/location');
    } else {
      widget.tracker.stop();
    }
  }

  Future<void> _loadUnread() async {
    try {
      final n = await widget.api.unread();
      if (mounted) setState(() => _unread = n);
    } on ApiException {
      // A badge is not worth an error message.
    }
  }

  Future<void> _toggleOnline() async {
    try {
      await widget.api.toggleOnline();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showUkoMessage(context, e.message, error: true);
    }
  }

  Future<void> _openLeg(CourierJob job) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegScreen(api: widget.api, tracker: widget.tracker, jobId: job.id),
    ));
    await _load();
  }

  Future<void> _accept(CourierJob job, DateTime? departAt) async {
    try {
      await widget.api.acceptJob(job.id, departAt: departAt);
      await _load();
      if (!mounted) return;
      setState(() => _tab = DriverTab.onRoad);
      showUkoMessage(context, 'Yours · ${job.waybillNo} · collect at ${job.origin?.name ?? 'the shelf'}');
    } on ApiException catch (e) {
      if (mounted) showUkoMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: DriverTopBar(
        title: data?.driver.name ?? widget.auth.partnerName,
        subtitle: data == null ? null : _subtitle(data.driver),
        actions: [
          if (data != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Switch(
                value: data.driver.isOnline,
                onChanged: data.driver.active ? (_) => _toggleOnline() : null,
              ),
            ),
        ],
      ),
      body: data == null ? _firstLoad() : _body(data),
      bottomNavigationBar: DriverBottomTabs(
        current: _tab,
        onSelect: (t) => setState(() => _tab = t),
        badges: {
          DriverTab.board: data?.offerCount ?? 0,
          DriverTab.onRoad: (data?.liveCount ?? 0) + _unread,
        },
      ),
    );
  }

  /// The roads he runs, which is the one fact that decides what the board can ever show him.
  String _subtitle(Driver d) {
    if (!d.isOnline) return 'Offline';
    final where = d.counties.isEmpty ? 'anywhere' : d.counties.join(', ');
    return 'Online · $where';
  }

  Widget _body(DriverDashboard data) => switch (_tab) {
        DriverTab.board => BoardTab(
            data: data,
            error: _error,
            onRefresh: _load,
            onOpen: _openLeg,
            onAccept: _accept,
          ),
        DriverTab.onRoad => OnRoadTab(
            data: data,
            tracker: widget.tracker,
            onRefresh: _load,
            onOpen: _openLeg,
          ),
        DriverTab.earnings => WalletScreen(api: widget.api, embedded: true, data: data),
        DriverTab.profile => ProfileTab(
            data: data,
            auth: widget.auth,
            tracker: widget.tracker,
          ),
      };

  Widget _firstLoad() {
    if (_error.isEmpty) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: UkoEmpty(
          icon: Icons.wifi_off,
          title: 'Could not load the board',
          subtitle: _error,
          action: AsyncButton(label: 'Try again', onPressed: _load),
        ),
      ),
    );
  }
}
