// lib/widgets/enhanced_voice_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EnhancedVoiceButton extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final bool whisperAvailable;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;

  const EnhancedVoiceButton({
    Key? key,
    required this.isRecording,
    required this.isProcessing,
    required this.whisperAvailable,
    this.onStartRecording,
    this.onStopRecording,
  }) : super(key: key);

  @override
  _EnhancedVoiceButtonState createState() => _EnhancedVoiceButtonState();
}

class _EnhancedVoiceButtonState extends State<EnhancedVoiceButton>
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
  void didUpdateWidget(EnhancedVoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  void _handleTap() {
    if (!widget.whisperAvailable) {
      _showServiceUnavailableDialog();
      return;
    }

    if (widget.isProcessing) {
      return; // No permitir nuevas grabaciones mientras se procesa
    }

    HapticFeedback.mediumImpact();

    if (widget.isRecording) {
      widget.onStopRecording?.call();
    } else {
      widget.onStartRecording?.call();
    }
  }

  void _showServiceUnavailableDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Servicio No Disponible'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('El servicio de transcripción Whisper no está disponible.'),
              SizedBox(height: 12),
              Text('Posibles causas:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• Servidor FastAPI no está ejecutándose'),
              Text('• Modelo Whisper no está cargado'),
              Text('• Problemas de conectividad'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Puedes usar comandos de texto mientras tanto',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Entendido'),
            ),
          ],
        );
      },
    );
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
      return 'Whisper No Disponible';
    } else if (widget.isProcessing) {
      return 'Transcribiendo...';
    } else if (widget.isRecording) {
      return 'Detener Grabación';
    } else {
      return 'Mantener para Hablar';
    }
  }

  String _getStatusText() {
    if (!widget.whisperAvailable) {
      return 'Servicio de voz deshabilitado';
    } else if (widget.isProcessing) {
      return 'Procesando audio con Whisper...';
    } else if (widget.isRecording) {
      return 'Grabando audio... Suelta para enviar';
    } else {
      return 'Presiona y mantén para grabar comando de voz';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón principal con animaciones
        GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
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
                  ),
                ),
              );
            },
          ),
        ),

        SizedBox(height: 24),

        // Texto del botón
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
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

        SizedBox(height: 12),

        // Texto de estado
        Container(
          constraints: BoxConstraints(maxWidth: 280),
          child: Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Indicador de progreso para procesamiento
        if (widget.isProcessing) ...[
          SizedBox(height: 16),
          Container(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Whisper está transcribiendo el audio...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],

        // Indicadores visuales de grabación
        if (widget.isRecording) ...[
          SizedBox(height: 16),
          Row(
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
                'REC',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}