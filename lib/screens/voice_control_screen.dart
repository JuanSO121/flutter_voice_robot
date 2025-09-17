// lib/screens/voice_control_screen.dart (VERSIÓN CORREGIDA)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/enhanced_websocket_service.dart';
import '../services/whisper_service.dart';
import '../utils/network_helper.dart';
import '../widgets/voice_button.dart';
import '../widgets/status_indicator.dart';
import '../widgets/ai_response_card.dart';
import '../models/voice_command.dart';

class VoiceControlScreen extends StatefulWidget {
  @override
  _VoiceControlScreenState createState() => _VoiceControlScreenState();
}

class _VoiceControlScreenState extends State<VoiceControlScreen> {
  final AudioService _audioService = AudioService();
  final EnhancedWebSocketService _wsService = EnhancedWebSocketService();

  bool _isRecording = false;
  bool _alwaysListening = false;
  bool _isProcessing = false;
  bool _servicesConnected = false;
  bool _isInitializing = true;
  bool _isProcessingAudio = false;

  String _lastTranscription = '';
  String _lastAIResponse = '';
  String _connectionStatus = 'Buscando servidor...';
  String? _serverIP;

  Map<String, bool> _serviceStatus = {
    'whisper': false,
    'ai': false,
    'ros2': false,
  };

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isInitializing = true;
      _connectionStatus = 'Inicializando servicios...';
    });

    try {
      // 1. Ejecutar diagnóstico de red
      setState(() => _connectionStatus = 'Buscando servidor...');
      final diagnostic = await NetworkHelper.runDiagnostics();

      if (!diagnostic['internet']) {
        throw Exception('Sin conexión a internet');
      }

      if (!diagnostic['server_found']) {
        throw Exception(
            'Servidor no encontrado. Verifica que WSL2 esté ejecutándose.');
      }

      _serverIP = diagnostic['server_ip'];

      // 2. Inicializar AudioService
      setState(() => _connectionStatus = 'Configurando micrófono...');
      await _audioService.initialize();

      // 3. Conectar WebSocket con la IP encontrada
      setState(() => _connectionStatus = 'Conectando al servidor...');
      await _wsService.connect(_serverIP!, 8000);

      // 4. Configurar listeners
      _setupWebSocketListeners();

      // 5. Solicitar estado inicial
      _wsService.requestStatus();

      setState(() {
        _servicesConnected = true;
        _connectionStatus = 'Conectado a $_serverIP';
        _isInitializing = false;
      });

      _showSuccessMessage('✅ Conectado correctamente al servidor');

    } catch (e) {
      print('❌ Error inicializando servicios: $e');
      setState(() {
        _connectionStatus = 'Error: ${e.toString()}';
        _servicesConnected = false;
        _isInitializing = false;
      });
      _showErrorDialog(e.toString());
    }
  }

  void _setupWebSocketListeners() {
    _wsService.onConnectionStatus = (Map<String, dynamic> status) {
      setState(() {
        _serviceStatus = Map<String, bool>.from(status['services'] ?? {});
        _servicesConnected = status['status'] == 'connected';
        if (_servicesConnected) {
          _connectionStatus = 'Servicios activos';
        }
      });
    };

    _wsService.onCommandResult = (VoiceCommandResult result) {
      setState(() {
        _isProcessing = false;
        _isProcessingAudio = false;
        _lastTranscription = result.transcription ?? '';
        _lastAIResponse = result.aiResponse ?? '';
      });

      if (result.success) {
        HapticFeedback.lightImpact();
        _showSuccessMessage('Comando procesado exitosamente');
      } else {
        HapticFeedback.vibrate();
        _showError(
            'Error procesando comando: ${result.error ?? 'Error desconocido'}');
      }
    };

    _wsService.onRobotStatus = (Map<String, dynamic> status) {
      print('🤖 Estado del robot: ${status['feedback']}');
    };

    // NUEVO: Callback para transcripciones
    _wsService.onTranscriptionResult = (result) {
      setState(() {
        if (result.success && result.transcription != null) {
          _lastTranscription = result.transcription!;
          _isProcessingAudio = false;
        }
      });
        };

  }

  @override
  void dispose() {
    _audioService.dispose();
    _wsService.disconnect();
    super.dispose();
  }

  // === MÉTODOS DE GRABACIÓN ===

  Future<void> _startRecording() async {
    if (_isProcessing || !_servicesConnected) return;

    try {
      await _audioService.startRecording();
      setState(() {
        _isRecording = true;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      _showError('Error iniciando grabación: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _isProcessingAudio = true;
      });

      final audioPath = await _audioService.stopRecording();

      if (audioPath != null) {
        await _processAudioFile(audioPath);
      } else {
        setState(() {
          _isProcessing = false;
          _isProcessingAudio = false;
        });
        _showError('No se pudo obtener la grabación');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isProcessingAudio = false;
      });
      _showError('Error procesando audio: $e');
    }
  }

  // NUEVO: Método mejorado para procesar audio
  Future<void> _processAudioFile(String audioPath) async {
    if (!_servicesConnected) {
      _showError('No conectado al servidor');
      return;
    }

    try {
      _showSuccessMessage('Procesando audio...');

      final result = await _wsService.processAudioCommand(audioPath);

      setState(() {
        _lastAIResponse = result.aiResponse ?? 'Sin respuesta del servidor';
        _lastTranscription = result.transcription ?? '';
        _isProcessing = false;
        _isProcessingAudio = false;
      });

      if (result.success) {
        _showSuccessMessage('✅ Audio procesado correctamente');
      } else {
        _showError('Error: ${result.error ?? 'Error desconocido'}');
      }

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isProcessingAudio = false;
        _lastAIResponse = 'Error procesando audio: $e';
      });
      _showError('Error: $e');
    }
  }

  void _toggleAlwaysListening() {
    if (!_servicesConnected) {
      _showError('Conecta al servidor primero');
      return;
    }

    setState(() {
      _alwaysListening = !_alwaysListening;
    });

    if (_alwaysListening) {
      _audioService.enableContinuousListening(_onContinuousAudio);
      _showSuccessMessage('Escucha continua activada');
    } else {
      _audioService.disableContinuousListening();
      _showSuccessMessage('Escucha continua desactivada');
    }
  }

  void _onContinuousAudio(String audioPath) {
    if (!_isProcessing && _servicesConnected) {
      _processAudioFile(audioPath);
    }
  }

  // === MÉTODOS DE UI ===

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error de Conexión'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No se pudo conectar al servidor:'),
            SizedBox(height: 8),
            Text(error,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
            SizedBox(height: 16),
            Text('🔧 Posibles soluciones:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Verificar que WSL2 esté ejecutándose'),
            Text('• Ejecutar el servidor: ./start_server.sh'),
            Text('• Verificar la IP de WSL2'),
            Text('• Comprobar firewall de Windows'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _runDiagnostic();
            },
            child: Text('Diagnosticar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeServices();
            },
            child: Text('Reintentar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _runDiagnostic() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Ejecutando diagnóstico...'),
              Text('Esto puede tardar unos segundos',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    try {
      final diagnostic = await NetworkHelper.runDiagnostics();
      Navigator.of(context).pop(); // Cerrar loading

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('📋 Diagnóstico de Red'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDiagnosticItem('Internet', diagnostic['internet']),
                _buildDiagnosticItem(
                    'Servidor encontrado', diagnostic['server_found']),
                if (diagnostic['server_ip'] != null) ...[
                  Text('IP: ${diagnostic['server_ip']}',
                      style: TextStyle(fontFamily: 'monospace')),
                  SizedBox(height: 8),
                  _buildDiagnosticItem(
                      'Puerto Flask (8000)', diagnostic['flask_port']),
                  _buildDiagnosticItem('Puerto Rosbridge (9090)',
                      diagnostic['rosbridge_port']),
                ],
                SizedBox(height: 8),
                Text('Tiempo: ${diagnostic['diagnosis_time']}ms',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar'),
            ),
            if (diagnostic['server_found'])
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _initializeServices();
                },
                child: Text('Conectar'),
              ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Error ejecutando diagnóstico: $e');
    }
  }

  Widget _buildDiagnosticItem(String label, bool status) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.error,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
          SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🤖 Control de Voz'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_servicesConnected ? Icons.wifi : Icons.wifi_off),
            onPressed: _isInitializing ? null : _initializeServices,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _runDiagnostic(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isInitializing ? _buildLoadingScreen() : _buildMainInterface(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            _connectionStatus,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Configurando servicios...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInterface() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          // === INDICADORES DE ESTADO ===
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estado de Servicios',
                          style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        icon: Icon(Icons.refresh, size: 20),
                        onPressed: () => _wsService.requestStatus(),
                        tooltip: 'Actualizar estado',
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StatusIndicator(
                        label: 'Whisper',
                        isActive: _serviceStatus['whisper'] ?? false,
                      ),
                      StatusIndicator(
                        label: 'IA',
                        isActive: _serviceStatus['ai'] ?? false,
                      ),
                      StatusIndicator(
                        label: 'ROS2',
                        isActive: _serviceStatus['ros2'] ?? false,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _servicesConnected ? Icons.check_circle : Icons.error,
                        color: _servicesConnected ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _connectionStatus,
                          style: TextStyle(
                              fontSize: 14,
                              color: _servicesConnected
                                  ? Colors.green[700]
                                  : Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // === CONTROLES DE VOZ ===
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botón principal de grabación
                VoiceButton(
                  isRecording: _isRecording,
                  isProcessing: _isProcessing || _isProcessingAudio,
                  onStartRecording: _startRecording,
                  onStopRecording: _stopRecording,
                ),

                SizedBox(height: 32),

                // Toggle para escucha continua
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Escucha Continua',
                                style: Theme.of(context).textTheme.titleSmall),
                            Text('Siempre detectando comandos',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                        Switch(
                          value: _alwaysListening,
                          onChanged: _servicesConnected
                              ? (_) => _toggleAlwaysListening()
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                if (!_servicesConnected) ...[
                  SizedBox(height: 16),
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sin conexión al servidor',
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                                Text('Verifica que WSL2 esté ejecutándose',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _initializeServices,
                            child: Text('Conectar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Indicador de procesamiento de audio
                if (_isProcessingAudio) ...[
                  SizedBox(height: 16),
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Transcribiendo audio...',
                              style: TextStyle(color: Colors.blue[700])),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // === RESPUESTAS DE IA ===
          AIResponseCard(
            transcription: _lastTranscription,
            aiResponse: _lastAIResponse,
          ),
        ],
      ),
    );
  }
}