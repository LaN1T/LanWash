import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../domain/entities/note.dart';
import '../../data/datasources/remote/auth_api.dart';

class NoteApi {
  final String _baseUrl = AppConstants.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthApi().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Note>> getNotes() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/notes/'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Note.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Note>> getNotesByUser(String username) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/notes/by-user/$username'),
        headers: await _getHeaders(),
      ).timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.map((m) => Note.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<int> getUnreadNotesCount() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/notes/unread-count'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body)['count'] ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<Note?> createNote(String username, String title, String message, String category) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/notes/?username=$username'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'title': title,
          'message': message,
          'category': category,
        }),
      ).timeout(AppConstants.timeout);
      if (resp.statusCode == 200) {
        return Note.fromMap(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  Future<bool> markNoteRead(int noteId) async {
    try {
      final resp = await http.put(Uri.parse('$_baseUrl/notes/$noteId/read'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllNotesRead() async {
    try {
      final resp = await http.put(Uri.parse('$_baseUrl/notes/read-all'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNote(int noteId) async {
    try {
      final resp = await http.delete(Uri.parse('$_baseUrl/notes/$noteId'), headers: await _getHeaders())
          .timeout(AppConstants.timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
