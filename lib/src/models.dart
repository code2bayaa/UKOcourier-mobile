/// What the driver's dashboard is made of.
///
/// These mirror `courier/back-end/app/serialize.py` — `courier_dict`, `job_dict`, `message_dict` and
/// the wallet summary — and nothing more. Fields the API sends that the phone has no use for are simply
/// not read; fields it needs are read defensively, because a partner on a two-year-old Android should
/// not be shown a crash because one nullable came back null.
///
/// **Neither hand-over code is ever his to give.** `pickup_code` belongs to the origin shelf owner and
/// `delivery_code` to the destination shelf owner: each reads his own out loud and the driver types it
/// in. The API sends them on a leg he has accepted only so the app can check the length before it
/// spends a round trip — it never shows them, and on the job board (`codes=False`) it does not send
/// them at all, because a driver who could read the pickup code off an offer he never took could walk
/// into the origin shelf and be handed the load.
library;

import 'package:uko_core/uko_core.dart';

/// The driver, as `courier_dict` sends him.
class Driver {
  Driver.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        name = asText(j['name'], 'Driver'),
        phone = asText(j['phone']),
        companyEmail = asText(j['company_email']),
        vehicleType = asText(j['vehicle_type'], 'van'),
        numberPlate = asText(j['number_plate']),
        capacityKg = asDouble(j['capacity_kg']),
        counties = (j['counties'] as List?)?.map((c) => '$c').toList() ?? const [],
        classes = (j['classes'] as List?)?.map((c) => '$c').toList() ?? const [],
        insured = j['insured'] == true,
        insurer = asText(j['insurer']),
        insuranceExpires = asDate(j['insurance_expires']),
        rating = asDouble(j['rating'], 5),
        trips = asInt(j['trips']),
        isOnline = j['is_online'] == true,
        status = asText(j['status'], 'active'),
        /// Staff link some drivers to a UKO shop account; only those can spend the wallet on UKO
        /// services in the shop. An unlinked driver works and is paid identically.
        linked = j['linked'] == true;

  final int id;
  final String name;
  final String phone;
  final String companyEmail;
  final String vehicleType;
  final String numberPlate;
  final double capacityKg;
  final List<String> counties;
  final List<String> classes;
  final bool insured;
  final String insurer;
  final DateTime? insuranceExpires;
  final double rating;
  final int trips;
  final bool isOnline;
  final String status;
  final bool linked;

  bool get active => status == 'active';

  /// Cover that has run out is not cover. The API makes the same check before it lets him take a
  /// fragile load (`can_carry`), and saying so on his profile is how he finds out before the board
  /// quietly empties rather than after.
  bool get coverLapsed =>
      insured && insuranceExpires != null && insuranceExpires!.isBefore(DateTime.now());

  bool get canCarryFragile => insured && !coverLapsed;
}

/// A shelf at either end of a leg.
class Shelf {
  Shelf.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        name = asText(j['name'], 'Shelf'),
        ownerName = asText(j['owner_name']),
        ward = asText(j['ward']),
        county = asText(j['county']),
        address = asText(j['address']),
        landmark = asText(j['landmark']),
        phone = asText(j['contact_phone']),
        openingTime = asText(j['opening_time']),
        closingTime = asText(j['closing_time']),
        lat = j['lat'] == null ? null : asDouble(j['lat']),
        lng = j['lng'] == null ? null : asDouble(j['lng']);

  final int id;
  final String name;
  final String ownerName;
  final String ward;
  final String county;
  final String address;
  final String landmark;
  final String phone;
  final String openingTime;
  final String closingTime;
  final double? lat;
  final double? lng;

  /// Where to point a driver who has never been here. The landmark matters more than the street on a
  /// Kenyan address, so it goes last where it is read last.
  String get where => [
        if (address.isNotEmpty) address,
        if (ward.isNotEmpty) ward,
        if (landmark.isNotEmpty) 'near $landmark',
      ].join(' · ');

  String get hours =>
      openingTime.isEmpty || closingTime.isEmpty ? '' : '$openingTime – $closingTime';
}

/// UKO's live-tracking state for a leg.
class JobTracking {
  JobTracking.fromJson(Map<String, dynamic> j)
      : url = asText(j['url']),
        lastSeenAt = asDate(j['last_seen_at']),
        warnMinutes = asInt(j['warn_minutes'], 20),
        missingMinutes = asInt(j['missing_minutes'], 60);

  final String url;
  final DateTime? lastSeenAt;
  final int warnMinutes;
  final int missingMinutes;
}

/// One step in a leg's history, as the API appends it.
class JobEvent {
  JobEvent.fromJson(Map<String, dynamic> j)
      : title = asText(j['title']),
        sub = asText(j['sub']),
        at = asDate(j['time']);

  final String title;
  final String sub;
  final DateTime? at;
}

/// One line of what is in the box.
class JobItem {
  JobItem.fromJson(Map<String, dynamic> j)
      : title = asText(j['title'], 'Item'),
        variant = asText(j['variant_label']),
        quantity = asInt(j['quantity'], 1);

  final String title;
  final String variant;
  final int quantity;

  String get line => '$quantity × $title${variant.isEmpty ? '' : ' · $variant'}';
}

/// A leg: a load going from a shelf in one county to a shelf in another.
///
/// The states run `offered → accepted → collected → in_transit → delivered`, and each one is a real
/// event with a witness: a shelf owner reads out the pickup code, the driver sets off, the far shelf
/// owner reads out the delivery code. There is no "out for delivery" and no buyer to phone, because a
/// courier never delivers to a person — the load lands at a shelf and the buyer collects there.
class CourierJob {
  CourierJob.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        waybillNo = asText(j['waybill_no']),
        kind = asText(j['kind'], 'order'),
        orderNo = asText(j['order_no']),
        returnNo = asText(j['return_no']),
        carrying = asText(j['carrying']),
        status = asText(j['status'], 'offered'),
        origin = j['origin'] == null ? null : Shelf.fromJson(asMap(j['origin'])),
        destinationShelf = j['destination_shelve'] == null
            ? null
            : Shelf.fromJson(asMap(j['destination_shelve'])),
        originCounty = asText(j['origin_county']),
        originWard = asText(j['origin_ward']),
        destinationCounty = asText(j['destination_county']),
        destinationWard = asText(j['destination_ward']),
        parcelClass = asText(j['parcel_class'], 'standard'),
        className = asText(j['class_name'], 'Standard'),
        classNote = asText(j['class_note']),
        categories = (j['categories'] as List?)?.map((c) => '$c').toList() ?? const [],
        weightKg = asDouble(j['weight_kg']),
        distanceKm = asDouble(j['distance_km']),
        fee = asDouble(j['fee']),
        driverEarns = asDouble(j['driver_earns']),
        departAt = asDate(j['depart_at']),
        departedAt = asDate(j['departed_at']),
        arrivedAt = asDate(j['arrived_at']),
        travelMinutes = asInt(j['travel_minutes']),
        offerExpires = asDate(j['offer_expires']),
        items = asList(j['items']).map(JobItem.fromJson).toList(),
        events = asList(j['events']).map(JobEvent.fromJson).toList(),
        tracking =
            j['tracking'] == null ? null : JobTracking.fromJson(asMap(j['tracking'])),
        // Board-only, and only on the board: whether he may take this load, and if not, why. The API
        // sends the reason rather than hiding the offer, so a driver can see that a road he does not
        // run or a cover that has lapsed is what is standing between him and the work.
        eligible = j['eligible'] != false,
        reason = asText(j['reason']),
        expiresIn = asInt(j['expires_in']);

  final int id;
  final String waybillNo;
  final String kind;
  final String orderNo;
  final String returnNo;
  final String carrying;
  final String status;
  final Shelf? origin;
  final Shelf? destinationShelf;
  final String originCounty;
  final String originWard;
  final String destinationCounty;
  final String destinationWard;
  final String parcelClass;
  final String className;
  final String classNote;
  final List<String> categories;
  final double weightKg;
  final double distanceKm;
  final double fee;
  final double driverEarns;
  final DateTime? departAt;
  final DateTime? departedAt;
  final DateTime? arrivedAt;
  final int travelMinutes;
  final DateTime? offerExpires;
  final List<JobItem> items;
  final List<JobEvent> events;
  final JobTracking? tracking;
  final bool eligible;
  final String reason;
  final int expiresIn;

  /// A seller's own item going home off a shelf (PRD 22), rather than a buyer's order. To the driver
  /// the leg is identical — two shelves, two codes — so this only changes what the screen calls it.
  bool get isReturn => kind == 'return';

  String get reference => isReturn && returnNo.isNotEmpty ? returnNo : orderNo;

  String get route => '$originCounty  →  $destinationCounty';

  /// Nobody's yet.
  bool get offered => status == 'offered';

  /// His, but the load is still on the shelf — the one state he may hand it back from.
  bool get waitingToCollect => status == 'accepted';

  /// On the van, not yet moving. The last moment before the travel clock starts.
  bool get loaded => status == 'collected';

  bool get onTheRoad => status == 'in_transit';

  bool get finished => status == 'delivered';

  /// Anything that counts as in his hands, which is what the tracker follows and what the "one at a
  /// time" rule counts.
  bool get mine => waitingToCollect || loaded || onTheRoad;

  /// How long the load has been travelling, for a leg still on the road. `travel_minutes` is only set
  /// once the far shelf signs for it, so before then the clock has to be read off `departed_at`.
  Duration? get onRoadFor =>
      departedAt == null ? null : DateTime.now().toUtc().difference(departedAt!.toUtc());
}

/// A message on a leg — to the shelf at whichever end the load is nearest, or to UKO.
class JobMessage {
  JobMessage.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        audience = asText(j['audience'], 'shelve'),
        senderRole = asText(j['sender_role']),
        senderName = asText(j['sender_name']),
        body = asText(j['body']),
        at = asDate(j['time']);

  final int id;
  final String audience;
  final String senderRole;
  final String senderName;
  final String body;
  final DateTime? at;

  bool get mine => senderRole == 'courier';
}

/// Everything `/courier/dashboard` returns, in one object.
class DriverDashboard {
  DriverDashboard.fromJson(Map<String, dynamic> j)
      : driver = Driver.fromJson(asMap(j['courier'])),
        active = asList(j['active']).map(CourierJob.fromJson).toList(),
        offered = asList(j['offered']).map(CourierJob.fromJson).toList(),
        completed = asList(j['completed']).map(CourierJob.fromJson).toList(),
        trips = asInt(asMap(j['stats'])['trips']),
        rating = asDouble(asMap(j['stats'])['rating'], 5),
        earningsWeek = asDouble(asMap(j['stats'])['earnings_week']),
        kmWeek = asDouble(asMap(j['stats'])['km_week']),
        avgHours = asDouble(asMap(j['stats'])['avg_hours']),
        commissionPct = asDouble(asMap(j['stats'])['commission_pct'], 10),
        wallet = asDouble(asMap(j['stats'])['wallet']),
        /// The waybill (or rider job) he already has in hand. While this is set the API offers him
        /// nothing — and it counts a *rider* job from the other app, because a partner cleared for
        /// both is still one man with one vehicle.
        currentJob = asText(asMap(j['stats'])['current_job']);

  final Driver driver;
  final List<CourierJob> active;
  final List<CourierJob> offered;
  final List<CourierJob> completed;
  final int trips;
  final double rating;
  final double earningsWeek;
  final double kmWeek;
  final double avgHours;
  final double commissionPct;
  final double wallet;
  final String currentJob;

  int get liveCount => active.length;

  /// Only the offers he could actually take. Badging him with work he is not cleared for would be a
  /// notification that resolves to "no".
  int get offerCount => offered.where((j) => j.eligible).length;

  bool get busy => currentJob.isNotEmpty;
}

/// One line of the wallet ledger.
class WalletEntry {
  WalletEntry.fromJson(Map<String, dynamic> j)
      : amount = asDouble(j['amount']),
        reason = asText(j['reason']),
        ref = asText(j['ref']),
        at = asDate(j['time']);

  final double amount;
  final String reason;
  final String ref;
  final DateTime? at;

  String get label => switch (reason) {
        'courier_fee' => 'Leg',
        'withdrawal' => 'Withdrawal to M-PESA',
        'withdrawal_fee' => 'Withdrawal fee',
        'withdrawal_refund' => 'Withdrawal returned',
        _ => reason.replaceAll('_', ' '),
      };
}

/// The driver's wallet, as `wallet_summary` sends it.
class Wallet {
  Wallet.fromJson(Map<String, dynamic> j)
      : balance = asDouble(j['balance']),
        minWithdrawal = asDouble(j['min_withdrawal'], 100),
        feePct = asDouble(j['fee_pct'], 10),
        mpesaNumber = asText(j['mpesa_number']),
        linked = j['linked'] == true,
        ledger = asList(j['ledger']).map(WalletEntry.fromJson).toList();

  final double balance;
  final double minWithdrawal;
  final double feePct;
  final String mpesaNumber;
  final bool linked;
  final List<WalletEntry> ledger;

  bool get canWithdraw => balance >= minWithdrawal;

  /// What actually reaches his phone. Legs already pay him net of UKO's commission; the withdrawal fee
  /// is a *second* ten per cent, on money leaving UKO — and a partner should never discover that one
  /// at payout.
  double netOf(double amount) => amount - amount * feePct / 100;
}
