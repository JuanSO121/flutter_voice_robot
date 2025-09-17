// lib/services/websocket_service.dart (VERSIÓN CORREGIDA PARA HTTP PURO)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/voice_command.dart';

class WebSocketService {
  String? _baseUrl;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 5;

  // Callbacks para la UI
  Function(Map<String, dynamic>)? onConnectionStatus;
  Function(VoiceCommandResult)? onCommandResult;
  Function(Map<String, dynamic>)? onRobotStatus;

  Future<void> connect(String host, int port) async {
    _baseUrl = 'http://$host:$port';

    print('🔄 Intentando conectar a: $_baseUrl');

    try {
      // Verificar que el servidor HTTP esté disponible
      final healthCheck = await _checkServerHealth();
      if (!healthCheck) {
        throw Exception('Servidor no disponible en $host:$port');
      }

      _isConnected = true;
      _reconnectAttempts = 0;

      print('✅ Conexión HTTP establecida exitosamente');

      // Notificar estado de conexión
      onConnectionStatus?.call({
        'status': 'Conectado',
        'server': '$host:$port'
      });

      // Solicitar estado inicial
      await _requestStatus();

    } catch (e) {
      print('❌ Error conectando: $e');
      _isConnected = false;
      onConnectionStatus?.call({
        'status': 'Error de conexión',
        'error': e.toString()
      });
      _scheduleReconnect();
      throw e;
    }
  }

  Future<bool> _checkServerHealth() async {
    try {
      print('🏥 Verificando servidor en: $_baseUrl/health');

      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Connection': 'keep-alive',
          'User-Agent': 'FlutterVoiceRobot/1.0'
        },
      ).timeout(Duration(seconds: 15)); // Timeout más generoso

      print('📡 Respuesta servidor: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Servidor HTTP respondiendo correctamente');
        try {
          final healthData = jsonDecode(response.body);
          print('🔍 Estado servicios: ${healthData['services']}');
        } catch (e) {
          print('⚠️ Respuesta no es JSON válido: ${response.body}');
        }
        return true;
      } else {
        print('⚠️ Servidor respondió con código: ${response.statusCode}');
        print('📄 Body: ${response.body}');
        return false;
      }

    } catch (e) {
      print('❌ Error verificando servidor: $e');
      if (e is SocketException) {
        print('🔍 Detalles de conexión: ${e.message}');
        print('🔍 Dirección: ${e.address}');
        print('🔍 Puerto: ${e.port}');
      }
      return false;
    }
  }

  Future<void> _requestStatus() async {
    if (_baseUrl == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/robot_status'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final statusData = jsonDecode(response.body);
        onRobotStatus?.call(statusData);
      }
    } catch (e) {
      print('⚠️ Error obteniendo estado inicial: $e');
    }
  }

  void _handleConnectionLoss() {
    _isConnected = false;
    _heartbeatTimer?.cancel();

    onConnectionStatus?.call({
      'status': 'Conexión perdida',
    });

    if (_reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      _scheduleReconnect();
    } else {
      print('❌ Máximo de intentos de reconexión alcanzado');
      onConnectionStatus?.call({
        'status': 'Desconectado - Max intentos',
      });
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final delay = Duration(seconds: _reconnectAttempts * 2);
    print('🔄 Reconectando en ${delay.inSeconds}s (intento $_reconnectAttempts/$MAX_RECONNECT_ATTEMPTS)');

    onConnectionStatus?.call({
      'status': 'Reconectando en ${delay.inSeconds}s',
    });

    _reconnectTimer = Timer(delay, () {
      if (!_isConnected) {
        _reconnect();
      }
    });
  }

  Future<void> _reconnect() async {
    try {
      if (_baseUrl != null) {
        final uri = Uri.parse(_baseUrl!);
        await connect(uri.host, uri.port);
      }
    } catch (e) {
      print('❌ Error en reconexión: $e');
      _scheduleReconnect();
    }
  }

  // === MÉTODOS PÚBLICOS ===

  Future<VoiceCommandResult> sendAudioFile(String audioPath) async {
    if (_baseUrl == null || !_isConnected) {
      throw Exception('No conectado al servidor');
    }

    try {
      print('🎵 Enviando audio: $audioPath');

      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Archivo de audio no encontrado');
      }

      final fileSize = await file.length();
      if (fileSize < 1000) {
        throw Exception('Archivo de audio demasiado pequeño: ${fileSize} bytes');
      }

      print('📁 Tamaño del archivo: ${fileSize} bytes');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/process_audio'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'FlutterVoiceRobot/1.0',
      });

      request.files.add(
          await http.MultipartFile.fromPath('audio', audioPath)
      );

      print('⏳ Enviando petición HTTP...');
      final response = await request.send().timeout(Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();

      print('📥 Respuesta del servidor: ${response.statusCode}');
      print('📄 Body respuesta: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        print('📝 Resultado: ${data['ai_response']}');
        return VoiceCommandResult.fromJson(data);
      } else {
        print('❌ Error del servidor: $responseBody');
        throw Exception('Error del servidor: ${response.statusCode} - $responseBody');
      }

    } catch (e) {
      print('❌ Error enviando audio: $e');

      // Si es error de conexión, marcar como desconectado
      if (e is SocketException || e.toString().contains('Connection')) {
        _handleConnectionLoss();
      }

      return VoiceCommandResult(
        success: false,
        error: e.toString(),
        aiResponse: 'Error de conexión: ${e.toString()}',
      );
    }
  }

  Future<VoiceCommandResult> sendTextCommand(String command) async {
    if (_baseUrl == null || !_isConnected) {
      throw Exception('No conectado al servidor');
    }

    try {
      print('💬 Enviando comando de texto: $command');

      final response = await http.post(
        Uri.parse('$_baseUrl/send_text_command'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'FlutterVoiceRobot/1.0',
        },
        body: jsonEncode({'command': command}),
      ).timeout(Duration(seconds: 20));

      print('📥 Respuesta: ${response.statusCode}');
      print('📄 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📝 Respuesta IA: ${data['ai_response']}');
        return VoiceCommandResult.fromJson(data);
      } else {
        throw Exception('Error del servidor: ${response.statusCode} - ${response.body}');
      }

    } catch (e) {
      print('❌ Error enviando comando de texto: $e');

      // Si es error de conexión, marcar como desconectado
      if (e is SocketException || e.toString().contains('Connection')) {
        _handleConnectionLoss();
      }

      return VoiceCommandResult(
        success: false,
        error: e.toString(),
        aiResponse: 'Error: ${e.toString()}',
      );
    }
  }

  void requestStatus() {
    _requestStatus();
  }

  bool get isConnected => _isConnected;

  void disconnect() {
    print('🔌 Desconectando...');

    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    _isConnected = false;
    _reconnectAttempts = 0;

    onConnectionStatus?.call({
      'status': 'Desconectado',
    });

    print('✅ Desconectado');
  }
}