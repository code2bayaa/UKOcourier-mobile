/// The driver's wallet: what he has earned, and getting it to M-PESA.
///
/// The same two honesty problems as every UKO partner wallet, and they are where a partner feels
/// cheated if nobody told him:
///
///   * **The 10 % is on the way out, not on the way in.** Every leg pays `driver_earns` into the wallet
///     — the fee less UKO's commission — and that number is already net. Withdrawing then costs
///     `fee_pct` again, which is the *withdrawal* fee. So the screen shows what will actually land on
///     his phone before he taps, not after.
///   * **His money belongs to the courier row, not to a shop account.** A driver never linked to UKO
///     shop is paid and withdraws exactly the same, to `couriers.mpesa_number` — which is the number
///     shown here, and which this withdrawal updates for next time.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../models.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.api, this.embedded = false, this.data});

  final CourierApi api;

  /// True when this is the Earnings tab inside the shell rather than a pushed screen: the shell
  /// already draws the top bar and the tabs, so no Scaffold or AppBar of its own.
  final bool embedded;

  /// The dashboard the shell already has — the week's figures come from there rather than being
  /// re-fetched a beat later and disagreeing with the tab next door.
  final DriverDashboard? data;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Wallet? _wallet;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await widget.api.wallet();
      if (!mounted) return;
      setState(() {
        _wallet = w;
        _error = '';
      });
    } on ApiException catch (e) {
      if (!mounted || e.unauthorised) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _wallet;
    final data = widget.data;
    final body = w == null
        ? Center(
            child: _error.isEmpty
                ? const CircularProgressIndicator()
                : UkoEmpty(icon: Icons.error_outline, title: 'Could not load', subtitle: _error),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                UkoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available', style: TextStyle(fontSize: 12, color: UkoColors.ink2)),
                      const SizedBox(height: 4),
                      Text(
                        ksh(w.balance),
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w800, color: UkoColors.ink),
                      ),
                      const SizedBox(height: 12),
                      AsyncButton(
                        label: 'Withdraw to M-PESA',
                        icon: Icons.smartphone,
                        enabled: w.canWithdraw,
                        onPressed: w.canWithdraw ? () => _withdrawSheet(w) : null,
                      ),
                      if (!w.canWithdraw) ...[
                        const SizedBox(height: 8),
                        Text(
                          'The smallest withdrawal is ${ksh(w.minWithdrawal)}.',
                          style: const TextStyle(fontSize: 11.5, color: UkoColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (data != null) ...[
                  const SizedBox(height: 14),
                  // The week as the API counts it — his share, already net of commission.
                  StatCards(stats: [
                    (label: 'This week', value: ksh(data.earningsWeek), trend: null),
                    (
                      label: 'Distance',
                      value: data.kmWeek > 0 ? km(data.kmWeek) : '—',
                      trend: null
                    ),
                    (
                      label: 'Average leg',
                      value: data.avgHours > 0 ? '${data.avgHours}h' : '—',
                      trend: null
                    ),
                  ]),
                ],
                const SizedBox(height: 14),
                UkoPanel(
                  title: 'Recent',
                  subtitle: 'Every leg and every withdrawal, newest first.',
                  padded: false,
                  child: w.ledger.isEmpty
                      ? const UkoEmpty(
                          icon: Icons.receipt_long_outlined,
                          title: 'Nothing yet',
                          subtitle: 'Leg fees land here the moment a far shelf signs for a load.',
                        )
                      : Column(
                          children: [
                            for (final e in w.ledger)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(e.label,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: UkoColors.ink)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${e.ref}${e.at == null ? '' : ' · ${fmtDate(e.at)}'}',
                                            style: const TextStyle(
                                                fontSize: 11, color: UkoColors.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${e.amount < 0 ? '−' : '+'}${ksh(e.amount.abs())}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            e.amount < 0 ? UkoColors.ink2 : UkoColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Wallet')), body: body);
  }

  Future<void> _withdrawSheet(Wallet w) async {
    final amount = TextEditingController(text: w.balance.round().toString());
    final account = TextEditingController(text: w.mpesaNumber);
    String error = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: UkoColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(UkoRadius.lg)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final asked = double.tryParse(amount.text.trim()) ?? 0;
          final ok = asked >= w.minWithdrawal &&
              asked <= w.balance &&
              account.text.trim().length >= 9;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Withdraw to M-PESA',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: 'KSh '),
                  onChanged: (_) => setSheet(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: account,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'M-PESA number',
                    hintText: '07xx xxx xxx',
                  ),
                  onChanged: (_) => setSheet(() {}),
                ),
                const SizedBox(height: 14),
                // The figure that matters: what actually reaches his phone.
                UkoNotice(
                  asked <= 0
                      ? 'UKO keeps ${w.feePct.round()}% when money leaves for M-PESA. Spending it '
                          'inside UKO costs nothing.'
                      : '${ksh(w.netOf(asked))} reaches your phone — ${ksh(asked)} less UKO\'s '
                          '${w.feePct.round()}% withdrawal fee.',
                  tone: UkoTone.primary,
                  icon: Icons.info_outline,
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  UkoNotice(error, tone: UkoTone.danger),
                ],
                const SizedBox(height: 16),
                AsyncButton(
                  label: asked > 0 ? 'Send ${ksh(w.netOf(asked))}' : 'Withdraw',
                  enabled: ok,
                  onPressed: ok
                      ? () async {
                          try {
                            await widget.api
                                .withdraw(amount: asked, account: account.text.trim());
                            if (!sheetContext.mounted) return;
                            Navigator.pop(sheetContext);
                            await _load();
                            if (mounted) {
                              showUkoMessage(context,
                                  'On its way — M-PESA usually takes a minute or two.');
                            }
                          } on ApiException catch (e) {
                            setSheet(() => error = e.message);
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
    amount.dispose();
    account.dispose();
  }
}
