// lib/widgets/accessible_status_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class AccessibleStatusIndicator extends StatelessWidget {
  final String label;
  final bool isActive;
  final String? subtitle;
  final String? detailedDescription;

  const AccessibleStatusIndicator({
    Key? key,
    required this.label,
    required this.isActive,
    this.subtitle,
    this.detailedDescription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusText = isActive ? 'activo' : 'inactivo';
    final semanticLabel = '$label está $statusText. ${detailedDescription ?? ''}';

    return Semantics(
      label: semanticLabel,
      value: statusText,
      readOnly: true,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.green[300]! : Colors.red[300]!,
            width: 2,
          ),
          color: isActive
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador visual con texto alternativo
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? Colors.green : Colors.red,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isActive ? Icons.check : Icons.close,
                    size: 10,
                    color: Colors.white,
                    semanticLabel: isActive ? 'Activo' : 'Inactivo',
                  ),
                ),
                SizedBox(width: 6),
                // Texto del estado visible para usuarios con baja visión
                Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green[700] : Colors.red[700],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            // Etiqueta del servicio
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.green[700] : Colors.red[700],
              ),
              textAlign: TextAlign.center,
            ),
            // Subtítulo opcional
            if (subtitle != null) ...[
              SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}