// lib/widgets/ai_response_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AIResponseCard extends StatelessWidget {
  final String transcription;
  final String aiResponse;

  const AIResponseCard({
    Key? key,
    required this.transcription,
    required this.aiResponse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transcription.isEmpty && aiResponse.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline,
                    color: Colors.blue[600], size: 20),
                SizedBox(width: 8),
                Text(
                  'Última Interacción',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                if (transcription.isNotEmpty || aiResponse.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.copy, size: 16),
                    onPressed: () => _copyToClipboard(context),
                    tooltip: 'Copiar texto',
                  ),
              ],
            ),

            Divider(height: 16),

            // Transcripción
            if (transcription.isNotEmpty) ...[
              _buildSectionHeader('Tu comando:', Icons.mic),
              SizedBox(height: 4),
              _buildTextContent(transcription, Colors.blue[50]!),
              SizedBox(height: 12),
            ],

            // Respuesta IA
            if (aiResponse.isNotEmpty) ...[
              _buildSectionHeader('Respuesta del Robot:', Icons.smart_toy),
              SizedBox(height: 4),
              _buildTextContent(aiResponse, Colors.green[50]!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildTextContent(String content, Color backgroundColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final textToCopy = [
      if (transcription.isNotEmpty) 'Comando: $transcription',
      if (aiResponse.isNotEmpty) 'Respuesta: $aiResponse',
    ].join('\n\n');

    Clipboard.setData(ClipboardData(text: textToCopy));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Texto copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
