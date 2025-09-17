// test/test_server_connection.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const serverIP = '172.17.192.179';
  const serverPort = 8000;

  print('🧪 PROBANDO CONEXIÓN DESDE FLUTTER');
  print('==================================');
  print('Servidor: http://$serverIP:$serverPort');
  print('');

  // Test 1: Health Check
  try {
    print('1️⃣ Probando Health Check...');
    final healthResponse = await http.get(
      Uri.parse('http://$serverIP:$serverPort/health'),
      headers: {'User-Agent': 'FlutterTest/1.0'},
    ).timeout(Duration(seconds: 10));

    if (healthResponse.statusCode == 200) {
      print('✅ Health Check OK');
      final healthData = jsonDecode(healthResponse.body);
      print('   Servicios: ${healthData['services']}');
      print('   Estado: ${healthData['status']}');
    } else {
      print('❌ Health Check falló: ${healthResponse.statusCode}');
    }
  } catch (e) {
    print('❌ Error en Health Check: $e');
  }

  print('');

  // Test 2: Comando de Texto
  try {
    print('2️⃣ Probando comando de texto...');
    final textResponse = await http.post(
      Uri.parse('http://$serverIP:$serverPort/send_text_command'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'command': 'hola robot desde flutter'}),
    ).timeout(Duration(seconds: 15));

    if (textResponse.statusCode == 200) {
      print('✅ Comando de texto OK');
      final responseData = jsonDecode(textResponse.body);
      print('   Respuesta IA: ${responseData['ai_response']}');
      print('   Éxito: ${responseData['success']}');
    } else {
      print('❌ Comando falló: ${textResponse.statusCode}');
      print('   Body: ${textResponse.body}');
    }
  } catch (e) {
    print('❌ Error en comando: $e');
  }

  print('');

  // Test 3: Estado del Robot
  try {
    print('3️⃣ Probando estado del robot...');
    final statusResponse = await http.get(
      Uri.parse('http://$serverIP:$serverPort/robot_status'),
    ).timeout(Duration(seconds: 10));

    if (statusResponse.statusCode == 200) {
      print('✅ Estado del robot OK');
      final statusData = jsonDecode(statusResponse.body);
      print('   Conectado: ${statusData['connected']}');
    } else {
      print('❌ Estado falló: ${statusResponse.statusCode}');
    }
  } catch (e) {
    print('❌ Error obteniendo estado: $e');
  }

  print('');
  print('🏁 Test completado');
}