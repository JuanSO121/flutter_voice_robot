// lib/services/diagnostic_service.dart - ACTUALIZADO con detección automática
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dynamic_ip_detector.dart'; // ← NUEVO IMPORT

class DiagnosticService {
  static const Duration _timeout = Duration(seconds: 3);

  /// ↓ ACTUALIZADO: Usar detección automática de IP
  static Future<Map<String, dynamic>> runFullDiagnostic({
    String? ip, // ← Ahora opcional - se detecta automáticamente si es null
    int port = 8000,
    required int timeout,
  }) async {

    // ↓ NUEVO: Detectar IP automáticamente si no se proporciona
    String serverIP;
    if (ip != null) {
      serverIP = ip;
      print('🔍 Usando IP especificada: $ip');
    } else {
      print('🔍 Detectando IP automáticamente...');
      final detectedIP = await DynamicIPDetector.detectWhisperServerIP();
      if (detectedIP == null) {
        return {
          'internet': await checkInternetConnection(),
          'server_found': false,
          'server_ip': null,
          'server_port': port,
          'response_time': null,
          'server_health': null,
          'errors': ['No se pudo detectar servidor automáticamente'],
          'timestamp': DateTime.now().toIso8601String(),
          'detection_method': 'automatic_failed'
        };
      }
      serverIP = detectedIP;
      print('✅ IP detectada automáticamente: $serverIP');
    }

    final Map<String, dynamic> report = {
      'internet': false,
      'server_found': false,
      'server_ip': serverIP,
      'server_port': port,
      'response_time': null,
      'server_health': null,
      'errors': [],
      'timestamp': DateTime.now().toIso8601String(),
      'detection_method': ip != null ? 'manual' : 'automatic'
    };

    // 1. Verificar Internet básico
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(_timeout);
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        report['internet'] = true;
      }
    } catch (e) {
      report['errors'].add('Sin conexión a internet: $e');
    }

    // 2. Verificar conexión TCP al servidor
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(serverIP, port, timeout: _timeout);
      stopwatch.stop();

      report['server_found'] = true;
      report['response_time'] = stopwatch.elapsedMilliseconds;

      await socket.close();

      // 3. Si TCP funciona, probar HTTP
      try {
        final response = await http.get(
          Uri.parse('http://$serverIP:$port/health'),
          headers: {'Connection': 'close'},
        ).timeout(_timeout);

        if (response.statusCode == 200) {
          report['server_health'] = 'healthy';
          report['health_response'] = response.body;
        } else {
          report['server_health'] = 'responding_but_error';
          report['http_status'] = response.statusCode;
        }
      } catch (e) {
        report['errors'].add('HTTP error: $e');
        report['server_health'] = 'tcp_ok_http_fail';
      }

    } catch (e) {
      stopwatch.stop();
      report['errors'].add('Servidor no disponible en $serverIP:$port -> $e');
      report['server_found'] = false;
    }

    return report;
  }

  /// ↓ ACTUALIZADO: Usar detección automática en lugar de lista estática
  static Future<String?> findServerIP({
    List<String>? possibleIPs,
    int port = 8000,
  }) async {

    if (possibleIPs != null) {
      // Modo legacy: usar IPs proporcionadas
      print('🔍 Buscando servidor en ${possibleIPs.length} IPs especificadas...');

      for (int i = 0; i < possibleIPs.length; i += 3) {
        final batch = possibleIPs.skip(i).take(3).toList();
        final futures = batch.map((ip) => _testServerQuick(ip, port)).toList();
        final results = await Future.wait(futures);

        for (int j = 0; j < results.length; j++) {
          if (results[j]) {
            final foundIP = batch[j];
            print('✅ Servidor encontrado en: $foundIP');
            return foundIP;
          }
        }
      }

      print('❌ No se encontró servidor en las IPs especificadas');
    }

    // ↓ NUEVO: Usar detección automática como método principal
    print('🔍 Usando detección automática...');
    final detectedIP = await DynamicIPDetector.detectWhisperServerIP();

    if (detectedIP != null) {
      print('✅ Servidor detectado automáticamente en: $detectedIP');
      return detectedIP;
    }

    print('❌ No se encontró servidor con detección automática');
    return null;
  }

  /// Test rápido de una IP específica (sin cambios)
  static Future<bool> _testServerQuick(String ip, int port) async {
    try {
      print('🔍 Probando: $ip:$port');

      final socket = await Socket.connect(
          ip,
          port,
          timeout: Duration(seconds: 2)
      );

      await socket.close();
      print('✅ $ip:$port responde');
      return true;

    } catch (e) {
      print('❌ $ip:$port no disponible');
      return false;
    }
  }

  /// ↓ ACTUALIZADO: Incluir información de detección automática
  static String formatDiagnosticReport(Map<String, dynamic> report) {
    final buffer = StringBuffer();
    buffer.writeln('=== 📋 DIAGNÓSTICO DEL SISTEMA ===');
    buffer.writeln('🕒 Timestamp: ${report['timestamp']}');

    // ↓ NUEVO: Mostrar método de detección
    final detectionMethod = report['detection_method'] ?? 'unknown';
    final detectionEmoji = detectionMethod == 'automatic' ? '🤖' : '👤';
    buffer.writeln('$detectionEmoji Detección: ${detectionMethod == 'automatic' ? 'Automática' : 'Manual'}');

    buffer.writeln('🌍 Internet: ${report['internet'] ? '✅' : '❌'}');
    buffer.writeln('🤖 Servidor encontrado: ${report['server_found'] ? '✅' : '❌'}');
    buffer.writeln('🔌 IP/Puerto: ${report['server_ip']}:${report['server_port']}');

    if (report['response_time'] != null) {
      buffer.writeln('⏱️ Tiempo de respuesta: ${report['response_time']}ms');
    }

    if (report['server_health'] != null) {
      final healthEmoji = report['server_health'] == 'healthy' ? '💚' : '💛';
      buffer.writeln('🏥 Estado del servidor: $healthEmoji ${report['server_health']}');
    }

    if (report['http_status'] != null) {
      buffer.writeln('📡 HTTP Status: ${report['http_status']}');
    }

    if (report['errors'].isNotEmpty) {
      buffer.writeln('\n⚠️ Errores detectados:');
      for (var error in report['errors']) {
        buffer.writeln('  - $error');
      }
    }

    buffer.writeln('==================================');
    return buffer.toString();
  }

  /// Verificar conectividad básica a internet (sin cambios)
  static Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(_timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// ↓ ACTUALIZADO: Usar DynamicIPDetector para validación
  static Future<Map<String, dynamic>> pingServer(String ip, int port) async {
    final result = {
      'ip': ip,
      'port': port,
      'reachable': false,
      'response_time': null,
      'error': null,
      'whisper_service': false, // ← NUEVO: Verificar si es Whisper
    };

    final stopwatch = Stopwatch()..start();

    try {
      // Test básico de conectividad
      final socket = await Socket.connect(ip, port, timeout: _timeout);
      stopwatch.stop();

      result['reachable'] = true;
      result['response_time'] = stopwatch.elapsedMilliseconds;

      await socket.close();

      // ↓ NUEVO: Verificar si es realmente el servicio Whisper
      result['whisper_service'] = await DynamicIPDetector.verifyWhisperService(ip, port);

    } catch (e) {
      stopwatch.stop();
      result['error'] = e.toString();
    }

    return result;
  }

  /// ↓ NUEVO: Diagnóstico completo con información de red
  static Future<Map<String, dynamic>> runCompleteDiagnostic() async {
    final diagnosticResults = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'basic_diagnostic': {},
      'network_info': {},
      'detection_results': {},
    };

    try {
      // Diagnóstico básico con detección automática
      diagnosticResults['basic_diagnostic'] = await runFullDiagnostic(timeout: 5);

      // Información completa de red
      diagnosticResults['network_info'] = await DynamicIPDetector.getNetworkDiagnostics();

      // Resultados específicos de detección
      final detectedIP = await DynamicIPDetector.detectWhisperServerIP();
      diagnosticResults['detection_results'] = {
        'detected_ip': detectedIP,
        'detection_successful': detectedIP != null,
        'validation_passed': detectedIP != null
            ? await DynamicIPDetector.verifyWhisperService(detectedIP, 8000)
            : false,
      };

    } catch (e) {
      diagnosticResults['error'] = e.toString();
    }

    return diagnosticResults;
  }

  /// ↓ NUEVO: Función de conveniencia para re-detección
  static Future<String?> redetectServerIP({String? currentIP}) async {
    print('🔄 Re-detectando servidor IP...');

    // Si hay IP actual, verificarla primero
    if (currentIP != null) {
      final isValid = await DynamicIPDetector.verifyWhisperService(currentIP, 8000);
      if (isValid) {
        print('✅ IP actual sigue válida: $currentIP');
        return currentIP;
      }
      print('❌ IP actual ya no válida: $currentIP');
    }

    // Nueva detección
    final newIP = await DynamicIPDetector.detectWhisperServerIP();
    if (newIP != null) {
      print('✅ Nueva IP detectada: $newIP');
    } else {
      print('❌ No se pudo re-detectar servidor');
    }

    return newIP;
  }
}