// lib/utils/network_helper.dart - ACTUALIZADO con detección automática
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/dynamic_ip_detector.dart'; // ← NUEVO IMPORT

class NetworkHelper {
  // ↓ ELIMINADO: IPs estáticas - ahora se usa detección automática
  static const int WHISPER_PORT = 8000;
  static const int ROSBRIDGE_PORT = 9090;
  static const int PING_TIMEOUT = 3; // segundos
  static const int HTTP_TIMEOUT = 5; // segundos

  /// Ejecutar diagnóstico completo de red usando detección automática
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final startTime = DateTime.now();

    print('🔍 Iniciando diagnóstico completo con detección automática...');

    final results = <String, dynamic>{
      'internet': false,
      'server_found': false,
      'server_ip': null,
      'flask_port': false,
      'rosbridge_port': false,
      'diagnosis_time': 0,
      'detection_method': 'automatic',
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

      // 2. ↓ NUEVO: Usar detección automática de IP
      print('🔍 Usando detección automática de servidor Whisper...');
      final detectedIP = await DynamicIPDetector.detectWhisperServerIP();

      if (detectedIP != null) {
        results['server_found'] = true;
        results['server_ip'] = detectedIP;
        results['successful_ips'].add(detectedIP);

        // Verificar puertos específicos
        results['flask_port'] = await _checkWhisperService(detectedIP, WHISPER_PORT);
        results['rosbridge_port'] = await _checkPort(detectedIP, ROSBRIDGE_PORT);

        print('✅ Servidor detectado automáticamente en: $detectedIP');
        print('   - Whisper (puerto $WHISPER_PORT): ${results['flask_port']}');
        print('   - RosBridge (puerto $ROSBRIDGE_PORT): ${results['rosbridge_port']}');
      } else {
        print('❌ No se detectó servidor Whisper automáticamente');
      }

      // 3. ↓ NUEVO: Obtener información de diagnóstico detallado
      final networkDiagnostics = await DynamicIPDetector.getNetworkDiagnostics();
      results['network_diagnostics'] = networkDiagnostics;
      results['tested_ips'] = networkDiagnostics['all_candidates'] ?? [];

    } catch (e) {
      print('❌ Error en diagnóstico automático: $e');
      results['error'] = e.toString();
    }

    return _finalizeDiagnosis(results, startTime);
  }

  /// Método legacy - ahora usa detección automática internamente
  @deprecated
  static Future<Map<String, dynamic>?> _findWhisperServer() async {
    print('⚠️ Usando método legacy, se recomienda usar detección automática');

    final detectedIP = await DynamicIPDetector.detectWhisperServerIP();

    if (detectedIP != null) {
      final flaskWorking = await _checkWhisperService(detectedIP, WHISPER_PORT);
      final rosbridgeWorking = await _checkPort(detectedIP, ROSBRIDGE_PORT);

      if (flaskWorking) {
        return {
          'ip': detectedIP,
          'flask_working': true,
          'rosbridge_working': rosbridgeWorking,
        };
      }
    }

    return null;
  }

  /// Verificar conexión básica a internet (sin cambios)
  static Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: PING_TIMEOUT));

      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;

    } catch (e) {
      print('⚠️ Error verificando internet: $e');
      return false;
    }
  }

  /// Verificar específicamente el servicio Whisper (sin cambios)
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

  /// Verificar si un puerto específico está abierto (sin cambios)
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

  /// Finalizar diagnóstico y calcular tiempo (sin cambios)
  static Map<String, dynamic> _finalizeDiagnosis(
      Map<String, dynamic> results,
      DateTime startTime
      ) {
    final endTime = DateTime.now();
    results['diagnosis_time'] = endTime.difference(startTime).inMilliseconds;

    print('🏁 Diagnóstico completado en ${results['diagnosis_time']}ms');
    return results;
  }

  /// ↓ NUEVO: Detección automática de IP del servidor Whisper
  static Future<String?> detectWhisperServerIP() async {
    return await DynamicIPDetector.detectWhisperServerIP();
  }

  /// ↓ ACTUALIZADO: Usa detección automática
  static Future<String?> getWSL2IP() async {
    return await DynamicIPDetector.detectWSL2IP();
  }

  /// Test rápido de conectividad (sin cambios)
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

  /// ↓ ACTUALIZADO: Usa DynamicIPDetector para información completa
  static Future<Map<String, dynamic>> getNetworkInfo() async {
    final info = <String, dynamic>{};

    try {
      // Usar diagnóstico completo del DynamicIPDetector
      final diagnostics = await DynamicIPDetector.getNetworkDiagnostics();

      info['detection_method'] = 'automatic';
      info['network_interfaces'] = diagnostics['network_interfaces'];
      info['all_candidates'] = diagnostics['all_candidates'];
      info['gateway_ips'] = diagnostics['gateway_ips'];

      // Información específica de WSL2 si está en Windows
      if (Platform.isWindows) {
        info['wsl2_ip'] = diagnostics['wsl2_ip'];
      }

      info['whisper_server_detected'] = await detectWhisperServerIP();

    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }

  /// ↓ NUEVO: Validar que una IP detectada sigue funcionando
  static Future<bool> validateDetectedIP(String ip) async {
    return await DynamicIPDetector.verifyWhisperService(ip, WHISPER_PORT);
  }

  /// ↓ NUEVO: Re-detectar IP si la actual falla
  static Future<String?> redetectServerIP(String? currentIP) async {
    print('🔄 Re-detectando servidor IP...');

    // Si hay una IP actual, probarla primero
    if (currentIP != null) {
      print('🔍 Verificando IP actual: $currentIP');
      final isStillValid = await validateDetectedIP(currentIP);
      if (isStillValid) {
        print('✅ IP actual sigue siendo válida: $currentIP');
        return currentIP;
      } else {
        print('❌ IP actual ya no es válida: $currentIP');
      }
    }

    // Ejecutar nueva detección
    print('🔍 Ejecutando nueva detección automática...');
    final newIP = await detectWhisperServerIP();

    if (newIP != null) {
      print('✅ Nueva IP detectada: $newIP');
    } else {
      print('❌ No se pudo re-detectar servidor');
    }

    return newIP;
  }

  /// ↓ NUEVO: Monitoreo continuo de IP (útil para reconexiones automáticas)
  static Stream<String?> monitorServerIP({
    String? currentIP,
    Duration interval = const Duration(seconds: 30),
  }) async* {
    String? lastValidIP = currentIP;

    while (true) {
      await Future.delayed(interval);

      try {
        // Verificar IP actual
        if (lastValidIP != null) {
          final isValid = await validateDetectedIP(lastValidIP);
          if (isValid) {
            yield lastValidIP; // IP sigue siendo válida
            continue;
          }
        }

        // Re-detectar si es necesario
        final newIP = await detectWhisperServerIP();
        if (newIP != lastValidIP) {
          lastValidIP = newIP;
          yield newIP; // Nueva IP detectada o null si no se encontró
        }

      } catch (e) {
        print('⚠️ Error en monitoreo de IP: $e');
        yield null; // Error en la detección
      }
    }
  }

  /// ↓ NUEVO: Configuración de red para desarrollo (debugging)
  static Map<String, dynamic> getDevelopmentNetworkConfig() {
    return {
      'whisper_port': WHISPER_PORT,
      'rosbridge_port': ROSBRIDGE_PORT,
      'ping_timeout': PING_TIMEOUT,
      'http_timeout': HTTP_TIMEOUT,
      'detection_method': 'automatic',
      'platform': Platform.operatingSystem,
      'supports_wsl2': Platform.isWindows,
      'recommended_commands': {
        'start_whisper': 'python3 ~/ros2_ws/src/tutorial_pkg/tutorial_pkg/whisper_fastapi_service.py',
        'check_wsl2': 'wsl hostname -I',
        'check_ports': 'netstat -an | grep :8000',
      }
    };
  }
}