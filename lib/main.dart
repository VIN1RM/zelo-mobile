import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Karla',
    ], await rootBundle.loadString('assets/fonts/karla/OFL.txt'));
  });
  runApp(const ProviderScope(child: ZeloBootstrap()));
}
