/// UKO courier — the driver's app.
///
/// Points at the courier API (`courier/back-end`, port 8016). The base URL is a `--dart-define`; see
/// `src/config.dart` for why and for the emulator / handset / production forms.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A driver reads this at a shelf gate with one hand. Landscape gains nothing and loses the code boxes.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const UkoCourierApp());
}
