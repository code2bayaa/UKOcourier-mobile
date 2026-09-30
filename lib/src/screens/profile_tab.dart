/// The Profile tab: his vehicle, the roads he runs, and the cover the fragile work depends on.
///
/// Read-only, deliberately. The console lets a driver edit his routes, classes and working hours, and
/// `PUT /api/courier/profile` accepts them; but a half-built editor that silently drops a field is
/// worse than a clear list plus the console, so this shows what UKO has and says where to change it.
///
/// The one thing it does more than list: it explains the three gates. Counties, classes and cover are
/// what decide whether the board has anything on it, and a driver staring at an empty board deserves
/// to be told which of the three is the reason rather than left to guess.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../config.dart';
import '../models.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.data,
    required this.auth,
    required this.tracker,
  });

  final DriverDashboard data;
  final AuthController auth;
  final LocationTracker tracker;

  @override
  Widget build(BuildContext context) {
    final d = data.driver;
    final session = auth.session;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        UkoPanel(
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: UkoColors.primary050,
                  borderRadius: BorderRadius.circular(UkoRadius.md),
                ),
                child: const Icon(Icons.local_shipping, color: UkoColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                    const SizedBox(height: 2),
                    Text(
                      d.companyEmail.isEmpty ? d.phone : d.companyEmail,
                      style: const TextStyle(fontSize: 12, color: UkoColors.ink2),
                    ),
                  ],
                ),
              ),
              UkoChip(d.status, tone: d.active ? UkoTone.success : UkoTone.danger),
            ],
          ),
        ),
        const SizedBox(height: 14),
        UkoPanel(
          title: 'Your vehicle',
          subtitle: Config.courierWebLabel.isEmpty
              ? 'Change these in the UKO courier console.'
              : 'Change these in the courier console at ${Config.courierWebLabel}.',
          child: Column(
            children: [
              UkoKeyValue('Phone', d.phone.isEmpty ? '—' : d.phone),
              const Divider(height: 16),
              UkoKeyValue('Vehicle', vehicleName(d.vehicleType)),
              const Divider(height: 16),
              UkoKeyValue('Number plate', d.numberPlate.isEmpty ? '—' : d.numberPlate),
              const Divider(height: 16),
              UkoKeyValue('Carries up to',
                  d.capacityKg > 0 ? '${d.capacityKg.toStringAsFixed(0)} kg' : '—'),
              const Divider(height: 16),
              UkoKeyValue('Trips', '${d.trips}'),
              const Divider(height: 16),
              UkoKeyValue('Rating', d.rating.toStringAsFixed(1), strong: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Gate one and two: where he runs, and what he is cleared to carry.
        UkoPanel(
          title: 'What you can be offered',
          subtitle: 'A leg has to start and end on roads you run, and be a class you are cleared for.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('Counties you run'),
              const SizedBox(height: 6),
              if (d.counties.isEmpty)
                const Text('Anywhere in Kenya',
                    style: TextStyle(fontSize: 13, color: UkoColors.ink))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in d.counties) UkoChip(c, tone: UkoTone.primary)],
                ),
              const Divider(height: 22),
              const _Label('Load classes'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in (d.classes.isEmpty ? const ['standard'] : d.classes))
                    UkoChip(_className(c), tone: UkoTone.neutral),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Gate three, and the only one that expires on its own while he sleeps.
        UkoPanel(
          title: 'Goods-in-transit cover',
          subtitle: 'UKO does not insure a load. Fragile and high-value legs need your own cover, and '
              'it has to be in date on the day you take one.',
          child: Column(
            children: [
              UkoKeyValue('Insurer', d.insurer.isEmpty ? 'Not declared' : d.insurer),
              const Divider(height: 16),
              UkoKeyValue(
                'Expires',
                d.insuranceExpires == null ? '—' : fmtDate(d.insuranceExpires),
                strong: d.coverLapsed,
              ),
              const SizedBox(height: 12),
              if (d.coverLapsed)
                UkoNotice(
                  'Your cover ran out on ${fmtDate(d.insuranceExpires)}. Fragile legs are not being '
                  'offered to you until the courier desk has a current certificate.',
                  tone: UkoTone.danger,
                  icon: Icons.shield_outlined,
                )
              else if (!d.insured)
                const UkoNotice(
                  'No cover on file, so the board will only ever show you standard and bulky loads. '
                  'Send a certificate to the courier desk to open up the fragile work.',
                  tone: UkoTone.warning,
                  icon: Icons.shield_outlined,
                )
              else
                const UkoNotice(
                  'In date — fragile and high-value legs are open to you.',
                  tone: UkoTone.success,
                  icon: Icons.verified_user_outlined,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!d.linked) ...[
          const UkoNotice(
            'Your wallet is paid exactly the same whether or not UKO staff have linked this account to '
            'a UKO shop account. Linking only adds one thing: spending the balance on UKO services in '
            'the shop instead of withdrawing it.',
            tone: UkoTone.primary,
            title: 'Not linked to a shop account',
            icon: Icons.link_off,
          ),
          const SizedBox(height: 14),
        ],
        UkoPanel(
          title: 'This session',
          // The two-hour expiry is absolute, not idle-based, so it is worth showing: a driver who knows
          // he has 20 minutes left will sign in again before he is standing at a shelf with a load.
          subtitle: session == null
              ? null
              : 'Sessions last two hours from sign-in, however busy you are.',
          child: Column(
            children: [
              if (session != null)
                UkoKeyValue(
                  'Signed out in',
                  session.remaining.inMinutes < 1
                      ? 'less than a minute'
                      : '${session.remaining.inHours}h ${session.remaining.inMinutes % 60}m',
                  strong: session.aboutToExpire,
                ),
              const SizedBox(height: 12),
              AsyncButton(
                label: 'Sign out',
                icon: Icons.logout,
                outlined: true,
                onPressed: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _className(String c) => switch (c) {
        'fragile' => 'Fragile / high value',
        'bulky' => 'Bulky',
        _ => 'Standard',
      };

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Any leg you have accepted stays yours, and UKO keeps tracking the load. You will need your '
          'password and a new e-mailed code to sign back in.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (yes != true) return;
    await tracker.stop();
    await auth.signOut();
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: UkoColors.muted),
      );
}
