// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'services/enhanced_websocket_service.dart';
import 'services/audio_service.dart';
import 'services/tts_service.dart';
import 'services/dynamic_ip_detector.dart';
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
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16, height: 1.4),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
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
        textTheme: const TextTheme(
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
      themeMode: ThemeMode.system,
      home: AccessibleVoiceControlScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(1.0, 2.0),
          ),
          child: child!,
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AccessibleVoiceControlScreen extends StatefulWidget {
  const AccessibleVoiceControlScreen({super.key});

  @override
  AccessibleVoiceControlScreenState createState() => AccessibleVoiceControlScreenState();
}

class AccessibleVoiceControlScreenState extends State<AccessibleVoiceControlScreen> {
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

  // ↓ ELIMINADO: Lista estática de IPs - ahora se detecta dinámicamente
  static const int SERVER_PORT = 8000;

  @override
  void initState() {
    super.initState();
    _setupWebSocketCallbacks();
    _initializeServices();
    _autoDiscoverAndConnect(); // ← Ahora usa detección automática

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        'Aplicación de control de voz para robot iniciada. Detectando servidor automáticamente.',
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

      if (status['status'] == 'connected') {
        SemanticsService.announce(
          'Conectado al servidor en $_discoveredIP. Servicios de voz disponibles.',
          TextDirection.ltr,
        );
      } else if (status['status'] == 'connection_lost') {
        SemanticsService.announce(
          'Se perdió la conexión con el servidor. Detectando nueva IP automáticamente.',
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
    SemanticsService.announce(
      'Inicializando servicios de audio y voz.',
      TextDirection.ltr,
    );

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

  // ↓ MÉTODO COMPLETAMENTE REESCRITO con detección automática
  Future<void> _autoDiscoverAndConnect() async {
    setState(() {
      _isSearchingServer = true;
      _connectionStatus = 'Detectando servidor automáticamente...';
    });

    SemanticsService.announce(
      'Detectando servidor de reconocimiento de voz automáticamente. Esto puede tomar unos segundos.',
      TextDirection.ltr,
    );

    try {
      // ← NUEVO: Usar detección automática de IP
      final detectedIP = await DynamicIPDetector.detectWhisperServerIP();

      if (detectedIP != null) {
        setState(() {
          _connectionStatus = 'IP detectada: $detectedIP. Conectando...';
        });

        await _connectToServer(detectedIP);

        if (_isConnected) {
          _showAccessibleSnackBar(
              'Conectado automáticamente a $detectedIP',
              Colors.green,
              'Conexión exitosa'
          );
        }
      } else {
        setState(() {
          _connectionStatus = 'No se detectó servidor Whisper automáticamente';
        });

        _showAccessibleSnackBar(
            'No se encontró servidor Whisper. Verifique que esté ejecutándose.',
            Colors.red,
            'Servidor no encontrado'
        );

        _showAccessibleServerNotFoundDialog();
      }

    } catch (e) {
      setState(() {
        _connectionStatus = 'Error en detección automática';
      });

      _showAccessibleSnackBar(
          'Error detectando servidor: ${e.toString()}',
          Colors.red,
          'Error de detección'
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
        _connectionStatus = 'Conectado a $serverIP';
        _discoveredIP = serverIP; // ← Guarda la IP detectada
        _whisperAvailable = _webSocketService.whisperAvailable;
      });

    } catch (e) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _connectionStatus = 'Error conectando a $serverIP';
      });
      rethrow;
    }
  }

  // === MÉTODOS DE GRABACIÓN (sin cambios) ===
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

      HapticFeedback.mediumImpact();

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

  // === MÉTODOS DE COMANDOS DE TEXTO - CORREGIDO ===
  Future<void> _sendTextCommand() async {
    final command = _textController.text.trim();
    if (command.isEmpty) {
      _showAccessibleSnackBar(
          'Por favor escriba un comando antes de enviarlo',
          Colors.orange,
          'Campo vacío'
      );
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

        if (_ttsEnabled && _ttsServiceReady && _lastResponse.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _ttsService.speakSystemResponse(_lastResponse);
        }

        HapticFeedback.lightImpact();

      } else {
        _showAccessibleSnackBar(
            'Error enviando comando: ${result.error}',
            Colors.red,
            'Error de envío'
        );
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
    SemanticsService.announce(message, TextDirection.ltr);
  }

  // ↓ ACTUALIZADO: Dialog con información de detección automática
  void _showAccessibleServerNotFoundDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Semantics(
            label: 'Diálogo de error: Servidor Whisper no encontrado',
            header: true,
            child: const Row(
              children: [
                Icon(Icons.search_off,
                    color: Colors.orange,
                    semanticLabel: 'Icono de búsqueda fallida'),
                SizedBox(width: 8),
                Expanded(child: Text('Servidor Whisper No Detectado')),
              ],
            ),
          ),
          content: Semantics(
            label: 'Información sobre detección automática y solución de problemas',
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('El sistema de detección automática no encontró el servidor Whisper.'),
                  SizedBox(height: 12),
                  Text('Verificaciones realizadas:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Interfaces de red locales'),
                  Text('• IP de WSL2 (si está en Windows)'),
                  Text('• Gateway y rangos de red'),
                  Text('• IPs comunes de desarrollo'),
                  SizedBox(height: 12),
                  Text('Verifique que:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('• El servicio Whisper esté ejecutándose en puerto 8000'),
                  Text('• WSL2 esté activo (Windows)'),
                  Text('• No haya problemas de firewall'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comando para iniciar Whisper:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '1) En Windows: netsh interface portproxy add v4tov4 '
                              'listenaddress=192.168.1.4 listenport=8000 '
                              'connectaddress=172.17.192.179 connectport=8000',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '2) En WSL2: python3 ~/ros2_ws/src/tutorial_pkg/tutorial_pkg/whisper_fastapi_service.py',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8),
                  Text('Puede usar comandos de texto mientras tanto.',
                      style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          actions: [
            Semantics(
              label: 'Ver diagnóstico de red detallado',
              hint: 'Muestra información técnica de la detección de IP',
              button: true,
              child: TextButton(
                onPressed: () => _showNetworkDiagnostics(),
                child: Text('Diagnóstico'),
              ),
            ),
            Semantics(
              label: 'Reintentar detección automática',
              hint: 'Vuelve a buscar el servidor automáticamente',
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
              label: 'Cerrar diálogo',
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

  // ↓ NUEVO: Mostrar diagnóstico detallado de red
  void _showNetworkDiagnostics() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Obteniendo diagnóstico...'),
        content: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final diagnostics = await DynamicIPDetector.getNetworkDiagnostics();
      Navigator.of(context).pop(); // Cerrar loading

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Diagnóstico de Red'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('IPs Candidatas Encontradas:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (diagnostics['all_candidates'] != null)
                  ...((diagnostics['all_candidates'] as List).map((ip) =>
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('• $ip', style: TextStyle(fontSize: 12)),
                      )
                  )),
                SizedBox(height: 12),
                if (diagnostics['wsl2_ip'] != null) ...[
                  Text('WSL2 IP Detectada:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${diagnostics['wsl2_ip']}'),
                  SizedBox(height: 12),
                ],
                Text('Interfaces de Red:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (diagnostics['network_interfaces'] != null)
                  ...((diagnostics['network_interfaces'] as List).map((interface) =>
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${interface['name']}:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            ...(interface['addresses'] as List).map((addr) =>
                                Text('  ${addr['address']}',
                                    style: TextStyle(fontSize: 11))
                            ),
                          ],
                        ),
                      )
                  )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar loading
      _showAccessibleSnackBar(
          'Error obteniendo diagnóstico: $e',
          Colors.red,
          'Error'
      );
    }
  }

  void _showAccessibleSnackBar(String message, Color color, String category) {
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
            label: 'Título: Control de Voz para Robot con detección automática',
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
                  onReconnect: _autoDiscoverAndConnect, // ← Usa detección automática
                  onRefreshStatus: () => _webSocketService.requestStatus(),
                ),

                SizedBox(height: 16),

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

                _buildAccessibleTextCommandCard(),

                SizedBox(height: 16),

                if (_isConnected) _buildAccessibleQuickCommandsCard(),

                SizedBox(height: 16),

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
                      hint: 'Presione para enviar el comando al robot',
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
      label: 'Sección de comandos rápidos',
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Título: Comandos rápidos',
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
                label: 'Lista de comandos predefinidos',
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
      hint: 'Presione para enviar este comando al robot',
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
          minimumSize: Size(88, 36),
        ),
      ),
    );
  }
}