import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/auth/secure_storage_service.dart';
import 'core/api/api_client.dart';

// Firebase.initializeApp() is deferred to Phase 3 (Notifications) once
// firebase_options.dart is generated via `flutterfire configure`.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await SecureStorageService.create();
  final apiClient = await ApiClient.create(storage);

  runApp(
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWithValue(apiClient),
      ],
      child: const App(),
    ),
  );
}
