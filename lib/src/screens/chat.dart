/// The two threads on a leg (PRD 19): the shelf, and UKO.
///
/// They are kept apart deliberately rather than merged into one inbox. "I am two hours out, have the
/// load ready" belongs to a shelf owner; "the load is short one box" belongs to UKO and wants a record.
/// A driver who has to pick the audience before he types is a driver who has thought for one second
/// about who is going to read it.
///
/// Which shelf "the shelf" means moves with the load — the origin before it is collected, the
/// destination after — and the server decides that, not the app. So the heading says *a* shelf rather
/// than naming one and risking being a step behind the truth.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.api, required this.job});

  final CourierApi api;
  final CourierJob job;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _draft = TextEditingController();

  List<JobMessage> _shelve = const [];
  List<JobMessage> _admin = const [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _draft.dispose();
    super.dispose();
  }

  /// Opening a thread is what marks its messages read, server-side — so this call is also what clears
  /// the badge the driver just tapped.
  Future<void> _load() async {
    try {
      final both = await widget.api.messages(widget.job.id);
      if (!mounted) return;
      setState(() {
        _shelve = both.shelve;
        _admin = both.admin;
        _loading = false;
        _error = '';
      });
    } on ApiException catch (e) {
      if (!mounted || e.unauthorised) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  String get _audience => _tabs.index == 0 ? 'shelve' : 'admin';

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (text.isEmpty) return;
    try {
      await widget.api.send(widget.job.id, audience: _audience, body: text);
      _draft.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showUkoMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.job.waybillNo),
          bottom: TabBar(
            controller: _tabs,
            labelColor: UkoColors.primary,
            unselectedLabelColor: UkoColors.muted,
            indicatorColor: UkoColors.secondary,
            tabs: const [
              Tab(text: 'The shelf'),
              Tab(text: 'UKO'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _thread(
                          _shelve,
                          empty: 'Nothing yet. Tell the shelf when you are arriving, or ask for the '
                              'load to be ready — whichever end the load is at right now is who reads '
                              'this.',
                        ),
                        _thread(
                          _admin,
                          empty: 'Nothing yet. Use this for anything UKO should have a record of — a '
                              'load that is short, a shelf that is shut, a breakdown.',
                        ),
                      ],
                    ),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: UkoNotice(_error, tone: UkoTone.danger),
              ),
            _composer(),
          ],
        ),
      );

  Widget _thread(List<JobMessage> messages, {required String empty}) {
    if (messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: UkoEmpty(
          icon: Icons.chat_bubble_outline,
          title: 'No messages',
          subtitle: empty,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: messages.length,
        itemBuilder: (context, i) => _bubble(messages[i]),
      ),
    );
  }

  Widget _bubble(JobMessage m) => Align(
        alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          decoration: BoxDecoration(
            color: m.mine ? UkoColors.primary050 : UkoColors.surface,
            borderRadius: BorderRadius.circular(UkoRadius.md),
            border: Border.all(color: m.mine ? UkoColors.primary300 : UkoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!m.mine && m.senderName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    m.senderName,
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700, color: UkoColors.ink2),
                  ),
                ),
              Text(m.body,
                  style: const TextStyle(fontSize: 13, color: UkoColors.ink, height: 1.4)),
              if (m.at != null) ...[
                const SizedBox(height: 3),
                Text(fmtDate(m.at),
                    style: const TextStyle(fontSize: 10, color: UkoColors.muted)),
              ],
            ],
          ),
        ),
      );

  Widget _composer() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: UkoColors.bg,
            border: Border(top: BorderSide(color: UkoColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _draft,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _tabs.index == 0 ? 'Message the shelf' : 'Message UKO',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _draft.text.trim().isEmpty ? null : _send,
                icon: const Icon(Icons.send, size: 18),
                style: IconButton.styleFrom(backgroundColor: UkoColors.primary),
              ),
            ],
          ),
        ),
      );
}
