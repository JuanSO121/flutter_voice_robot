// lib/widgets/accessible_connection_status_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'accessible_status_indicator.dart';

class AccessibleConnectionStatusCard extends StatelessWidget {
  final bool isConnected;
  final String connectionStatus;
  final String? serverIP;
  final bool isSearching;
  final bool isConnecting;
  final Map<String, bool> serviceStatus;
  final VoidCallback? onReconnect;
  final VoidCallback? onRefreshStatus;

  const AccessibleConnectionStatusCard({
    Key? key,
    required this.isConnected,
    required this.connectionStatus,
    this.serverIP,
    required this.isSearching,
    required this.isConnecting,
    required this.serviceStatus,
    this.onReconnect,
    this.onRefreshStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusDescription = _getDetailedStatusDescription();

    return Semantics(
      label: 'Tarjeta de estado de conexión',
      child: Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con semántica mejorada
              Semantics(
                label: 'Título de sección: Estado de Conexión',
                header: true,
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      color: isConnected ? Colors.green : Colors.red,
                      semanticLabel: isConnected
                          ? 'Icono de conectado'
                          : 'Icono de desconectado',
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estado de Conexión',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                    if (onRefreshStatus != null)
                      Semantics(
                        label: 'Actualizar estado de conexión',
                        hint: 'Presione para verificar el estado actual de todos los servicios',
                        button: true,
                        child: IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: onRefreshStatus,
                          tooltip: 'Actualizar estado',
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 8),

              // Información del servidor
              Semantics(
                label: serverIP != null
                    ? 'Servidor conectado: $serverIP puerto 8000'
                    : 'Buscando servidor',
                readOnly: true,
                child: Text(
                  serverIP != null
                      ? 'Servidor: $serverIP:8000'
                      : 'Servidor: Buscando...',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),

              SizedBox(height: 4),

              // Estado de conexión con descripción detallada
              Semantics(
                label: 'Estado de conexión: $statusDescription',
                readOnly: true,
                child: Text(
                  'Estado: $connectionStatus',
                  style: TextStyle(
                    color: isConnected
                        ? Colors.green
                        : (isSearching || isConnecting)
                        ? Colors.orange
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Indicadores de servicios con mejor accesibilidad
              SizedBox(height: 12),
              Semantics(
                label: 'Estado de servicios del sistema',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Servicios:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        AccessibleStatusIndicator(
                          label: 'Whisper',
                          isActive: serviceStatus['whisper'] ?? false,
                          detailedDescription: serviceStatus['whisper'] == true
                              ? 'Servicio de transcripción de voz funcionando correctamente'
                              : 'Servicio de transcripción de voz no disponible',
                        ),
                        AccessibleStatusIndicator(
                          label: 'Audio',
                          isActive: serviceStatus['audio'] ?? false,
                          detailedDescription: serviceStatus['audio'] == true
                              ? 'Micrófono y grabación de audio funcionando'
                              : 'Problemas con micrófono o grabación de audio',
                        ),
                        AccessibleStatusIndicator(
                          label: 'TTS',
                          isActive: serviceStatus['tts'] ?? false,
                          detailedDescription: serviceStatus['tts'] == true
                              ? 'Síntesis de voz funcionando correctamente'
                              : 'Síntesis de voz no disponible',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Indicador de progreso accesible
              if (isSearching || isConnecting) ...[
                SizedBox(height: 12),
                Semantics(
                  label: 'Progreso de conexión',
                  value: isSearching ? 'Buscando servidor' : 'Conectando',
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]
                            : Colors.grey[300],
                      ),
                      SizedBox(height: 4),
                      Text(
                        isSearching
                            ? 'Buscando servidor disponible...'
                            : 'Estableciendo conexión...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Botón de reconexión accesible
              if (!isConnected && !isConnecting && !isSearching && onReconnect != null) ...[
                SizedBox(height: 12),
                Semantics(
                  label: 'Reconectar al servidor',
                  hint: 'Presione para intentar conectar nuevamente al servidor de reconocimiento de voz',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: onReconnect,
                    icon: Icon(Icons.refresh),
                    label: Text('Reconectar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],

              // Mensaje de ayuda para usuarios con discapacidad visual
              if (!isConnected) ...[
                SizedBox(height: 8),
                Semantics(
                  label: 'Información de ayuda sobre conexión',
                  readOnly: true,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Sin conexión al servidor. Puede usar comandos de texto como alternativa mientras se restablece la conexión.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
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

  String _getDetailedStatusDescription() {
    if (isConnected) {
      final activeServices = serviceStatus.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .join(', ');
      return 'Conectado correctamente. Servicios activos: $activeServices';
    } else if (isSearching) {
      return 'Buscando servidor de reconocimiento de voz en la red';
    } else if (isConnecting) {
      return 'Estableciendo conexión con el servidor';
    } else {
      return 'Sin conexión. Verifica que el servidor esté ejecutándose';
    }
  }
}
