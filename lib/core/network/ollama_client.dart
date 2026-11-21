import 'package:dio/dio.dart';

import '../../domain/services/prompt_builder.dart';

/// Where AI requests go: directly to Ollama, or relayed through the server.
enum AiMode { direct, relay }

/// Sends [Prompt]s to Ollama and returns the raw text response.
class AiClient {
  final Dio _dio;
  final String ollamaUrl; // e.g. http://192.168.1.10:11434
  final String model;
  final String? relayUrl; // server URL, used when mode == relay
  final AiMode mode;

  AiClient({
    required this.ollamaUrl,
    required this.model,
    this.relayUrl,
    this.mode = AiMode.direct,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options.receiveTimeout = const Duration(minutes: 5);
  }

  Future<String> generate(Prompt p) async {
    if (mode == AiMode.relay && relayUrl != null) {
      return _relay(p);
    }
    return _direct(p);
  }

  Future<String> _direct(Prompt p) async {
    final url = '${ollamaUrl.trim().replaceAll(RegExp(r'/+$'), '')}/api/chat';
    final body = <String, dynamic>{
      'model': model,
      'stream': false,
      if (p.json) 'format': 'json',
      'messages': [
        if (p.system.isNotEmpty) {'role': 'system', 'content': p.system},
        {'role': 'user', 'content': p.user},
      ],
    };
    final resp = await _dio.post<Map<String, dynamic>>(url, data: body);
    final data = resp.data;
    if (data == null) return '';
    final msg = data['message'];
    if (msg is Map) {
      final content = msg['content'];
      return content?.toString() ?? '';
    }
    return data['response']?.toString() ?? '';
  }

  Future<String> _relay(Prompt p) async {
    final url =
        '${relayUrl!.trim().replaceAll(RegExp(r'/+$'), '')}/api/ai/relay';
    final resp = await _dio.post<Map<String, dynamic>>(
      url,
      data: {
        'model': model,
        'system': p.system,
        'prompt': p.user,
        'json': p.json,
      },
    );
    final data = resp.data;
    return data?['content']?.toString() ?? '';
  }

  /// List available models (direct mode only; used in settings UI).
  Future<List<String>> listModels() async {
    final url =
        '${ollamaUrl.trim().replaceAll(RegExp(r'/+$'), '')}/api/tags';
    final resp = await _dio.get<dynamic>(url);
    final data = resp.data;
    if (data is Map && data['models'] is List) {
      return (data['models'] as List)
          .map((e) => (e is Map ? e['name'] : e)?.toString() ?? '')
          .toList();
    }
    return const [];
  }
}
