// lib/widgets/accessible_enhanced_voice_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

class AccessibleEnhancedVoiceButton extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final bool whisperAvailable;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;

  const AccessibleEnhancedVoiceButton({
    Key? key,
    required this.isRecording,
    required this.isProcessing,
    required this.whisperAvailable,
    this.onStartRecording,
    this.onStopRecording,
  }) : super(key: key);

  @override
  _AccessibleEnhancedVoiceButtonState createState() => _AccessibleEnhancedVoiceButtonState();
}

class _AccessibleEnhancedVoiceButtonState extends State<AccessibleEnhancedVoiceButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(AccessibleEnhancedVoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
      // Anunciar inicio de grabación
      SemanticsService.announce(
        'Grabación iniciada. Hable ahora.',
        TextDirection.ltr,
      );
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
      // Anunciar fin de grabación
      SemanticsService.announce(
        'Grabación detenida. Procesando audio.',
        TextDirection.ltr,
      );
    }

    if (widget.isProcessing && !oldWidget.isProcessing) {
      SemanticsService.announce(
        'Transcribiendo audio con Whisper. Por favor espere.',
        TextDirection.ltr,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.whisperAvailable) {
      _showAccessibleServiceUnavailableDialog();
      return;
    }

    if (widget.isProcessing) {
      // Informar al usuario que debe esperar
      SemanticsService.announce(
        'El sistema está procesando. Por favor espere.',
        TextDirection.ltr,
      );
      return;
    }

    // Feedback háptico diferenciado
    if (widget.isRecording) {
      HapticFeedback.lightImpact();
      widget.onStopRecording?.call();
    } else {
      HapticFeedback.mediumImpact();
      widget.onStartRecording?.call();
    }
  }

  void _showAccessibleServiceUnavailableDialog() {
    // Anuncio inmediato para lectores de pantalla
    SemanticsService.announce(
      'Servicio de voz no disponible. Abriendo información de diagnóstico.',
      TextDirection.ltr,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Semantics(
            label: 'Alerta: Servicio No Disponible',
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    color: Colors.orange,
                    semanticLabel: 'Icono de advertencia'),
                SizedBox(width: 8),
                Expanded(child: Text('Servicio No Disponible')),
              ],
            ),
          ),
          content: Semantics(
            label: 'El servicio de transcripción Whisper no está disponible. '
                'Posibles causas: Servidor FastAPI no ejecutándose, '
                'Modelo Whisper no cargado, o problemas de conectividad. '
                'Puede usar comandos de texto mientras tanto.',
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('El servicio de transcripción Whisper no está disponible.'),
                  SizedBox(height: 12),
                  Text('Posibles causas:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('• Servidor FastAPI no está ejecutándose'),
                  Text('• Modelo Whisper no está cargado'),
                  Text('• Problemas de conectividad'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Puede usar comandos de texto mientras tanto',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Semantics(
              label: 'Cerrar diálogo',
              hint: 'Presione para cerrar esta ventana',
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

  // Métodos para obtener información semántica
  String _getSemanticLabel() {
    if (!widget.whisperAvailable) {
      return 'Botón de comando de voz deshabilitado. El servicio Whisper no está disponible.';
    } else if (widget.isProcessing) {
      return 'Procesando comando de voz. El sistema está transcribiendo su audio.';
    } else if (widget.isRecording) {
      return 'Grabando comando de voz. Presione para detener la grabación.';
    } else {
      return 'Botón de comando de voz. Presione para iniciar grabación.';
    }
  }

  String _getSemanticHint() {
    if (!widget.whisperAvailable) {
      return 'Presione para ver información sobre por qué el servicio no está disponible';
    } else if (widget.isProcessing) {
      return 'Por favor espere mientras se procesa su comando';
    } else if (widget.isRecording) {
      return 'Hable ahora y presione nuevamente cuando termine';
    } else {
      return 'Mantenga presionado mientras habla o toque para iniciar grabación';
    }
  }

  String _getSemanticValue() {
    if (!widget.whisperAvailable) {
      return 'Deshabilitado';
    } else if (widget.isProcessing) {
      return 'Procesando';
    } else if (widget.isRecording) {
      return 'Grabando';
    } else {
      return 'Listo';
    }
  }

  Color _getButtonColor() {
    if (!widget.whisperAvailable) {
      return Colors.grey;
    } else if (widget.isProcessing) {
      return Colors.blue;
    } else if (widget.isRecording) {
      return Colors.red;
    } else {
      return Colors.green;
    }
  }

  IconData _getButtonIcon() {
    if (widget.isProcessing) {
      return Icons.hourglass_empty;
    } else if (widget.isRecording) {
      return Icons.stop;
    } else {
      return Icons.mic;
    }
  }

  String _getButtonText() {
    if (!widget.whisperAvailable) {
      return 'Servicio de Voz No Disponible';
    } else if (widget.isProcessing) {
      return 'Transcribiendo Audio...';
    } else if (widget.isRecording) {
      return 'Grabando - Presione para Detener';
    } else {
      return 'Presionar para Comando de Voz';
    }
  }

  String _getStatusText() {
    if (!widget.whisperAvailable) {
      return 'El servicio de reconocimiento de voz está deshabilitado. Use comandos de texto como alternativa.';
    } else if (widget.isProcessing) {
      return 'Procesando su comando de voz con Whisper. Este proceso puede tardar unos segundos.';
    } else if (widget.isRecording) {
      return 'Grabando su comando de voz. Hable claramente y presione el botón cuando termine.';
    } else {
      return 'Listo para recibir comandos de voz. Presione el botón y hable su comando.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _getSemanticLabel(),
      hint: _getSemanticHint(),
      value: _getSemanticValue(),
      button: true,
      enabled: widget.whisperAvailable || !widget.isProcessing,
      focusable: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón principal con semántica mejorada
          GestureDetector(
            onTap: _handleTap,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 120 * _pulseAnimation.value,
                    height: 120 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getButtonColor(),
                      boxShadow: [
                        BoxShadow(
                          color: _getButtonColor().withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: widget.isRecording ? 10 : 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _getButtonIcon(),
                      size: 48,
                      color: Colors.white,
                      semanticLabel: widget.isRecording
                          ? 'Botón de detener'
                          : widget.isProcessing
                          ? 'Procesando'
                          : 'Botón de micrófono',
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 24),

          // Texto del botón con contraste mejorado
          Semantics(
            label: 'Estado del botón: ${_getButtonText()}',
            readOnly: true,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getButtonColor(),
                  width: 2,
                ),
              ),
              child: Text(
                _getButtonText(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getButtonColor(),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          SizedBox(height: 12),

          // Descripción detallada del estado
          Semantics(
            label: 'Descripción del estado: ${_getStatusText()}',
            readOnly: true,
            child: Container(
              constraints: BoxConstraints(maxWidth: 280),
              child: Text(
                _getStatusText(),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[300]
                      : Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Indicador de progreso accesible para procesamiento
          if (widget.isProcessing) ...[
            SizedBox(height: 16),
            Semantics(
              label: 'Indicador de progreso',
              value: 'Transcribiendo audio',
              child: Container(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]
                      : Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
            SizedBox(height: 8),
            Semantics(
              label: 'Estado de transcripción: Whisper está procesando su audio',
              readOnly: true,
              child: Text(
                'Whisper está transcribiendo el audio...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // Indicadores visuales y semánticos de grabación
          if (widget.isRecording) ...[
            SizedBox(height: 16),
            Semantics(
              label: 'Indicador de grabación activa',
              value: 'Grabando',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'GRABANDO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}