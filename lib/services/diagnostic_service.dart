// lib/services/diagnostic_service.dart
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class DiagnosticService {
  static const Duration _timeout = Duration(seconds: 3);

  /// Ejecuta un diagnóstico completo del servidor
  static Future<Map<String, dynamic>> runFullDiagnostic({
    String ip = '172.17.192.179',
    int port = 8000, required int timeout,
  }) async {
    final Map<String, dynamic> report = {
      'internet': false,
      'server_found': false,
      'server_ip': ip,
      'server_port': port,
      'response_time': null,
      'server_health': null,
      'errors': [],
      'timestamp': DateTime.now().toIso8601String(),
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
      final socket = await Socket.connect(ip, port, timeout: _timeout);
      stopwatch.stop();

      report['server_found'] = true;
      report['response_time'] = stopwatch.elapsedMilliseconds;

      await socket.close();

      // 3. Si TCP funciona, probar HTTP
      try {
        final response = await http.get(
          Uri.parse('http://$ip:$port/health'),
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
      report['errors'].add('Servidor no disponible en $ip:$port -> $e');
      report['server_found'] = false;
    }

    return report;
  }

  /// Buscar el servidor en múltiples IPs posibles
  static Future<String?> findServerIP({
    List<String>? possibleIPs,
    int port = 8000,
  }) async {
    possibleIPs ??= [
      '172.17.192.179',  // IP detectada
      '172.17.0.1',      // WSL2 común
      '172.31.176.1',    // WSL2 alternativa
      '172.16.0.1',      // Privada
      '10.0.0.1',        // Privada
      '172.17.192.1',    // Local
      '192.168.0.100',   // Local
      'localhost',       // Local
      '127.0.0.1',       // Loopback
    ];

    print('🔍 Buscando servidor en ${possibleIPs.length} IPs posibles...');

    // Probar IPs en paralelo (pero limitado para no saturar)
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

    print('❌ No se encontró servidor en ninguna IP');
    return null;
  }

  /// Test rápido de una IP específica
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

  /// Convertir el diagnóstico en texto legible
  static String formatDiagnosticReport(Map<String, dynamic> report) {
    final buffer = StringBuffer();
    buffer.writeln('=== 📋 DIAGNÓSTICO DEL SISTEMA ===');
    buffer.writeln('🕒 Timestamp: ${report['timestamp']}');
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

  /// Verificar conectividad básica a internet
  static Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(_timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Ping específico a una IP
  static Future<Map<String, dynamic>> pingServer(String ip, int port) async {
    final result = {
      'ip': ip,
      'port': port,
      'reachable': false,
      'response_time': null,
      'error': null,
    };

    final stopwatch = Stopwatch()..start();

    try {
      final socket = await Socket.connect(ip, port, timeout: _timeout);
      stopwatch.stop();

      result['reachable'] = true;
      result['response_time'] = stopwatch.elapsedMilliseconds;

      await socket.close();

    } catch (e) {
      stopwatch.stop();
      result['error'] = e.toString();
    }

    return result;
  }
}