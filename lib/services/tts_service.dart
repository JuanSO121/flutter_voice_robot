// lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isEnabled = true;

  // Configuraciones por defecto
  double _speechRate = 0.5;
  double _volume = 0.8;
  double _pitch = 1.0;
  String _language = 'es-ES';

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isEnabled => _isEnabled;
  double get speechRate => _speechRate;
  double get volume => _volume;
  double get pitch => _pitch;
  String get language => _language;

  // Callbacks
  Function()? onSpeakStart;
  Function()? onSpeakComplete;
  Function(String)? onSpeakError;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configurar callbacks
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        onSpeakStart?.call();
        print('TTS: Iniciando reproducción');
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakComplete?.call();
        print('TTS: Reproducción completada');
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        final errorMsg = msg.toString();
        onSpeakError?.call(errorMsg);
        print('TTS Error: $errorMsg');
      });

      // Configurar idioma y parámetros iniciales
      await _setDefaultConfiguration();

      _isInitialized = true;
      print('TTS Service inicializado correctamente');

    } catch (e) {
      print('Error inicializando TTS Service: $e');
      throw Exception('No se pudo inicializar el servicio TTS: $e');
    }
  }

  Future<void> _setDefaultConfiguration() async {
    try {
      // Verificar idiomas disponibles
      final languages = await _flutterTts.getLanguages;
      print('Idiomas TTS disponibles: $languages');

      // Configurar idioma español (probar varias variantes)
      final spanishLanguages = ['es-ES', 'es-MX', 'es-US', 'es'];
      String selectedLanguage = 'en-US'; // Fallback por defecto

      for (String lang in spanishLanguages) {
        if (languages.contains(lang)) {
          selectedLanguage = lang;
          break;
        }
      }

      await _flutterTts.setLanguage(selectedLanguage);
      _language = selectedLanguage;
      print('TTS Idioma configurado: $selectedLanguage');

      // Configurar otros parámetros
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);

      // Configuraciones específicas por plataforma
      if (Platform.isAndroid) {
        await _flutterTts.setQueueMode(1); // Modo cola para Android
      } else if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
      }

    } catch (e) {
      print('Error configurando TTS: $e');
      // Continuar con configuración por defecto
    }
  }

  // Método principal para hablar texto
  Future<bool> speak(String text) async {
    if (!_isInitialized) {
      print('TTS no inicializado. Intentando inicializar...');
      await initialize();
    }

    if (!_isEnabled) {
      print('TTS está deshabilitado');
      return false;
    }

    if (text.trim().isEmpty) {
      print('TTS: Texto vacío, no se puede reproducir');
      return false;
    }

    try {
      // Detener cualquier reproducción anterior
      if (_isSpeaking) {
        await stop();
        await Future.delayed(Duration(milliseconds: 100));
      }

      // Limpiar y preparar el texto
      final cleanText = _cleanTextForTTS(text);
      print('TTS: Reproduciendo - "$cleanText"');

      final result = await _flutterTts.speak(cleanText);
      return result == 1; // 1 = éxito en flutter_tts

    } catch (e) {
      print('Error en TTS speak: $e');
      onSpeakError?.call(e.toString());
      return false;
    }
  }

  // Limpiar texto para mejorar la síntesis de voz
  String _cleanTextForTTS(String text) {
    return text
    // Reemplazar algunos patrones comunes para mejor pronunciación
        .replaceAll(RegExp(r'ROS\s*2?'), 'ros dos')
        .replaceAll(RegExp(r'AI|IA'), 'inteligencia artificial')
        .replaceAll(RegExp(r'HTTP'), 'http')
        .replaceAll(RegExp(r'API'), 'api')
        .replaceAll(RegExp(r'URL'), 'url')
        .replaceAll(RegExp(r'JSON'), 'json')
        .replaceAll(RegExp(r'WSL'), 'w s l')
        .replaceAll(RegExp(r'IP'), 'i p')
    // Limpiar caracteres especiales problemáticos
        .replaceAll(RegExp(r'[^\w\s\.,!?;:()\-]', unicode: true), '')
    // Normalizar espacios
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Detener reproducción
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      print('TTS: Reproducción detenida');
    } catch (e) {
      print('Error deteniendo TTS: $e');
    }
  }

  // Pausar reproducción
  Future<void> pause() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.pause();
      print('TTS: Reproducción pausada');
    } catch (e) {
      print('Error pausando TTS: $e');
    }
  }

  // Configuraciones de voz

  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) return;

    try {
      _speechRate = rate.clamp(0.1, 2.0);
      await _flutterTts.setSpeechRate(_speechRate);
      print('TTS: Velocidad configurada a $_speechRate');
    } catch (e) {
      print('Error configurando velocidad TTS: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    if (!_isInitialized) return;

    try {
      _volume = volume.clamp(0.0, 1.0);
      await _flutterTts.setVolume(_volume);
      print('TTS: Volumen configurado a $_volume');
    } catch (e) {
      print('Error configurando volumen TTS: $e');
    }
  }

  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) return;

    try {
      _pitch = pitch.clamp(0.5, 2.0);
      await _flutterTts.setPitch(_pitch);
      print('TTS: Tono configurado a $_pitch');
    } catch (e) {
      print('Error configurando tono TTS: $e');
    }
  }

  Future<void> setLanguage(String language) async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.setLanguage(language);
      _language = language;
      print('TTS: Idioma configurado a $language');
    } catch (e) {
      print('Error configurando idioma TTS: $e');
    }
  }

  // Habilitar/deshabilitar TTS
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled && _isSpeaking) {
      stop();
    }
    print('TTS: ${enabled ? 'Habilitado' : 'Deshabilitado'}');
  }

  // Obtener voces disponibles
  Future<List<Map<String, String>>> getAvailableVoices() async {
    if (!_isInitialized) return [];

    try {
      final voices = await _flutterTts.getVoices;
      return List<Map<String, String>>.from(voices ?? []);
    } catch (e) {
      print('Error obteniendo voces: $e');
      return [];
    }
  }

  // Obtener idiomas disponibles
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) return [];

    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages ?? []);
    } catch (e) {
      print('Error obteniendo idiomas: $e');
      return [];
    }
  }

  // Método de conveniencia para respuestas del sistema
  Future<void> speakSystemResponse(String response) async {
    if (response.trim().isEmpty) return;

    // Agregar un pequeño delay para que no se superponga con otros sonidos
    await Future.delayed(Duration(milliseconds: 300));

    final success = await speak(response);
    if (!success) {
      print('No se pudo reproducir la respuesta del sistema');
    }
  }

  // Limpiar recursos
  void dispose() {
    if (_isSpeaking) {
      stop();
    }
    print('TTS Service disposed');
  }
}