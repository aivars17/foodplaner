import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/config/app_config.dart';
import 'core/local/document_store.dart';
import 'core/network/ollama_client.dart';
import 'core/network/sync_client.dart';
import 'ui/screens/home_screen.dart';

/// Root widget. Loads per-device config, builds the [AppStore] with a local
/// document store, optional sync client and AI client, and provides it to the
/// UI via [StoreProvider].
class FoodPlanerApp extends StatefulWidget {
  final String storePath;
  const FoodPlanerApp({super.key, required this.storePath});

  @override
  State<FoodPlanerApp> createState() => _FoodPlanerAppState();
}

class _FoodPlanerAppState extends State<FoodPlanerApp> {
  final _config = AppConfig();
  late Future<AppStore> _store;

  @override
  void initState() {
    super.initState();
    _store = _buildStore();
  }

  Future<AppStore> _buildStore() async {
    final docs = LocalDocumentStore();
    await docs.load(widget.storePath);

    // AI client (direct Ollama or via server relay).
    final ollamaUrl = await _config.getOllamaUrl();
    final model = await _config.getModel();
    final mode = await _config.getAiMode();
    final serverUrl = await _config.getServerUrl();
    final ai = AiClient(
      ollamaUrl: ollamaUrl,
      model: model,
      relayUrl: mode == 'relay' ? serverUrl : null,
      mode: mode == 'relay' ? AiMode.relay : AiMode.direct,
    );

    // Sync client (only when a server URL is configured).
    SyncClient? sync;
    if (serverUrl != null && serverUrl.isNotEmpty) {
      sync = SyncClient(baseUrl: serverUrl);
      sync.connect();
    }

    final store = AppStore(docs: docs, config: _config, sync: sync, ai: ai);

    // Wire remote changes from the server into the store.
    sync?.remoteChanges.listen(store.applyRemoteChange);

    await store.load();
    return store;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStore>(
      future: _store,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Klaida: ${snap.error}'),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final store = snap.data!;
        return StoreProvider(
          store: store,
          child: MaterialApp(
            title: 'FoodPlaner',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme:
                  ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            home: const HomeScreen(),
          ),
        );
      },
    );
  }
}

/// Provides the [AppStore] and listens to it so dependents rebuild.
class StoreProvider extends InheritedNotifier<AppStore> {
  const StoreProvider({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<StoreProvider>();
    if (p == null) {
      throw StateError('StoreProvider not found above this widget');
    }
    return p.notifier!;
  }
}
