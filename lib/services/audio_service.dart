// lib/services/audio_service.dart
import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  Timer? _continuousTimer;

  bool _isInitialized = false;
  bool _isRecording = false;
  String? _currentRecordingPath;

  Function(String)? _onContinuousAudio;

  Future<void> initialize() async {
    try {
      // Solicitar permisos de micrófono
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        throw Exception('Permiso de micrófono denegado');
      }

      // Inicializar Record y AudioPlayer
      _recorder = AudioRecorder();
      _player = AudioPlayer();

      _isInitialized = true;
      print('✅ AudioService inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando AudioService: $e');
      throw e;
    }
  }

  Future<void> startRecording() async {
    if (!_isInitialized || _isRecording) return;

    try {
      // Verificar permisos nuevamente
      if (await _recorder!.hasPermission() == false) {
        throw Exception('Sin permisos de micrófono');
      }

      // Crear archivo temporal para la grabación
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/voice_command_$timestamp.wav';

      // Configuración de grabación optimizada para Whisper
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        bitRate: 128000,
        numChannels: 1,
      );

      await _recorder!.start(config, path: _currentRecordingPath!);
      _isRecording = true;
      print('🎤 Grabación iniciada: $_currentRecordingPath');

    } catch (e) {
      print('❌ Error iniciando grabación: $e');
      throw e;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder!.stop();
      _isRecording = false;

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          print('🛑 Grabación detenida: $path (${size} bytes)');

          // Verificar que el archivo tiene contenido
          if (size > 1000) { // Al menos 1KB
            return path;
          } else {
            print('⚠️ Archivo de audio demasiado pequeño: ${size} bytes');
            return null;
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error deteniendo grabación: $e');
      _isRecording = false;
      throw e;
    }
  }

  void enableContinuousListening(Function(String) onAudioDetected) {
    _onContinuousAudio = onAudioDetected;

    // Iniciar grabación continua cada 4 segundos
    _continuousTimer = Timer.periodic(Duration(seconds: 4), (timer) async {
      if (!_isRecording) {
        try {
          await startRecording();

          // Grabar por 3 segundos
          Timer(Duration(seconds: 3), () async {
            final audioPath = await stopRecording();
            if (audioPath != null && _onContinuousAudio != null) {
              _onContinuousAudio!(audioPath);
            }
          });
        } catch (e) {
          print('⚠️ Error en grabación continua: $e');
        }
      }
    });

    print('🔄 Escucha continua activada');
  }

  void disableContinuousListening() {
    _continuousTimer?.cancel();
    _continuousTimer = null;
    _onContinuousAudio = null;

    if (_isRecording) {
      stopRecording();
    }

    print('⏸️ Escucha continua desactivada');
  }

  Future<void> playAudioFile(String filePath) async {
    if (!_isInitialized) return;

    try {
      await _player!.play(DeviceFileSource(filePath));
      print('🔊 Reproduciendo: $filePath');
    } catch (e) {
      print('❌ Error reproduciendo audio: $e');
    }
  }

  // Metodo para verificar si el micrófono está disponible
  Future<bool> checkMicrophonePermission() async {
    if (_recorder == null) return false;
    return await _recorder!.hasPermission();
  }

  // Metodo para verificar amplitud de audio (si está grabando)
  Stream<Amplitude>? getAmplitudeStream() {
    if (_recorder != null && _isRecording) {
      return _recorder!.onAmplitudeChanged(const Duration(milliseconds: 500));
    }
    return null;
  }

  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;

  void dispose() {
    _continuousTimer?.cancel();

    if (_isRecording) {
      _recorder?.stop();
    }

    _recorder?.dispose();
    _player?.dispose();

    print('🗑️ AudioService liberado');
  }
}