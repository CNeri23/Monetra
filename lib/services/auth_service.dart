import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // Dirección de Laravel desde el emulador de Android.
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = data['token'];

        if (token == null || token.toString().isEmpty) {
          throw Exception('El servidor no devolvió un token.');
        }

        await _storage.write(
          key: 'auth_token',
          value: token.toString(),
        );

        return data;
      }

      if (response.statusCode == 422 ||
          response.statusCode == 401) {
        final errors = data['errors'];

        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;

          if (firstError is List && firstError.isNotEmpty) {
            throw Exception(firstError.first.toString());
          }
        }

        throw Exception(
          data['message'] ??
              'El correo electrónico o la contraseña son incorrectos.',
        );
      }

      throw Exception(
        data['message'] ?? 'No se pudo iniciar sesión.',
      );
    } on TimeoutException {
      throw Exception(
        'El servidor tardó demasiado en responder.',
      );
    } on FormatException {
      throw Exception(
        'El servidor devolvió una respuesta no válida.',
      );
    } on http.ClientException {
      throw Exception(
        'No se pudo conectar con el servidor de Monetra.',
      );
    }
  }

  static Future<String?> getToken() {
    return _storage.read(key: 'auth_token');
  }

  static Future<void> logout() async {
    final token = await getToken();

    try {
      if (token != null) {
        await http
            .post(
              Uri.parse('$baseUrl/auth/logout'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 15));
      }
    } finally {
      await _storage.delete(key: 'auth_token');
    }
  }
}