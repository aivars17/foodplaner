import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Per-device (non-synced) configuration: where the sync server and Ollama live.
class AppConfig {
  static const _serverUrlKey = 'server_url';
  static const _ollamaUrlKey = 'ollama_url';
  static const _modelKey = 'model';
  static const _aiModeKey = 'ai_mode'; // 'direct' | 'relay'

  final FlutterSecureStorage _storage;

  AppConfig({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage();

  Future<String?> getServerUrl() => _storage.read(key: _serverUrlKey);
  Future<void> setServerUrl(String url) =>
      _storage.write(key: _serverUrlKey, value: url.trim());

  Future<String> getOllamaUrl() async =>
      (await _storage.read(key: _ollamaUrlKey)) ?? 'http://localhost:11434';
  Future<void> setOllamaUrl(String url) =>
      _storage.write(key: _ollamaUrlKey, value: url.trim());

  Future<String> getModel() async =>
      (await _storage.read(key: _modelKey)) ?? 'qwen3.8:27b';
  Future<void> setModel(String model) =>
      _storage.write(key: _modelKey, value: model.trim());

  /// 'direct' or 'relay'.
  Future<String> getAiMode() async =>
      (await _storage.read(key: _aiModeKey)) ?? 'direct';
  Future<void> setAiMode(String mode) =>
      _storage.write(key: _aiModeKey, value: mode);
}
