// lib/services/whisper_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/voice_command.dart';

class WhisperService {
  String? _baseUrl;
  bool _isConnected = false;
  Map<String, dynamic> _lastHealthCheck = {};

  // Configuración por defecto
  static const int DEFAULT_TIMEOUT = 30; // segundos
  static const int MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

  bool get isConnected => _isConnected;
  Map<String, dynamic> get lastHealthCheck => _lastHealthCheck;

  /// Conectar al servicio Whisper FastAPI
  Future<bool> connect(String host, int port) async {
    _baseUrl = 'http://$host:$port';

    print('🔄 Conectando a Whisper Service: $_baseUrl');

    try {
      final healthResult = await checkHealth();
      _isConnected = healthResult;

      if (_isConnected) {
        print('✅ Conectado a Whisper Service');
        print('📦 Modelo: ${_lastHealthCheck['whisper_model'] ?? 'desconocido'}');
        print('🤖 ROS2: ${_lastHealthCheck['ros2_available'] ?? false}');
      } else {
        print('❌ No se pudo conectar a Whisper Service');
      }

      return _isConnected;

    } catch (e) {
      print('❌ Error conectando a Whisper Service: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Verificar salud del servicio
  Future<bool> checkHealth() async {
    if (_baseUrl == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'FlutterWhisperClient/1.0',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        _lastHealthCheck = jsonDecode(response.body);
        return _lastHealthCheck['status'] == 'healthy';
      } else {
        print('⚠️ Health check falló: ${response.statusCode}');
        return false;
      }

    } catch (e) {
      print('❌ Error en health check: $e');
      return false;
    }
  }

  /// Transcribir archivo de audio usando Whisper
  Future<VoiceCommandResult> transcribeAudio(String audioFilePath) async {
    if (!_isConnected || _baseUrl == null) {
      return VoiceCommandResult(
        success: false,
        error: 'No conectado al servicio Whisper',
      );
    }

    final audioFile = File(audioFilePath);

    // Verificaciones previas
    if (!await audioFile.exists()) {
      return VoiceCommandResult(
        success: false,
        error: 'Archivo de audio no encontrado',
      );
    }

    final fileSize = await audioFile.length();
    if (fileSize > MAX_FILE_SIZE) {
      return VoiceCommandResult(
        success: false,
        error: 'Archivo demasiado grande: ${fileSize} bytes (máx: ${MAX_FILE_SIZE})',
      );
    }

    if (fileSize < 1000) {
      return VoiceCommandResult(
        success: false,
        error: 'Archivo demasiado pequeño: ${fileSize} bytes',
      );
    }

    try {
      print('🎵 Enviando audio a Whisper: ${audioFile.path} (${fileSize} bytes)');

      final startTime = DateTime.now();

      // Crear request multipart
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/transcribe'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'FlutterWhisperClient/1.0',
      });

      // Agregar archivo de audio
      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFile.path),
      );

      // Enviar request con timeout
      final streamedResponse = await request.send().timeout(
        Duration(seconds: DEFAULT_TIMEOUT),
      );

      final response = await http.Response.fromStream(streamedResponse);
      final processingTime = DateTime.now().difference(startTime).inMilliseconds / 1000.0;

      print('📥 Respuesta Whisper: ${response.statusCode} (${processingTime.toStringAsFixed(2)}s)');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final result = VoiceCommandResult(
          success: data['success'] ?? false,
          transcription: data['transcription'],
          confidence: data['confidence']?.toDouble(),
          aiResponse: data['transcription'], // La transcripción ES la respuesta
          timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
        );

        if (result.success && result.transcription != null && result.transcription!.isNotEmpty) {
          print('📝 Transcripción exitosa: "${result.transcription}"');
          print('🎯 Confianza: ${(result.confidence! * 100).toStringAsFixed(1)}%');

          // Verificar si se publicó en ROS2
          if (data['ros2_published'] == true) {
            print('📡 Comando enviado a ROS2 automáticamente');
          }
        } else {
          print('⚠️ Transcripción vacía o fallida');
        }

        return result;

      } else {
        final errorData = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'detail': 'Error desconocido'};

        final errorMsg = errorData['detail'] ?? 'Error del servidor';
        print('❌ Error del servidor Whisper: $errorMsg');

        return VoiceCommandResult(
          success: false,
          error: errorMsg,
          aiResponse: 'Error de transcripción: $errorMsg',
        );
      }

    } catch (e) {
      print('❌ Error transcribiendo audio: $e');

      String errorMessage;
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Timeout - El servidor tardó demasiado en responder';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Error de conexión - Verifica que el servidor esté ejecutándose';
      } else {
        errorMessage = 'Error inesperado: ${e.toString()}';
      }

      return VoiceCommandResult(
        success: false,
        error: errorMessage,
        aiResponse: errorMessage,
      );
    }
  }

  /// Enviar comando de texto directamente al sistema ROS2
  Future<VoiceCommandResult> sendTextCommand(String command) async {
    if (!_isConnected || _baseUrl == null) {
      return VoiceCommandResult(
        success: false,
        error: 'No conectado al servicio Whisper',
      );
    }

    if (command.trim().isEmpty) {
      return VoiceCommandResult(
        success: false,
        error: 'Comando vacío',
      );
    }

    try {
      print('💬 Enviando comando texto: "$command"');

      final response = await http.post(
        Uri.parse('$_baseUrl/send_text_command'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'FlutterWhisperClient/1.0',
        },
        body: jsonEncode({'command': command.trim()}),
      ).timeout(Duration(seconds: 10));

      print('📥 Respuesta comando texto: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print('✅ Comando enviado a ROS2: "${data['command_sent']}"');

        return VoiceCommandResult(
          success: data['success'] ?? false,
          transcription: command, // El comando original
          aiResponse: 'Comando "${command}" enviado al robot',
          commandType: 'text_command',
          timestamp: data['timestamp']?.toDouble(),
        );

      } else {
        final errorData = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'detail': 'Error desconocido'};

        final errorMsg = errorData['detail'] ?? 'Error del servidor';
        print('❌ Error enviando comando: $errorMsg');

        return VoiceCommandResult(
          success: false,
          error: errorMsg,
          aiResponse: 'Error enviando comando: $errorMsg',
        );
      }

    } catch (e) {
      print('❌ Error enviando comando de texto: $e');
      return VoiceCommandResult(
        success: false,
        error: e.toString(),
        aiResponse: 'Error de conexión: ${e.toString()}',
      );
    }
  }

  /// Obtener información del servicio
  Future<Map<String, dynamic>?> getServiceInfo() async {
    if (_baseUrl == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('⚠️ Error obteniendo info del servicio: $e');
    }

    return null;
  }

  /// Desconectar del servicio
  void disconnect() {
    _isConnected = false;
    _baseUrl = null;
    _lastHealthCheck.clear();
    print('🔌 Desconectado de Whisper Service');
  }

  /// Obtener estadísticas del último health check
  Map<String, dynamic> getServiceStats() {
    return {
      'connected': _isConnected,
      'whisper_available': _lastHealthCheck['services']?['whisper'] ?? false,
      'ros2_available': _lastHealthCheck['ros2_available'] ?? false,
      'gpu_available': _lastHealthCheck['services']?['gpu'] ?? false,
      'model': _lastHealthCheck['whisper_model'] ?? 'desconocido',
      'last_check': _lastHealthCheck['timestamp'],
    };
  }
}