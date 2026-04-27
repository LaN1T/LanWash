  Future<Map<String, dynamic>?> register({
    required String username,
    required String password,
    required String displayName,
    String phone = '',
    String carModel = '',
    String carNumber = '',
  }) async {
    debugPrint('DEBUG: Starting register call...');
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'displayName': displayName,
          'phone': phone,
          'carModel': carModel,
          'carNumber': carNumber,
        }),
      ).timeout(const Duration(seconds: 10));
      debugPrint('DEBUG: Status Code: ${resp.statusCode}');
      debugPrint('DEBUG: Response Body: ${resp.body}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        debugPrint('DEBUG: Decoded JSON: $data');
        await setToken(data['access_token']);
        return {'user': data['user']};
      }
      final err = jsonDecode(resp.body);
      debugPrint('DEBUG: Error Body: $err');
      return {'error': err['detail'] ?? 'Ошибка регистрации'};
    } catch (e, stackTrace) {
      debugPrint('CRITICAL ERROR: $e');
      debugPrint('STACKTRACE: $stackTrace');
      return {'error': 'Нет связи с сервером'};
    }
  }
