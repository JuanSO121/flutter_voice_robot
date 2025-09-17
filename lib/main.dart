// lib/main.dart - VERSIÓN CON ACCESIBILIDAD MEJORADA
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'services/enhanced_websocket_service.dart';
import 'services/audio_service.dart';
import 'services/tts_service.dart';
import 'models/voice_command.dart';
import 'widgets/accessible_enhanced_voice_button.dart';
import 'widgets/accessible_transcription_card.dart';
import 'widgets/accessible_connection_status_card.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Voz para Robot Accesible',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        // Configuración de accesibilidad mejorada
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontSize: 16, height: 1.4),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        // Colores con contraste mejorado
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ).copyWith(
          primary: Colors.blue[700],
          secondary: Colors.green[600],
          error: Colors.red[700],
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: Colors.white70),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: Colors.blue[300],
          secondary: Colors.green[400],
          error: Colors.red[400],
          surface: Colors.grey[900],
          onSurface: Colors.white,
        ),
      ),
      themeMode: ThemeMode.system, // Respeta preferencias del sistema
      home: AccessibleVoiceControlScreen(),
      // Configuraciones de accesibilidad global
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Asegurar tamaño mínimo de texto accesible
            textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(1.0, 2.0),
          ),
          child: child!,
        );
      },
      // Eliminar banner de debug para usuarios con discapacidad visual
      debugShowCheckedModeBanner: false,
    );
  }
}

class AccessibleVoiceControlScreen extends StatefulWidget {
  @override
  _AccessibleVoiceControlScreenState createState() => _AccessibleVoiceControlScreenState();
}

class _AccessibleVoiceControlScreenState extends State<AccessibleVoiceControlScreen> {
  final EnhancedWebSocketService _webSocketService = EnhancedWebSocketService();
  final AudioService _audioService = AudioService();
  final TTSService _ttsService = TTSService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();

  // Estados de conexión
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isSearchingServer = false;
  String _connectionStatus = 'Desconectado';
  String? _discoveredIP;

  // Estados de audio y transcripción
  bool _isRecording = false;
  bool _isProcessingAudio = false;
  bool _audioServiceReady = false;
  bool _whisperAvailable = false;

  // Estados de TTS
  bool _ttsServiceReady = false;
  bool _ttsEnabled = true;

  // Respuestas y transcripciones
  String _lastResponse = '';
  String _lastTranscription = '';
  double? _lastConfidence;
  double? _lastProcessingTime;

  // Lista de IPs a probar
  static const List<String> POSSIBLE_IPS = [
    '192.168.1.5',
    '172.17.192.179',
    '172.17.192.1',
    'localhost',
  ];
  static const int SERVER_PORT = 8000;

  @override
  void initState() {
    super.initState();
    _setupWebSocketCallbacks();
    _initializeServices();
    _autoDiscoverAndConnect();

    // Configurar texto alternativo para lectores de pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        'Aplicación de control de voz para robot iniciada. Conectando a servicios.',
        TextDirection.ltr,
      );
    });
  }

  void _setupWebSocketCallbacks() {
    _webSocketService.onConnectionStatus = (status) {
      setState(() {
        _connectionStatus = status['status'] ?? 'Desconocido';
        _whisperAvailable = status['whisper_available'] ?? false;
      });

      // Anunciar cambios de estado importantes
      if (status['status'] == 'connected') {
        SemanticsService.announce(
          'Conectado al servidor. Servicios de voz disponibles.',
          TextDirection.ltr,
        );
      } else if (status['status'] == 'connection_lost') {
        SemanticsService.announce(
          'Se perdió la conexión con el servidor. Reintentando conexión.',
          TextDirection.ltr,
        );
      }
    };

    _webSocketService.onCommandResult = (result) {
      setState(() {
        _lastResponse = result.aiResponse ?? 'Sin respuesta';
        if (result.transcription != null) {
          _lastTranscription = result.transcription!;
        }
      });

      // Feedback háptico para confirmación
      if (result.success) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.vibrate();
      }
    };

    _webSocketService.onTranscriptionResult = (result) {
      setState(() {
        if (result.success && result.transcription != null) {
          _lastTranscription = result.transcription!;
          _lastConfidence = result.confidence;
          _lastProcessingTime = result.processingTime;
        }
      });
    };
  }

  Future<void> _initializeServices() async {
    // Anunciar inicio de inicialización
    SemanticsService.announce(
      'Inicializando servicios de audio y voz.',
      TextDirection.ltr,
    );

    // Inicializar servicio de audio
    try {
      await _audioService.initialize();
      setState(() {
        _audioServiceReady = true;
      });
    } catch (e) {
      setState(() {
        _audioServiceReady = false;
      });
      _showAccessibleSnackBar(
          'Error inicializando micrófono: ${e.toString()}',
          Colors.red,
          'Error crítico'
      );
    }

    // Inicializar servicio TTS
    try {
      await _ttsService.initialize();
      setState(() {
        _ttsServiceReady = true;
      });
    } catch (e) {
      setState(() {
        _ttsServiceReady = false;
        _ttsEnabled = false;
      });
      _showAccessibleSnackBar(
          'Síntesis de voz no disponible: ${e.toString()}',
          Colors.orange,
          'Advertencia'
      );
    }
  }

  Future<void> _autoDiscoverAndConnect() async {
    setState(() {
      _isSearchingServer = true;
      _connectionStatus = 'Buscando servidor Whisper...';
    });

    SemanticsService.announce(
      'Buscando servidor de reconocimiento de voz en la red.',
      TextDirection.ltr,
    );

    try {
      for (String ip in POSSIBLE_IPS) {
        if (_isConnected) break;

        setState(() {
          _connectionStatus = 'Probando $ip...';
        });

        try {
          await _connectToServer(ip);
          if (_isConnected) {
            _showAccessibleSnackBar(
                'Conectado exitosamente a $ip',
                Colors.green,
                'Éxito'
            );
            break;
          }
        } catch (e) {
          print('Error conectando a $ip: $e');
        }

        await Future.delayed(Duration(milliseconds: 500));
      }

      if (!_isConnected) {
        setState(() {
          _connectionStatus = 'No se encontró servidor disponible';
        });
        _showAccessibleSnackBar(
            'No se encontró servidor Whisper. Use comandos de texto como alternativa.',
            Colors.red,
            'Error de conexión'
        );
        _showAccessibleServerNotFoundDialog();
      }

    } catch (e) {
      setState(() {
        _connectionStatus = 'Error buscando servidor';
      });
      _showAccessibleSnackBar(
          'Error en búsqueda de servidor: ${e.toString()}',
          Colors.red,
          'Error crítico'
      );
    } finally {
      setState(() {
        _isSearchingServer = false;
      });
    }
  }

  Future<void> _connectToServer(String serverIP) async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Conectando a $serverIP...';
    });

    try {
      await _webSocketService.connect(serverIP, SERVER_PORT);

      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _connectionStatus = 'Conectado';
        _discoveredIP = serverIP;
        _whisperAvailable = _webSocketService.whisperAvailable;
      });

    } catch (e) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _connectionStatus = 'Error de conexión';
      });
      throw e;
    }
  }

  // === MÉTODOS DE GRABACIÓN DE VOZ ACCESIBLES ===

  Future<void> _startRecording() async {
    if (!_audioServiceReady) {
      _showAccessibleSnackBar(
          'Servicio de audio no disponible',
          Colors.red,
          'Error'
      );
      return;
    }

    if (!_isConnected || !_whisperAvailable) {
      _showAccessibleSnackBar(
          'Whisper no disponible. Use comandos de texto como alternativa.',
          Colors.orange,
          'Servicio no disponible'
      );
      return;
    }

    try {
      await _audioService.startRecording();
      setState(() {
        _isRecording = true;
      });

      // Feedback háptico distintivo para inicio
      HapticFeedback.mediumImpact();

      // Anuncio inmediato
      SemanticsService.announce(
        'Grabación iniciada. Hable su comando ahora.',
        TextDirection.ltr,
      );

    } catch (e) {
      _showAccessibleSnackBar(
          'Error iniciando grabación: $e',
          Colors.red,
          'Error de grabación'
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final audioPath = await _audioService.stopRecording();
      setState(() {
        _isRecording = false;
      });

      // Feedback háptico distintivo para parada
      HapticFeedback.lightImpact();

      SemanticsService.announce(
        'Grabación detenida. Procesando comando con Whisper.',
        TextDirection.ltr,
      );

      if (audioPath != null) {
        await _processAudioFile(audioPath);
      } else {
        _showAccessibleSnackBar(
            'No se pudo procesar el audio grabado',
            Colors.red,
            'Error de procesamiento'
        );
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      _showAccessibleSnackBar(
          'Error deteniendo grabación: $e',
          Colors.red,
          'Error de grabación'
      );
    }
  }

  Future<void> _processAudioFile(String audioPath) async {
    if (!_isConnected || !_whisperAvailable) {
      _showAccessibleSnackBar(
          'Whisper no disponible',
          Colors.red,
          'Servicio no disponible'
      );
      return;
    }

    setState(() {
      _isProcessingAudio = true;
      _lastResponse = 'Transcribiendo con Whisper...';
      _lastTranscription = '';
      _lastConfidence = null;
      _lastProcessingTime = null;
    });

    try {
      final result = await _webSocketService.processAudioCommand(audioPath);

      setState(() {
        _lastResponse = result.aiResponse ?? 'Sin respuesta del servidor';
        _lastTranscription = result.transcription ?? '';
        _isProcessingAudio = false;
      });

      if (result.success) {
        _showAccessibleSnackBar(
            'Audio procesado exitosamente',
            Colors.green,
            'Éxito'
        );
        // TTS automático para respuesta de voz
        if (_ttsEnabled && _ttsServiceReady && _lastResponse.isNotEmpty) {
          await _ttsService.speakSystemResponse(_lastResponse);
        }
      } else {
        _showAccessibleSnackBar(
            'Error procesando audio: ${result.error}',
            Colors.red,
            'Error de procesamiento'
        );
      }

    } catch (e) {
      setState(() {
        _isProcessingAudio = false;
        _lastResponse = 'Error procesando audio: $e';
      });
      _showAccessibleSnackBar(
          'Error inesperado: $e',
          Colors.red,
          'Error crítico'
      );
    }
  }

  // === MÉTODOS DE COMANDOS DE TEXTO ACCESIBLES ===

  Future<void> _sendTextCommand() async {
    final command = _textController.text.trim();
    if (command.isEmpty) {
      _showAccessibleSnackBar(
          'Por favor escriba un comando antes de enviarlo',
          Colors.orange,
          'Campo vacío'
      );
      // Enfocar el campo de texto para facilitar corrección
      _textFieldFocusNode.requestFocus();
      return;
    }

    if (!_isConnected) {
      _showAccessibleSnackBar(
          'No hay conexión al servidor. Verifique su conexión.',
          Colors.red,
          'Sin conexión'
      );
      return;
    }

    try {
      setState(() => _lastResponse = 'Procesando comando: "$command"...');

      SemanticsService.announce(
        'Enviando comando de texto: $command',
        TextDirection.ltr,
      );

      final result = await _webSocketService.sendTextCommand(command);

      setState(() {
        _lastResponse = result.aiResponse ?? 'Sin respuesta del servidor';
        _lastTranscription = command;
      });

      _textController.clear();

      if (result.success) {
        _showAccessibleSnackBar(
            'Comando enviado exitosamente',
            Colors.green,
            'Éxito'
        );

        // TTS opcional para comandos de texto
        if (_ttsEnabled && _ttsServiceReady && _lastResponse.isNotEmpty) {
          await Future.delayed(Duration(milliseconds: 500));
          await _ttsService.speakSystemResponse(_lastResponse);
        }

        // Feedback háptico de confirmación
        HapticFeedback.lightImpact();

      } else {
        _showAccessibleSnackBar(
            'Error enviando comando: ${result.error}',
            Colors.red,
            'Error de envío'
        );
        // Reenfoque para facilitar corrección
        _textFieldFocusNode.requestFocus();
      }

    } catch (e) {
      _showAccessibleSnackBar(
          'Error de conexión: $e',
          Colors.red,
          'Error crítico'
      );
      setState(() => _lastResponse = 'Error: $e');
      _textFieldFocusNode.requestFocus();
    }
  }

  // === MÉTODOS TTS ACCESIBLES ===

  void _toggleTTS() {
    setState(() {
      _ttsEnabled = !_ttsEnabled;
    });

    final message = _ttsEnabled
        ? 'Síntesis de voz activada'
        : 'Síntesis de voz desactivada';

    _showAccessibleSnackBar(
        message,
        _ttsEnabled ? Colors.green : Colors.orange,
        'Configuración TTS'
    );

    if (!_ttsEnabled) {
      _ttsService.stop();
    }

    _ttsService.setEnabled(_ttsEnabled);

    // Anuncio inmediato del cambio
    SemanticsService.announce(message, TextDirection.ltr);
  }

  // === MÉTODOS DE UI ACCESIBLES ===

  void _showAccessibleServerNotFoundDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Semantics(
            label: 'Diálogo de error: Servidor Whisper no encontrado',
            header: true,
            child: Row(
              children: [
                Icon(Icons.search_off,
                    color: Colors.orange,
                    semanticLabel: 'Icono de búsqueda fallida'),
                SizedBox(width: 8),
                Expanded(child: Text('Servidor Whisper No Encontrado')),
              ],
            ),
          ),
          content: Semantics(
            label: 'Información detallada sobre el error de conexión y pasos para solucionarlo',
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No se pudo encontrar el servidor Whisper FastAPI en la red.'),
                  SizedBox(height: 16),
                  Text('Verifique que:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('• El servicio Whisper esté ejecutándose'),
                  Text('• WSL2 esté activo si usa Windows'),
                  Text('• El puerto 8000 esté disponible'),
                  Text('• No haya problemas de firewall'),
                  SizedBox(height: 16),
                  Text('Mientras tanto:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Puede usar comandos de texto como alternativa completa',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Semantics(
              label: 'Reintentar búsqueda del servidor',
              hint: 'Presione para buscar nuevamente el servidor Whisper',
              button: true,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _autoDiscoverAndConnect();
                },
                child: Text('Reintentar'),
              ),
            ),
            Semantics(
              label: 'Cerrar diálogo de error',
              hint: 'Presione para cerrar esta ventana de información',
              button: true,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Entendido'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAccessibleSnackBar(String message, Color color, String category) {
    // Anuncio inmediato para lectores de pantalla
    SemanticsService.announce(
      '$category: $message',
      TextDirection.ltr,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          label: '$category: $message',
          liveRegion: true,
          child: Row(
            children: [
              Icon(
                color == Colors.green ? Icons.check_circle :
                color == Colors.orange ? Icons.warning :
                Icons.error,
                color: Colors.white,
                semanticLabel: color == Colors.green ? 'Éxito' :
                color == Colors.orange ? 'Advertencia' :
                'Error',
              ),
              SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ),
        backgroundColor: color,
        duration: Duration(seconds: color == Colors.red ? 4 : 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    _audioService.dispose();
    _ttsService.dispose();
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aplicación de control de voz para robot',
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            label: 'Título de la aplicación: Control de Voz para Robot 2.0',
            header: true,
            child: Row(
              children: [
                Icon(Icons.smart_toy,
                    color: Colors.white,
                    semanticLabel: 'Icono de robot'),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voice Robot Control 2.0',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: _isConnected ? Colors.green :
          _isSearchingServer ? Colors.orange : Colors.red,
          elevation: 4,
          actions: [
            // Botón para alternar TTS con mejor accesibilidad
            Semantics(
              label: _ttsEnabled
                  ? 'Desactivar síntesis de voz'
                  : 'Activar síntesis de voz',
              hint: _ttsEnabled
                  ? 'Presione para silenciar las respuestas del robot'
                  : 'Presione para escuchar las respuestas del robot',
              button: true,
              child: IconButton(
                icon: Icon(
                  _ttsEnabled ? Icons.volume_up : Icons.volume_off,
                  color: _ttsServiceReady
                      ? (_ttsEnabled ? Colors.white : Colors.white70)
                      : Colors.grey[400],
                  semanticLabel: _ttsEnabled ? 'Sonido activado' : 'Sonido desactivado',
                ),
                onPressed: _ttsServiceReady ? _toggleTTS : null,
                tooltip: _ttsEnabled ? 'Desactivar voz' : 'Activar voz',
              ),
            ),
          ],
        ),
        body: Semantics(
          label: 'Contenido principal de la aplicación',
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // === ESTADO DE CONEXIÓN ACCESIBLE ===
                AccessibleConnectionStatusCard(
                  isConnected: _isConnected,
                  connectionStatus: _connectionStatus,
                  serverIP: _discoveredIP,
                  isSearching: _isSearchingServer,
                  isConnecting: _isConnecting,
                  serviceStatus: {
                    'whisper': _whisperAvailable,
                    'audio': _audioServiceReady,
                    'tts': _ttsServiceReady,
                  },
                  onReconnect: _autoDiscoverAndConnect,
                  onRefreshStatus: () => _webSocketService.requestStatus(),
                ),

                SizedBox(height: 16),

                // === BOTÓN DE VOZ ACCESIBLE ===
                if (_isConnected)
                  Semantics(
                    label: 'Sección de control de voz',
                    child: Center(
                      child: AccessibleEnhancedVoiceButton(
                        isRecording: _isRecording,
                        isProcessing: _isProcessingAudio,
                        whisperAvailable: _whisperAvailable && _audioServiceReady,
                        onStartRecording: _startRecording,
                        onStopRecording: _stopRecording,
                      ),
                    ),
                  ),

                SizedBox(height: 20),

                // === CAMPO DE TEXTO ACCESIBLE ===
                _buildAccessibleTextCommandCard(),

                SizedBox(height: 16),

                // === COMANDOS RÁPIDOS ACCESIBLES ===
                if (_isConnected) _buildAccessibleQuickCommandsCard(),

                SizedBox(height: 16),

                // === RESULTADO DE TRANSCRIPCIÓN ACCESIBLE ===
                if (_lastTranscription.isNotEmpty || _lastResponse.isNotEmpty)
                  AccessibleTranscriptionCard(
                    transcription: _lastTranscription,
                    aiResponse: _lastResponse,
                    confidence: _lastConfidence,
                    processingTime: _lastProcessingTime,
                    publishedToRos: true,
                    autoSpeak: _ttsEnabled && _ttsServiceReady,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessibleTextCommandCard() {
    return Semantics(
      label: 'Sección de comandos de texto',
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Título de sección: Enviar comando de texto',
                header: true,
                child: Row(
                  children: [
                    Icon(Icons.keyboard,
                        color: Colors.blue[600],
                        semanticLabel: 'Icono de teclado'),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enviar Comando de Texto',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Semantics(
                label: 'Campo de texto para escribir comandos al robot',
                textField: true,
                child: TextField(
                  controller: _textController,
                  focusNode: _textFieldFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Escriba un comando (ejemplo: "hola robot", "avanzar", "parar")',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                    ),
                    suffixIcon: Semantics(
                      label: 'Enviar comando de texto',
                      hint: 'Presione para enviar el comando escrito al robot',
                      button: true,
                      child: IconButton(
                        icon: Icon(Icons.send,
                            semanticLabel: 'Icono de enviar'),
                        onPressed: _isConnected ? _sendTextCommand : null,
                        tooltip: 'Enviar comando',
                      ),
                    ),
                  ),
                  enabled: _isConnected,
                  onSubmitted: _isConnected ? (_) => _sendTextCommand() : null,
                  textInputAction: TextInputAction.send,
                  keyboardType: TextInputType.text,
                  // Mejoras de accesibilidad para el campo de texto
                  style: TextStyle(fontSize: 16),
                  maxLines: null,
                  minLines: 1,
                ),
              ),
              if (!_isConnected) ...[
                SizedBox(height: 8),
                Semantics(
                  label: 'Información: Sin conexión al servidor',
                  child: Text(
                    'Conecte al servidor para enviar comandos',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessibleQuickCommandsCard() {
    final quickCommands = [
      'Hola robot',
      'Estado del robot',
      'Avanzar',
      'Parar',
      'Girar derecha',
      'Explorar',
    ];

    return Semantics(
      label: 'Sección de comandos rápidos predefinidos',
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Título de sección: Comandos rápidos',
                header: true,
                child: Row(
                  children: [
                    Icon(Icons.flash_on,
                        color: Colors.orange[600],
                        semanticLabel: 'Icono de comandos rápidos'),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Comandos Rápidos',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Semantics(
                label: 'Lista de ${quickCommands.length} comandos predefinidos disponibles',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickCommands.map((command) =>
                      _buildAccessibleQuickCommand(command)
                  ).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessibleQuickCommand(String command) {
    return Semantics(
      label: 'Comando rápido: $command',
      hint: 'Presione para enviar automáticamente este comando al robot',
      button: true,
      child: ElevatedButton(
        onPressed: () {
          _textController.text = command;
          _sendTextCommand();
        },
        child: Text(command),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[100],
          foregroundColor: Colors.blue[800],
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          // Tamaño mínimo para accesibilidad táctil
          minimumSize: Size(88, 36),
        ),
      ),
    );
  }
}