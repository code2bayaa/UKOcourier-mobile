/// Every call the courier app makes, in one place.
///
/// Thin on purpose: the courier API already decides everything that matters — whether a driver may
/// carry a load, whether a code is right, what he earns — and re-deciding any of it here would only
/// create a second opinion to be wrong. So these methods carry arguments to the server and turn what
/// comes back into the models next door. The rules live in `courier/back-end/app/routers/courier.py`.
///
/// The one thing the app does decide is *when* to stop asking: a 401 means the two-hour session is
/// over, and `ApiClient` reports that to the auth controller so the driver is sent to sign in rather
/// than shown "Not authenticated" on top of a leg he is halfway through.
library;

import 'package:uko_core/uko_core.dart';

import 'models.dart';

class CourierApi {
  CourierApi(this.client);

  final ApiClient client;

  // ---------------------------------------------------------------- the dashboard
  Future<DriverDashboard> dashboard() async =>
      DriverDashboard.fromJson(asMap(await client.get('/courier/dashboard')));

  Future<bool> toggleOnline() async {
    final body = asMap(await client.post('/courier/toggle-online'));
    return body['is_online'] == true;
  }

  // ---------------------------------------------------------------- the leg
  /// Take a load. `departAt` is when he plans to set off (PRD 19, time of travel) — the origin shelf
  /// is told, so an owner knows whether to expect him this afternoon or on Thursday.
  Future<void> acceptJob(int id, {DateTime? departAt}) => client.post(
        '/courier/jobs/$id/accept',
        body: {'depart_at': departAt?.toUtc().toIso8601String()},
      );

  /// Give an accepted waybill back to the board. The API refuses this once the load is on the van —
  /// at that point it is a phone call to the courier desk, not a button.
  Future<void> declineJob(int id) => client.post('/courier/jobs/$id/decline');

  /// The origin shelf owner reads out *his* pickup code and the load goes on the van.
  Future<void> collect(int id, String handoffCode) =>
      client.post('/courier/jobs/$id/collect', body: {'handoff_code': handoffCode});

  /// The van leaves. This is the moment `travel_minutes` is measured from, which is why it is a
  /// deliberate tap and not inferred from the first GPS fix that moves.
  Future<void> depart(int id) => client.post('/courier/jobs/$id/depart');

  /// The destination shelf owner signs for the load with *his* delivery code. The leg is finished and
  /// the driver is paid — the buyer's escrow is not released here, because the parcel has reached a
  /// shelf and not a person.
  Future<void> arrive(int id, String handoffCode, {String photo = ''}) =>
      client.post('/courier/jobs/$id/arrive',
          body: {'handoff_code': handoffCode, 'photo': photo});

  // ---------------------------------------------------------------- chat on a leg
  /// Both threads: to the shelf at whichever end the load is nearest, and to UKO. Opening them marks
  /// anything addressed to him as read, which is also what clears the badge.
  Future<({List<JobMessage> shelve, List<JobMessage> admin})> messages(int id) async {
    final body = asMap(await client.get('/courier/jobs/$id/messages'));
    return (
      shelve: asList(body['shelve']).map(JobMessage.fromJson).toList(),
      admin: asList(body['admin']).map(JobMessage.fromJson).toList(),
    );
  }

  Future<void> send(int id, {required String audience, required String body}) =>
      client.post('/courier/jobs/$id/messages',
          body: {'audience': audience, 'body': body});

  Future<int> unread() async {
    final body = asMap(await client.get('/courier/messages/unread'));
    return asInt(body['unread']);
  }

  // ---------------------------------------------------------------- money
  Future<Wallet> wallet() async =>
      Wallet.fromJson(asMap(await client.get('/wallet', query: {'role': 'courier'})));

  Future<void> withdraw({required double amount, required String account}) =>
      client.post('/wallet/withdraw', body: {
        'role': 'courier',
        'method': 'mpesa',
        'account': account,
        'amount': amount,
      });
}
