// lib/widgets/voice_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VoiceButton extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const VoiceButton({
    Key? key,
    required this.isRecording,
    required this.isProcessing,
    required this.onStartRecording,
    required this.onStopRecording,
  }) : super(key: key);

  @override
  _VoiceButtonState createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
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
      duration: Duration(milliseconds: 100),
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
  void didUpdateWidget(VoiceButton oldWidget) {
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

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
    if (!widget.isRecording && !widget.isProcessing) {
      widget.onStartRecording();
      HapticFeedback.mediumImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
    if (widget.isRecording) {
      widget.onStopRecording();
      HapticFeedback.lightImpact();
    }
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anillo pulsante cuando está grabando
                if (widget.isRecording)
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                    ),
                  ),

                // Botón principal
                GestureDetector(
                  onTapDown: _onTapDown,
                  onTapUp: _onTapUp,
                  onTapCancel: _onTapCancel,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _getButtonGradient(),
                      boxShadow: [
                        BoxShadow(
                          color: _getButtonColor().withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _getButtonIcon(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  LinearGradient _getButtonGradient() {
    if (widget.isProcessing) {
      return LinearGradient(
        colors: [Colors.orange[400]!, Colors.orange[600]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (widget.isRecording) {
      return LinearGradient(
        colors: [Colors.red[400]!, Colors.red[600]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [Colors.blue[400]!, Colors.blue[600]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Color _getButtonColor() {
    if (widget.isProcessing) return Colors.orange;
    if (widget.isRecording) return Colors.red;
    return Colors.blue;
  }

  Widget _getButtonIcon() {
    if (widget.isProcessing) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      );
    } else if (widget.isRecording) {
      return Icon(
        Icons.stop,
        color: Colors.white,
        size: 40,
      );
    } else {
      return Icon(
        Icons.mic,
        color: Colors.white,
        size: 40,
      );
    }
  }
}