/// What the courier app is checked on without a server.
///
/// The same principle as the rider app's suite: test the pure logic that would be embarrassing to get
/// wrong, and leave everything the API decides to the API's own suite
/// (`courier/back-end/tests/`) rather than to a mock here — a mock of a server that decides
/// everything would only be testing the mock.
///
/// What that leaves is narrow but load-bearing: which panel a leg screen shows, whether a driver's
/// cover is in date, and the two different ten per cents on his money.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uko_core/uko_core.dart';

import 'package:uko_courier/src/models.dart';

void main() {
  group('where a leg is', () {
    CourierJob at(String status) => CourierJob.fromJson({'id': 1, 'status': status});

    // Each state answers exactly one panel on the leg screen, and the screen shows every panel whose
    // predicate is true. Two states matching at once would stack a code box on a code box — which,
    // since the two codes belong to different people and open different doors, is the one bug on this
    // screen that could actually lose a load.
    test('offered is nobody\'s and shows no code box', () {
      expect(at('offered').offered, isTrue);
      expect(at('offered').mine, isFalse);
      expect(at('offered').waitingToCollect, isFalse);
      expect(at('offered').onTheRoad, isFalse);
    });

    test('accepted is waiting at the origin shelf, and is his', () {
      expect(at('accepted').waitingToCollect, isTrue);
      expect(at('accepted').mine, isTrue);
      expect(at('accepted').loaded, isFalse);
      expect(at('accepted').onTheRoad, isFalse);
    });

    test('collected is on the van but not moving', () {
      expect(at('collected').loaded, isTrue);
      expect(at('collected').mine, isTrue);
      expect(at('collected').waitingToCollect, isFalse);
      expect(at('collected').onTheRoad, isFalse);
    });

    test('in_transit is the road, and nothing else', () {
      expect(at('in_transit').onTheRoad, isTrue);
      expect(at('in_transit').mine, isTrue);
      expect(at('in_transit').loaded, isFalse);
      expect(at('in_transit').waitingToCollect, isFalse);
    });

    test('delivered is finished and no longer his to act on', () {
      expect(at('delivered').finished, isTrue);
      expect(at('delivered').mine, isFalse);
      expect(at('delivered').onTheRoad, isFalse);
    });

    test('exactly one state matches at a time', () {
      for (final s in ['offered', 'accepted', 'collected', 'in_transit', 'delivered']) {
        final j = at(s);
        final matched = [j.offered, j.waitingToCollect, j.loaded, j.onTheRoad, j.finished]
            .where((m) => m)
            .length;
        expect(matched, 1, reason: '$s matched $matched states');
      }
    });
  });

  group('what a leg is carrying', () {
    test('a return leg is labelled by its return number, an order by its order number', () {
      final home = CourierJob.fromJson(
          {'id': 1, 'kind': 'return', 'return_no': 'RT-306216', 'order_no': ''});
      final order = CourierJob.fromJson(
          {'id': 2, 'kind': 'order', 'order_no': 'UKO-48090', 'return_no': ''});
      expect(home.isReturn, isTrue);
      expect(home.reference, 'RT-306216');
      expect(order.isReturn, isFalse);
      expect(order.reference, 'UKO-48090');
    });

    test('an item line reads as a quantity and a name', () {
      expect(
        JobItem.fromJson({'title': 'Ankara maxi dress', 'quantity': 2, 'variant_label': 'M'}).line,
        '2 × Ankara maxi dress · M',
      );
      expect(JobItem.fromJson({'title': 'Pilot watch', 'quantity': 1}).line, '1 × Pilot watch');
    });
  });

  group('goods-in-transit cover', () {
    Driver withCover({required bool insured, DateTime? expires}) => Driver.fromJson({
          'id': 1,
          'insured': insured,
          'insurance_expires': expires?.toIso8601String(),
        });

    // The API makes this exact check before it lets him take a fragile load (`can_carry`). If the app
    // disagreed, a driver would be shown legs the server then refuses — which reads as a bug in UKO
    // rather than as a lapsed certificate.
    test('no cover declared cannot carry fragile', () {
      expect(withCover(insured: false).canCarryFragile, isFalse);
      expect(withCover(insured: false).coverLapsed, isFalse); // nothing to lapse
    });

    test('cover with a date in the past has lapsed', () {
      final d = withCover(
          insured: true, expires: DateTime.now().subtract(const Duration(days: 1)));
      expect(d.coverLapsed, isTrue);
      expect(d.canCarryFragile, isFalse);
    });

    test('cover in date carries fragile', () {
      final d =
          withCover(insured: true, expires: DateTime.now().add(const Duration(days: 30)));
      expect(d.coverLapsed, isFalse);
      expect(d.canCarryFragile, isTrue);
    });

    test('cover with no expiry on file is taken at its word', () {
      expect(withCover(insured: true).canCarryFragile, isTrue);
    });
  });

  group('the board', () {
    DriverDashboard boardOf(List<Map<String, dynamic>> offers) => DriverDashboard.fromJson({
          'courier': {'id': 1, 'name': 'Test'},
          'stats': {},
          'active': [],
          'offered': offers,
          'completed': [],
        });

    // Badging him with work he is not cleared for would be a notification that resolves to "no".
    test('the badge counts only legs he could actually take', () {
      final board = boardOf([
        {'id': 1, 'eligible': true},
        {'id': 2, 'eligible': false, 'reason': 'You do not run Nairobi → Kisumu'},
        {'id': 3, 'eligible': true},
      ]);
      expect(board.offered.length, 3);
      expect(board.offerCount, 2);
    });

    test('an offer missing the eligible flag is assumed takeable, not hidden', () {
      // `job_dict` alone (a leg he already owns) carries no `eligible`; only the board adds it.
      expect(boardOf([
        {'id': 1}
      ]).offerCount, 1);
    });
  });

  group('the two different ten per cents', () {
    // A leg pays `driver_earns`, already net of UKO's commission. Withdrawing costs the fee *again*,
    // on the way out. A partner should never discover the second one at payout.
    test('what reaches his phone is the amount less the withdrawal fee', () {
      final w = Wallet.fromJson({'balance': 2000, 'fee_pct': 10, 'min_withdrawal': 100});
      expect(w.netOf(1000), 900);
      expect(w.canWithdraw, isTrue);
    });

    test('a balance under the minimum cannot be withdrawn', () {
      expect(Wallet.fromJson({'balance': 50, 'min_withdrawal': 100}).canWithdraw, isFalse);
    });

    test('the leg fee and his share are different numbers and both are shown', () {
      final j = CourierJob.fromJson({'id': 1, 'fee': 4200, 'driver_earns': 3780});
      expect(j.fee, 4200);
      expect(j.driverEarns, 3780);
    });
  });

  group('a shelf a driver has never been to', () {
    test('the landmark comes last, where it is read last', () {
      final s = Shelf.fromJson({
        'id': 1,
        'name': 'Mombasa Shelf 02',
        'address': 'Nyerere Avenue',
        'ward': 'Tudor',
        'landmark': 'the blue mosque',
      });
      expect(s.where, 'Nyerere Avenue · Tudor · near the blue mosque');
    });

    test('hours are only shown when both ends are known', () {
      expect(
        Shelf.fromJson({'id': 1, 'opening_time': '08:00', 'closing_time': '18:00'}).hours,
        '08:00 – 18:00',
      );
      expect(Shelf.fromJson({'id': 1, 'opening_time': '08:00'}).hours, isEmpty);
    });
  });

  group('money, as the driver is shown it', () {
    test('matches the web console\'s thousand separators', () {
      expect(ksh(4200), 'KSh 4,200');
      expect(ksh(0), 'KSh 0');
    });

    test('nothing is an em dash, not zero — they are different answers', () {
      expect(km(null), '—');
    });
  });

  group('times from the server', () {
    // Every UKO API writes `datetime.utcnow().isoformat()` — no Z, no offset. Read as local time on a
    // Kenyan handset that is three hours adrift: a leg that departed ten seconds ago read "180:08 on
    // the road". The parse forces a bare timestamp to UTC.
    test('a bare timestamp is read as UTC, not as local time', () {
      final now = DateTime.now().toUtc();
      final bare = now.toIso8601String().replaceAll('Z', '');
      final parsed = asDate(bare)!;
      expect(now.difference(parsed.toUtc()).inMinutes.abs(), lessThan(1));
    });

    test('a leg that just departed is not hours old', () {
      final j = CourierJob.fromJson({
        'id': 1,
        'status': 'in_transit',
        'departed_at': DateTime.now().toUtc().toIso8601String().replaceAll('Z', ''),
      });
      expect(j.onRoadFor!.inMinutes.abs(), lessThan(1));
    });

    test('a timestamp that already carries a zone is trusted as it stands', () {
      final z = asDate('2026-09-24T09:00:00Z')!;
      expect(z.toUtc().hour, 9);
      final offset = asDate('2026-09-24T12:00:00+03:00')!;
      expect(offset.toUtc().hour, 9);
    });

    test('a date with no time is left alone', () {
      expect(asDate('2026-09-24')!.year, 2026);
      expect(asDate('')?.toString(), isNull);
    });
  });
}
