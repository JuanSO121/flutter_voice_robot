// lib/widgets/transcription_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tts_service.dart';

class TranscriptionCard extends StatefulWidget {
  final String transcription;
  final String aiResponse;
  final double? confidence;
  final double? processingTime;
  final bool publishedToRos;
  final String? commandType;
  final bool autoSpeak; // Nueva propiedad para reproducción automática

  const TranscriptionCard({
    Key? key,
    required this.transcription,
    required this.aiResponse,
    this.confidence,
    this.processingTime,
    this.publishedToRos = false,
    this.commandType,
    this.autoSpeak = true, // Por defecto habilitado
  }) : super(key: key);

  @override
  _TranscriptionCardState createState() => _TranscriptionCardState();
}

class _TranscriptionCardState extends State<TranscriptionCard>
    with TickerProviderStateMixin {
  final TTSService _ttsService = TTSService();
  bool _isSpeaking = false;
  bool _hasAutoSpoken = false;
  late AnimationController _speakAnimationController;
  late Animation<double> _speakAnimation;

  @override
  void initState() {
    super.initState();

    // Configurar animación para botón de TTS
    _speakAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _speakAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _speakAnimationController,
      curve: Curves.easeInOut,
    ));

    // Configurar callbacks de TTS
    _setupTTSCallbacks();

    // Auto-reproducir respuesta si está habilitado
    if (widget.autoSpeak && widget.aiResponse.isNotEmpty && !_hasAutoSpoken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _speakResponse();
      });
    }
  }

  void _setupTTSCallbacks() {
    _ttsService.onSpeakStart = () {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
        _speakAnimationController.repeat(reverse: true);
      }
    };

    _ttsService.onSpeakComplete = () {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
        _speakAnimationController.stop();
        _speakAnimationController.reset();
      }
    };

    _ttsService.onSpeakError = (error) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
        _speakAnimationController.stop();
        _speakAnimationController.reset();
        _showErrorSnackbar('Error en TTS: $error');
      }
    };
  }

  @override
  void didUpdateWidget(TranscriptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-reproducir nueva respuesta si cambió
    if (widget.autoSpeak &&
        widget.aiResponse.isNotEmpty &&
        widget.aiResponse != oldWidget.aiResponse &&
        !_hasAutoSpoken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _speakResponse();
      });
    }
  }

  Future<void> _speakResponse() async {
    if (widget.aiResponse.trim().isEmpty) return;

    try {
      _hasAutoSpoken = true;
      await _ttsService.speakSystemResponse(widget.aiResponse);
    } catch (e) {
      print('Error reproduciendo respuesta: $e');
      _showErrorSnackbar('No se pudo reproducir la respuesta');
    }
  }

  Future<void> _toggleTTS() async {
    if (_isSpeaking) {
      await _ttsService.stop();
    } else {
      await _speakResponse();
    }
  }

  @override
  void dispose() {
    _speakAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con tipo de comando
            Row(
              children: [
                Icon(
                  _getCommandIcon(),
                  color: _getCommandColor(),
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getCommandTitle(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getCommandColor(),
                    ),
                  ),
                ),
                if (widget.publishedToRos)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                        SizedBox(width: 4),
                        Text(
                          'ROS2',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            SizedBox(height: 12),

            // Transcripción/Comando
            if (widget.transcription.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote, size: 16, color: Colors.blue[600]),
                        SizedBox(width: 6),
                        Text(
                          widget.commandType == 'text' ? 'Comando de Texto' : 'Transcripción',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    SelectableText(
                      widget.transcription,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[800],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
            ],

            // Respuesta de IA con botón TTS
            if (widget.aiResponse.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.smart_toy, size: 16, color: Colors.green[600]),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Respuesta del Sistema',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[600],
                            ),
                          ),
                        ),
                        // Botón TTS integrado
                        AnimatedBuilder(
                          animation: _speakAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isSpeaking ? _speakAnimation.value : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isSpeaking ? Colors.orange[100] : Colors.green[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isSpeaking ? Colors.orange[300]! : Colors.green[300]!,
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _isSpeaking ? Icons.volume_up : Icons.volume_off,
                                    size: 18,
                                    color: _isSpeaking ? Colors.orange[700] : Colors.green[700],
                                  ),
                                  tooltip: _isSpeaking ? 'Detener reproducción' : 'Reproducir respuesta',
                                  onPressed: _toggleTTS,
                                  constraints: BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.all(4),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    SelectableText(
                      widget.aiResponse,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.green[800],
                        height: 1.3,
                      ),
                    ),
                    // Indicador de reproducción activa
                    if (_isSpeaking) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.orange[700],
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Reproduciendo...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12),
            ],

            // Métricas y acciones
            Row(
              children: [
                // Métricas de confianza y tiempo
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (widget.confidence != null && widget.confidence! > 0)
                        _buildMetric(
                          icon: Icons.psychology,
                          label: 'Confianza',
                          value: '${(widget.confidence! * 100).toStringAsFixed(1)}%',
                          color: _getConfidenceColor(widget.confidence!),
                        ),
                      if (widget.processingTime != null && widget.processingTime! > 0)
                        _buildMetric(
                          icon: Icons.timer,
                          label: 'Tiempo',
                          value: '${widget.processingTime!.toStringAsFixed(2)}s',
                          color: Colors.blue[600]!,
                        ),
                      if (widget.commandType != null)
                        _buildMetric(
                          icon: Icons.category,
                          label: 'Tipo',
                          value: widget.commandType!,
                          color: Colors.purple[600]!,
                        ),
                      // Indicador TTS
                      if (widget.aiResponse.isNotEmpty)
                        _buildMetric(
                          icon: Icons.record_voice_over,
                          label: 'TTS',
                          value: _isSpeaking ? 'Activo' : 'Listo',
                          color: _isSpeaking ? Colors.orange[600]! : Colors.grey[600]!,
                        ),
                    ],
                  ),
                ),

                // Botones de acción
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.transcription.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.copy, size: 18),
                        tooltip: 'Copiar transcripción',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.transcription));
                          _showCopiedSnackbar(context, 'Transcripción copiada');
                        },
                      ),
                    if (widget.aiResponse.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.copy_all, size: 18),
                        tooltip: 'Copiar respuesta',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.aiResponse));
                          _showCopiedSnackbar(context, 'Respuesta copiada');
                        },
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCommandIcon() {
    if (widget.commandType == 'text') {
      return Icons.keyboard;
    } else if (widget.publishedToRos) {
      return Icons.mic;
    } else {
      return Icons.error_outline;
    }
  }

  Color _getCommandColor() {
    if (widget.publishedToRos) {
      return Colors.green[600]!;
    } else if (widget.transcription.isEmpty && widget.aiResponse.contains('Error')) {
      return Colors.red[600]!;
    } else {
      return Colors.blue[600]!;
    }
  }

  String _getCommandTitle() {
    if (widget.commandType == 'text') {
      return 'Comando de Texto Enviado';
    } else if (widget.publishedToRos) {
      return 'Comando de Voz Procesado';
    } else if (widget.transcription.isEmpty) {
      return 'Error de Transcripción';
    } else {
      return 'Transcripción Completada';
    }
  }

  Color _getConfidenceColor(double conf) {
    if (conf >= 0.8) return Colors.green[600]!;
    if (conf >= 0.6) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showCopiedSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}