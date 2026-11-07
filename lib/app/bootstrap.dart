import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/zelo_logo.dart';
import 'app.dart';
import 'theme/app_theme.dart';

final firebaseInitializationProvider = FutureProvider<void>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    throw UnsupportedError('Only Android is configured for the ZELO MVP.');
  }
  // Android resources are generated from android/app/google-services.json.
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  await FirebaseAuth.instance.setLanguageCode('pt-BR');
}, retry: (retryCount, error) => null);

class ZeloBootstrap extends ConsumerWidget {
  const ZeloBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(firebaseInitializationProvider);
    if (initialization.hasValue) return const ZeloApp();
    return MaterialApp(
      title: 'ZELO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ZeloLogo(),
                  const SizedBox(height: 24),
                  if (initialization.hasError) ...[
                    const Text(
                      'Não foi possível iniciar o ZELO. Verifique a configuração '
                      'e tente novamente no aplicativo Android.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(firebaseInitializationProvider),
                      child: const Text('Tentar novamente'),
                    ),
                  ] else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
