// lib/services/enhanced_websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/voice_command.dart';

class EnhancedWebSocketService {
  String? _baseUrl;
  bool _isConnected = false;
  Timer? _healthCheckTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 3;

  // Estado de servicios
  bool _whisperAvailable = false;
  bool _ros2Connected = false;
  bool _audioProcessingAvailable = false;

  // Callbacks para la UI
  Function(Map<String, dynamic>)? onConnectionStatus;
  Function(VoiceCommandResult)? onCommandResult;
  Function(VoiceCommandResult)? onTranscriptionResult;
  Function(Map<String, dynamic>)? onRobotStatus;

  // Getters públicos
  bool get isConnected => _isConnected;

  bool get whisperAvailable => _whisperAvailable;

  bool get ros2Connected => _ros2Connected;

  Future<void> connect(String host, int port) async {
    _baseUrl = 'http://$host:$port';

    print('🔄 Conectando a Whisper FastAPI: $_baseUrl');

    try {
      // Verificar que el servicio FastAPI esté disponible
      final health = await _checkHealth();
      if (!health['success']) {
        throw Exception('Servicio FastAPI no disponible: ${health['error']}');
      }

      _isConnected = true;
      _reconnectAttempts = 0;

      // Actualizar estado de servicios
      _whisperAvailable = health['services']['whisper'] ?? false;
      _ros2Connected = health['services']['ros2'] ?? false;
      _audioProcessingAvailable =
          health['services']['audio_processing'] ?? false;

      print('✅ Conectado a Whisper FastAPI');
      print('   - Whisper: ${_whisperAvailable ? "✅" : "❌"}');
      print('   - ROS2: ${_ros2Connected ? "✅" : "❌"}');
      print('   - Audio Processing: ${_audioProcessingAvailable ? "✅" : "❌"}');

      // Notificar estado
      onConnectionStatus?.call({
        'status': 'connected',
        'server': '$host:$port',
        'services': {
          'whisper': _whisperAvailable,
          'ros2': _ros2Connected,
          'audio_processing': _audioProcessingAvailable,
        },
        'whisper_available': _whisperAvailable
      });

      // Iniciar monitoreo de salud
      _startHealthCheck();
    } catch (e) {
      print('❌ Error conectando a FastAPI: $e');
      _isConnected = false;
      onConnectionStatus?.call({
        'status': 'connection_error',
        'error': e.toString()
      });
      _scheduleReconnect();
      throw e;
    }
  }

  Future<Map<String, dynamic>> _checkHealth() async {
    if (_baseUrl == null) {
      return {'success': false, 'error': 'Base URL not set'};
    }

    try {
      print('🏥 Verificando salud del servicio...');

      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'FlutterVoiceRobot/2.0',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Estado servicios: ${data['services']}');

        return {
          'success': true,
          'services': data['services'] ?? {},
          'status': data['status']
        };
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      print('❌ Error en health check: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_isConnected) {
        final health = await _checkHealth();
        if (!health['success']) {
          print('⚠️ Servicio no saludable, reconectando...');
          _handleConnectionLoss();
        } else {
          // Actualizar estado de servicios
          final services = health['services'] ?? {};
          _whisperAvailable = services['whisper'] ?? false;
          _ros2Connected = services['ros2'] ?? false;
          _audioProcessingAvailable = services['audio_processing'] ?? false;
        }
      }
    });
  }

  void _handleConnectionLoss() {
    _isConnected = false;
    _healthCheckTimer?.cancel();

    onConnectionStatus?.call({
      'status': 'connection_lost'
    });

    if (_reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      _scheduleReconnect();
    } else {
      print('❌ Máximo de intentos de reconexión alcanzado');
      onConnectionStatus?.call({
        'status': 'max_reconnect_attempts'
      });
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final delay = Duration(seconds: _reconnectAttempts * 3);
    print(
        '🔄 Reconectando en ${delay.inSeconds}s (intento $_reconnectAttempts)');

    onConnectionStatus?.call({
      'status': 'reconnecting',
      'delay_seconds': delay.inSeconds,
      'attempt': _reconnectAttempts
    });

    _reconnectTimer = Timer(delay, () {
      if (_baseUrl != null && !_isConnected) {
        final uri = Uri.parse(_baseUrl!);
        connect(uri.host, uri.port).catchError((e) {
          print('❌ Error en reconexión: $e');
        });
      }
    });
  }

  // === MÉTODOS PRINCIPALES ===

  Future<VoiceCommandResult> processAudioCommand(String audioPath) async {
    if (!_isConnected || !_whisperAvailable) {
      return VoiceCommandResult(
          success: false,
          error: 'Whisper no disponible',
          aiResponse: 'Servicio de transcripción no disponible'
      );
    }

    try {
      print('🎵 Enviando audio a FastAPI: $audioPath');

      final file = File(audioPath);
      if (!await file.exists()) {
        return VoiceCommandResult(
            success: false,
            error: 'Archivo de audio no encontrado',
            aiResponse: 'Error: archivo no encontrado'
        );
      }

      final fileSize = await file.length();
      print('📁 Tamaño del archivo: $fileSize bytes');

      // Crear petición multipart
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/transcribe'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'FlutterVoiceRobot/2.0',
      });

      request.files.add(
          await http.MultipartFile.fromPath('audio', audioPath)
      );

      print('⏳ Enviando petición a Whisper...');
      final response = await request.send().timeout(Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();

      print('📥 Respuesta FastAPI: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);

        final result = VoiceCommandResult(
            success: data['success'] ?? false,
            transcription: data['transcription'],
            aiResponse: data['ai_response'],
            confidence: data['confidence']?.toDouble(),
            timestamp: data['timestamp']?.toDouble(),
            robotAction: data['ros2_published'],
            error: data['error']
        );

        print('✅ Transcripción: "${result.transcription}"');
        print('🤖 ROS2 publicado: ${result.robotAction}');

        // Notificar resultado
        onTranscriptionResult?.call(result);
        onCommandResult?.call(result);

        return result;
      } else {
        final error = 'Error HTTP ${response.statusCode}: $responseBody';
        print('❌ $error');

        return VoiceCommandResult(
            success: false,
            error: error,
            aiResponse: 'Error procesando audio'
        );
      }
    } catch (e) {
      print('❌ Error enviando audio: $e');

      // Si es error de conexión, manejar pérdida
      if (e is SocketException || e.toString().contains('Connection')) {
        _handleConnectionLoss();
      }

      return VoiceCommandResult(
          success: false,
          error: e.toString(),
          aiResponse: 'Error de conexión: $e'
      );
    }
  }

  Future<VoiceCommandResult> sendTextCommand(String command) async {
    if (!_isConnected) {
      return VoiceCommandResult(
          success: false,
          error: 'No conectado al servidor',
          aiResponse: 'Sin conexión al servidor FastAPI'
      );
    }

    try {
      print('💬 Enviando comando de texto: "$command"');

      final response = await http.post(
        Uri.parse('$_baseUrl/send_text_command'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'FlutterVoiceRobot/2.0',
        },
        body: jsonEncode({'command': command}),
      ).timeout(Duration(seconds: 20));

      print('📥 Respuesta: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final result = VoiceCommandResult(
            success: data['success'] ?? false,
            transcription: command,
            // El texto enviado
            aiResponse: data['ai_response'],
            timestamp: data['timestamp']?.toDouble(),
            robotAction: data['ros2_published'],
            commandType: 'text',
            error: data['error']
        );

        print('✅ Comando enviado a ROS2: ${result.robotAction}');

        // Notificar resultado
        onCommandResult?.call(result);

        return result;
      } else {
        final error = 'Error HTTP ${response.statusCode}: ${response.body}';
        print('❌ $error');

        return VoiceCommandResult(
            success: false,
            error: error,
            aiResponse: 'Error enviando comando'
        );
      }
    } catch (e) {
      print('❌ Error enviando comando de texto: $e');

      if (e is SocketException || e.toString().contains('Connection')) {
        _handleConnectionLoss();
      }

      return VoiceCommandResult(
          success: false,
          error: e.toString(),
          aiResponse: 'Error: $e'
      );
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    if (!_isConnected) {
      return {'success': false, 'error': 'No conectado'};
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stats'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'FlutterVoiceRobot/2.0',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  void requestStatus() {
    if (_isConnected) {
      _checkHealth().then((health) {
        onConnectionStatus?.call({
          'status': health['success'] ? 'healthy' : 'unhealthy',
          'services': health['services'] ?? {},
          'whisper_available': _whisperAvailable
        });
      });
    }
  }

  void disconnect() {
    print('🔌 Desconectando de Whisper FastAPI...');

    _healthCheckTimer?.cancel();
    _reconnectTimer?.cancel();

    _isConnected = false;
    _reconnectAttempts = 0;
    _whisperAvailable = false;
    _ros2Connected = false;
    _audioProcessingAvailable = false;

    onConnectionStatus?.call({
      'status': 'disconnected'
    });

    print('✅ Desconectado de FastAPI');
  }
}