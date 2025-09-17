// lib/utils/network_helper.dart
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkHelper {
  // IPs comunes para WSL2 y desarrollo local
  static const List<String> COMMON_IPS = [
    '172.17.192.1',
    '172.17.192.179',     // IP típica WSL2
    '172.18.0.1',         // Docker WSL2
    '172.19.0.1',         // Docker alternativo
    '192.168.1.3',        // IP Windows común
    '10.0.0.1',           // Red privada
    'localhost',          // Desarrollo local
    '172.17.192.1',          // Loopback
  ];

  static const int WHISPER_PORT = 8000;
  static const int ROSBRIDGE_PORT = 9090;
  static const int PING_TIMEOUT = 3; // segundos
  static const int HTTP_TIMEOUT = 5; // segundos

  /// Ejecutar diagnóstico completo de red
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final startTime = DateTime.now();

    print('🔍 Iniciando diagnóstico de red...');

    final results = <String, dynamic>{
      'internet': false,
      'server_found': false,
      'server_ip': null,
      'flask_port': false,
      'rosbridge_port': false,
      'diagnosis_time': 0,
      'tested_ips': <String>[],
      'successful_ips': <String>[],
    };

    try {
      // 1. Verificar conexión a internet
      print('🌐 Verificando conexión a internet...');
      results['internet'] = await _checkInternet();

      if (!results['internet']) {
        print('❌ Sin conexión a internet');
        return _finalizeDiagnosis(results, startTime);
      }

      // 2. Buscar servidor Whisper
      print('🔍 Buscando servidor Whisper...');
      final serverSearch = await _findWhisperServer();

      if (serverSearch != null) {
        results['server_found'] = true;
        results['server_ip'] = serverSearch['ip'];
        results['flask_port'] = serverSearch['flask_working'];
        results['rosbridge_port'] = serverSearch['rosbridge_working'];
        results['successful_ips'].add(serverSearch['ip']);

        print('✅ Servidor encontrado en: ${serverSearch['ip']}');
      } else {
        print('❌ No se encontró servidor Whisper');
      }

      results['tested_ips'] = COMMON_IPS;

    } catch (e) {
      print('❌ Error en diagnóstico: $e');
      results['error'] = e.toString();
    }

    return _finalizeDiagnosis(results, startTime);
  }

  /// Verificar conexión básica a internet
  static Future<bool> _checkInternet() async {
    try {
      // Intentar conectar a Google DNS
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: PING_TIMEOUT));

      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;

    } catch (e) {
      print('⚠️ Error verificando internet: $e');
      return false;
    }
  }

  /// Buscar servidor Whisper en IPs comunes
  static Future<Map<String, dynamic>?> _findWhisperServer() async {
    for (final ip in COMMON_IPS) {
      try {
        print('🔍 Probando IP: $ip');

        // Verificar si el host responde (ping básico)
        final hostReachable = await _isHostReachable(ip);
        if (!hostReachable) {
          print('❌ $ip no responde');
          continue;
        }

        // Verificar puerto Flask (Whisper)
        final flaskWorking = await _checkWhisperService(ip, WHISPER_PORT);

        if (flaskWorking) {
          // También verificar Rosbridge si es posible
          final rosbridgeWorking = await _checkPort(ip, ROSBRIDGE_PORT);

          return {
            'ip': ip,
            'flask_working': true,
            'rosbridge_working': rosbridgeWorking,
          };
        }

      } catch (e) {
        print('⚠️ Error probando $ip: $e');
        continue;
      }
    }

    return null;
  }

  /// Verificar si un host es alcanzable
  static Future<bool> _isHostReachable(String host) async {
    try {
      // Para localhost y 127.0.0.1, asumir que son alcanzables
      if (host == 'localhost' || host == '127.0.0.1') {
        return true;
      }

      // Intentar resolver DNS
      final addresses = await InternetAddress.lookup(host)
          .timeout(Duration(seconds: 2));

      return addresses.isNotEmpty;

    } catch (e) {
      // Si falla la resolución DNS, intentar conectar directamente
      try {
        final socket = await Socket.connect(host, 80, timeout: Duration(seconds: 2));
        await socket.close();
        return true;
      } catch (e2) {
        return false;
      }
    }
  }

  /// Verificar específicamente el servicio Whisper
  static Future<bool> _checkWhisperService(String host, int port) async {
    try {
      print('🎤 Verificando Whisper en $host:$port');

      final response = await http.get(
        Uri.parse('http://$host:$port/health'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'FlutterDiagnostic/1.0',
        },
      ).timeout(Duration(seconds: HTTP_TIMEOUT));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final isWhisperHealthy = data['status'] == 'healthy' &&
              data['services']?['whisper'] == true;

          if (isWhisperHealthy) {
            print('✅ Whisper Service verificado en $host:$port');
            print('📦 Modelo: ${data['whisper_model'] ?? 'unknown'}');
            print('🤖 ROS2: ${data['ros2_available'] ?? false}');
            return true;
          }
        } catch (e) {
          print('⚠️ Respuesta no es JSON válido de Whisper');
        }
      }

      return false;

    } catch (e) {
      print('❌ Error verificando Whisper en $host:$port - $e');
      return false;
    }
  }

  /// Verificar si un puerto específico está abierto
  static Future<bool> _checkPort(String host, int port) async {
    try {
      final socket = await Socket.connect(
          host,
          port,
          timeout: Duration(seconds: PING_TIMEOUT)
      );
      await socket.close();
      return true;

    } catch (e) {
      return false;
    }
  }

  /// Finalizar diagnóstico y calcular tiempo
  static Map<String, dynamic> _finalizeDiagnosis(
      Map<String, dynamic> results,
      DateTime startTime
      ) {
    final endTime = DateTime.now();
    results['diagnosis_time'] = endTime.difference(startTime).inMilliseconds;

    print('🏁 Diagnóstico completado en ${results['diagnosis_time']}ms');
    return results;
  }

  /// Obtener la IP de WSL2 dinámicamente (Windows)
  static Future<String?> getWSL2IP() async {
    try {
      if (!Platform.isWindows) return null;

      // Intentar obtener IP de WSL2 usando comando
      final result = await Process.run(
        'wsl',
        ['hostname', '-I'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        final ips = output.split(' ');

        // Buscar IP en rango típico de WSL2
        for (final ip in ips) {
          if (ip.startsWith('172.') || ip.startsWith('192.168.')) {
            print('🔍 IP WSL2 detectada: $ip');
            return ip;
          }
        }
      }

    } catch (e) {
      print('⚠️ Error obteniendo IP WSL2: $e');
    }

    return null;
  }

  /// Test rápido de conectividad
  static Future<bool> quickConnectivityTest(String host, int port) async {
    try {
      final response = await http.get(
        Uri.parse('http://$host:$port/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 3));

      return response.statusCode == 200;

    } catch (e) {
      return false;
    }
  }

  /// Obtener información de red del dispositivo
  static Future<Map<String, dynamic>> getNetworkInfo() async {
    final info = <String, dynamic>{};

    try {
      // Obtener interfaces de red
      final interfaces = await NetworkInterface.list();

      info['interfaces'] = interfaces.map((interface) => {
        'name': interface.name,
        'addresses': interface.addresses.map((addr) => addr.address).toList(),
      }).toList();

      // Detectar WSL2 si estamos en Windows
      if (Platform.isWindows) {
        info['wsl2_ip'] = await getWSL2IP();
      }

    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }
}