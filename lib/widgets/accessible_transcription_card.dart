// lib/widgets/accessible_transcription_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

class AccessibleTranscriptionCard extends StatefulWidget {
  final String transcription;
  final String aiResponse;
  final double? confidence;
  final double? processingTime;
  final bool publishedToRos;
  final String? commandType;
  final bool autoSpeak;

  const AccessibleTranscriptionCard({
    Key? key,
    required this.transcription,
    required this.aiResponse,
    this.confidence,
    this.processingTime,
    this.publishedToRos = false,
    this.commandType,
    this.autoSpeak = true,
  }) : super(key: key);

  @override
  _AccessibleTranscriptionCardState createState() => _AccessibleTranscriptionCardState();
}

class _AccessibleTranscriptionCardState extends State<AccessibleTranscriptionCard> {
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();

    // Anunciar nueva transcripción/respuesta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.transcription.isNotEmpty || widget.aiResponse.isNotEmpty) {
        final announcement = _buildAccessibilityAnnouncement();
        SemanticsService.announce(announcement, TextDirection.ltr);
      }
    });
  }

  String _buildAccessibilityAnnouncement() {
    final parts = <String>[];

    if (widget.transcription.isNotEmpty) {
      parts.add('Su comando: ${widget.transcription}');
    }

    if (widget.aiResponse.isNotEmpty) {
      parts.add('Respuesta del robot: ${widget.aiResponse}');
    }

    if (widget.publishedToRos) {
      parts.add('Comando enviado al robot exitosamente');
    }

    return parts.join('. ');
  }

  void _copyToClipboard(String text, String description) {
    Clipboard.setData(ClipboardData(text: text));

    // Anuncio accesible para la copia
    SemanticsService.announce(
      '$description copiado al portapapeles',
      TextDirection.ltr,
    );

    // Feedback visual para usuarios con visión parcial
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('$description copiado'),
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

  @override
  Widget build(BuildContext context) {
    if (widget.transcription.isEmpty && widget.aiResponse.isEmpty) {
      return SizedBox.shrink();
    }

    final confidenceText = widget.confidence != null
        ? '${(widget.confidence! * 100).toStringAsFixed(1)}% de confianza'
        : '';

    final processingTimeText = widget.processingTime != null
        ? 'procesado en ${widget.processingTime!.toStringAsFixed(2)} segundos'
        : '';

    return Semantics(
      label: 'Tarjeta de resultado de comando de voz',
      child: Card(
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
              // Header con información semántica mejorada
              Semantics(
                label: 'Tipo de comando: ${_getCommandTitle()}',
                header: true,
                child: Row(
                  children: [
                    Icon(
                      _getCommandIcon(),
                      color: _getCommandColor(),
                      size: 20,
                      semanticLabel: _getIconSemanticLabel(),
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
                      Semantics(
                        label: 'Comando enviado a ROS2 exitosamente',
                        child: Container(
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
                                'ENVIADO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 12),

              // Transcripción/Comando con mejor accesibilidad
              if (widget.transcription.isNotEmpty) ...[
                Semantics(
                  label: 'Su comando de voz transcrito: ${widget.transcription}. $confidenceText',
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.format_quote, size: 16, color: Colors.blue[600]),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.commandType == 'text' ? 'Su Comando de Texto' : 'Su Comando de Voz',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[600],
                                ),
                              ),
                            ),
                            // Botón de copia accesible
                            Semantics(
                              label: 'Copiar comando',
                              hint: 'Presione para copiar su comando al portapapeles',
                              button: true,
                              child: IconButton(
                                icon: Icon(Icons.copy, size: 16),
                                onPressed: () => _copyToClipboard(
                                    widget.transcription,
                                    'Comando'
                                ),
                                tooltip: 'Copiar comando',
                                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
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
                        if (confidenceText.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            confidenceText,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
              ],

              // Respuesta de IA con TTS accesible
              if (widget.aiResponse.isNotEmpty) ...[
                Semantics(
                  label: 'Respuesta del robot: ${widget.aiResponse}. $processingTimeText',
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!, width: 2),
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
                                'Respuesta del Robot',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[600],
                                ),
                              ),
                            ),
                            // Botón TTS accesible
                            Semantics(
                              label: _isSpeaking ? 'Detener lectura de respuesta' : 'Leer respuesta en voz alta',
                              hint: _isSpeaking ? 'Presione para detener la lectura' : 'Presione para escuchar la respuesta',
                              button: true,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isSpeaking ? Colors.orange[100] : Colors.green[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isSpeaking ? Colors.orange[300]! : Colors.green[300]!,
                                    width: 2,
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _isSpeaking ? Icons.volume_up : Icons.volume_off,
                                    size: 18,
                                    color: _isSpeaking ? Colors.orange[700] : Colors.green[700],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isSpeaking = !_isSpeaking;
                                    });
                                    // Aquí iría la integración con TTS
                                  },
                                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            // Botón de copia accesible
                            Semantics(
                              label: 'Copiar respuesta',
                              hint: 'Presione para copiar la respuesta del robot al portapapeles',
                              button: true,
                              child: IconButton(
                                icon: Icon(Icons.copy, size: 16),
                                onPressed: () => _copyToClipboard(
                                    widget.aiResponse,
                                    'Respuesta'
                                ),
                                tooltip: 'Copiar respuesta',
                                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
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
                        if (processingTimeText.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            processingTimeText,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        // Indicador de reproducción TTS
                        if (_isSpeaking) ...[
                          SizedBox(height: 8),
                          Semantics(
                            label: 'Reproduciendo respuesta en voz alta',
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[300]!),
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
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
              ],

              // Métricas accesibles
              Semantics(
                label: 'Información técnica del comando',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (widget.confidence != null && widget.confidence! > 0)
                      _buildAccessibleMetric(
                        icon: Icons.psychology,
                        label: 'Confianza',
                        value: '${(widget.confidence! * 100).toStringAsFixed(1)}%',
                        color: _getConfidenceColor(widget.confidence!),
                        description: 'Nivel de confianza de la transcripción',
                      ),
                    if (widget.processingTime != null && widget.processingTime! > 0)
                      _buildAccessibleMetric(
                        icon: Icons.timer,
                        label: 'Tiempo',
                        value: '${widget.processingTime!.toStringAsFixed(2)}s',
                        color: Colors.blue[600]!,
                        description: 'Tiempo de procesamiento',
                      ),
                    if (widget.commandType != null)
                      _buildAccessibleMetric(
                        icon: Icons.category,
                        label: 'Tipo',
                        value: widget.commandType!,
                        color: Colors.purple[600]!,
                        description: 'Tipo de comando enviado',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessibleMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String description,
  }) {
    return Semantics(
      label: '$description: $label es $value',
      readOnly: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
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

  String _getIconSemanticLabel() {
    if (widget.commandType == 'text') {
      return 'Icono de teclado para comando de texto';
    } else if (widget.publishedToRos) {
      return 'Icono de micrófono para comando de voz';
    } else {
      return 'Icono de error';
    }
  }

  Color _getConfidenceColor(double conf) {
    if (conf >= 0.8) return Colors.green[600]!;
    if (conf >= 0.6) return Colors.orange[600]!;
    return Colors.red[600]!;
  }
}