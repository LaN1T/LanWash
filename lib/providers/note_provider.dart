import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class NoteProvider extends ChangeNotifier {
  final ApiService _api;

  NoteProvider({required ApiService api}) : _api = api;

  List<Note> _noteList = [];
  int _unreadNotes = 0;
  String? _errorMessage;

  List<Note> get notes => _noteList;
  int get unreadNotes => _unreadNotes;
  String? get errorMessage => _errorMessage;

  void clearError() => _errorMessage = null;

  Future<void> loadNotes({String? username}) async {
    clearError();
    try {
      _noteList = username != null
          ? await _api.getNotesByUser(username)
          : await _api.getNotes();
      _unreadNotes = _noteList.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Ошибка загрузки заметок';
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount(AuthProvider auth) async {
    if (!auth.isAdmin) return;
    try {
      _unreadNotes = await _api.getUnreadNotesCount();
      notifyListeners();
    } catch (e) {}
  }

  Future<Note?> addNote(
      String username, String title, String message, String category) async {
    clearError();
    try {
      final note = await _api.createNote(username, title, message, category);
      if (note != null) {
        _noteList.insert(0, note);
        _unreadNotes = _noteList.where((n) => !n.isRead).length;
        notifyListeners();
      }
      return note;
    } catch (e) {
      _errorMessage = 'Ошибка создания заметки';
      notifyListeners();
      return null;
    }
  }

  Future<void> markNoteRead(int noteId) async {
    try {
      final ok = await _api.markNoteRead(noteId);
      if (ok) {
        final i = _noteList.indexWhere((n) => n.id == noteId);
        if (i != -1) {
          _noteList[i] = _noteList[i].copyWith(isRead: true);
          _unreadNotes = _noteList.where((n) => !n.isRead).length;
          notifyListeners();
        }
      }
    } catch (e) {}
  }

  Future<void> markAllNotesRead() async {
    try {
      final ok = await _api.markAllNotesRead();
      if (ok) {
        _noteList = _noteList.map((n) => n.copyWith(isRead: true)).toList();
        _unreadNotes = 0;
        notifyListeners();
      }
    } catch (e) {}
  }

  Future<void> deleteNote(int noteId) async {
    try {
      final ok = await _api.deleteNote(noteId);
      if (ok) {
        _noteList.removeWhere((n) => n.id == noteId);
        _unreadNotes = _noteList.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {}
  }
}
