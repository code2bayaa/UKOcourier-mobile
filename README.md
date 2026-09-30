# UKO courier — driver app (Flutter)

The driver's phone app. Same API as the web console (`courier/back-end`, port 8016), same two-step
sign-in, same codes, same money — and the same reason to exist as the rider app, only more so.

```
courier/front-end/
├─ web-app/     React 19 + TanStack Router  →  http://localhost:3016
└─ mobile/      Flutter 3.47 (this)         →  Android + iOS
```

## Why a native app at all

> **Live GPS while a load is on the van** (PRD 21). The web console uses `navigator.geolocation`, which
> stops the moment the phone locks or the tab loses focus. Here the OS keeps a foreground service
> running, so the fixes carry on with the screen off and the phone in the cab.

A rider is out of contact for twenty minutes; a driver is on the Nairobi–Mombasa road for six hours
with somebody else's goods in the back. The watchdog windows are longer to match —
`COURIER_TRACK_WARN_MINUTES` 20 and `COURIER_TRACK_MISSING_MINUTES` 60, against the rider's 10 and 30 —
which cuts both ways: a driver who loses signal in a dead spot is not instantly an incident, and a
broken tracker goes unnoticed for an hour rather than half of one.

## How a leg runs

Five states, each one a real event with a witness:

| | what happens | who proves it |
|---|---|---|
| `offered` | on the board | — |
| `accepted` | he takes it and says when he plans to leave | the origin shelf is told |
| `collected` | the load goes on the van | the **origin** shelf owner reads out his `pickup_code` |
| `in_transit` | he sets off — this starts `travel_minutes` | his own tap |
| `delivered` | the load comes off at the far shelf | the **destination** shelf owner reads out his `delivery_code` |

**Neither code is ever the driver's to give, and the app never shows either.** The man letting the load
go reads his code out loud and the man taking it types it in. A driver who could read the pickup code
off an offer he never accepted could walk into the origin shelf and be handed the load — which is why
`job_dict(codes=False)` strips both from every leg on the board.

Delivering does **not** release the buyer's escrow, unlike a rider's drop. The parcel has reached a
shelf, not a person: the order becomes `ready`, the driver is paid his share of the leg fee, and the
buyer either walks in with his shelve code or books a rider for the last mile.

## Running it

The toolchain lives at `F:\dev` (Flutter 3.47.5, JDK 17, Android SDK 36). From this folder:

```powershell
flutter pub get
flutter run --dart-define=UKO_API=http://10.0.2.2:8016
```

`10.0.2.2` is the Android emulator's alias for the machine running it. **On a real handset that is the
handset**, so pass the laptop's LAN address instead:

```powershell
flutter run --dart-define=UKO_API=http://192.168.1.20:8016
flutter build apk --release --dart-define=UKO_API=https://courier.uko-app.co.ke
```

### Checking it in a browser

`flutter build web` is the quickest way to put the real screens in front of the real API — everything
but the tracker works, and the tracker correctly reports that the browser refused it.

```powershell
flutter build web --dart-define=UKO_API=http://127.0.0.1:8016
python -m http.server 5011 --directory build/web
```

**`127.0.0.1`, not `localhost`.** `courier/back-end/run.ps1` binds uvicorn to `127.0.0.1` only, and a
browser asking for `localhost` may resolve it to `::1` and get `ERR_CONNECTION_REFUSED` while the API is
up and the port is listening. The app reports that as *"Could not reach UKO"* — the same sentence it
shows when the server really is down, so it is worth ruling out first.

Demo driver: the seeded driver signs in with his **company email** once staff have assigned one (admin
console → Couriers). With no SMTP configured the API cannot send the 6-digit code, so it hands it back
in the response and the sign-in screen shows it — that never happens against a server with mail set up.

```powershell
flutter analyze
flutter test
```

## What is on the screens

| Screen | What |
|---|---|
| Sign in | Company e-mail + password, then the 6-digit code e-mailed to that address. **Accepting location tracking is a condition of signing in**, and the OS permission is requested at the code step — with the reason on screen, not at launch where it means nothing and gets denied forever |
| Board | The stat row, then every leg UKO has going. Legs he **cannot** take are shown too, below the rest, each carrying the API's own reason — a road he does not run, a class he is not cleared for, cover that has lapsed, weight past his capacity. A filtered board would be shorter and would hide the one thing he could go and fix |
| On road | The single leg in his hands, with the tracking state above it. There is only ever one: the API refuses a second, and that count includes a **rider** job from the delivery app, because a partner cleared for both is still one man with one vehicle |
| Leg | One action at a time — collect, depart, or hand over — because at any moment there is exactly one thing he can do, and a screen offering three buttons on a highway is a screen that gets the wrong one pressed |
| Chat | Two threads, kept apart: the shelf (whichever end the load is at, which the server decides) and UKO. "I am two hours out" belongs to an owner; "the load is short one box" belongs to a record |
| Earnings | Balance, the week, the ledger, and M-PESA withdrawal — showing what actually lands on his phone before he taps. Legs already pay `driver_earns` (net of UKO's 10 %), and withdrawing costs the 10 % withdrawal fee again. Two different tens |
| Profile | His vehicle, and the three gates that decide whether the board has anything on it: counties, classes, and goods-in-transit cover. The cover is the only one that expires on its own while he sleeps, so it says so plainly |

## What the app does not decide

Almost nothing. The API decides whether a leg may be accepted, whether a code is right, what he earns
and when he is paid; `lib/src/api.dart` carries arguments there and turns the answer into models. Error
messages from the back-end go on screen **unchanged**, because they are written for the person reading
them — "You do not run Nairobi → Kisumu" is a better sentence than anything the app would invent.

## Shared code

`mobile/uko_core` (path dependency) holds everything the rider app needs too: the HTTP client and its
error handling, the two-step sign-in, the tracker and location consent, the money and date formatting,
the design tokens from `docs/wireframe.pen`, the wireframe chrome (top bar, bottom tabs, stat cards,
the M8 timeline), the GPS banner and tracking-link card, and the four-digit code box that every
transfer of custody in UKO rests on.

What is *not* shared is anything that knows what a job is. A delivery and a courier leg have different
states, different codes, different hand-overs and different watchdog windows, and flattening them into
one model would cost more than it saved.

## Platform bits that fail silently if you touch them

* `android/app/src/main/AndroidManifest.xml` — `ACCESS_FINE_LOCATION`, `FOREGROUND_SERVICE` and
  **`FOREGROUND_SERVICE_LOCATION`** (Android 14+ refuses the service without the typed one). Deliberately
  no `ACCESS_BACKGROUND_LOCATION`: a foreground service with its ongoing notification covers the job and
  avoids Play Store's prominent-disclosure review, and UKO never tracks a driver who has no load.
* `ios/Runner/Info.plist` — the two `NSLocation*UsageDescription` strings and `UIBackgroundModes:
  location`. iOS refuses a location request outright when the usage string is missing, and the refusal
  is indistinguishable from the driver denying permission.

Get any of these wrong and nothing crashes: the app runs, his own map moves, and UKO simply never hears
from him until the watchdog raises the alarm — an hour later, on a road, with a load on board.
