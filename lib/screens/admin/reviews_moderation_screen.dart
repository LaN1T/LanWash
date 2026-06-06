import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../services/api_service.dart';

class Review {
  final int id;
  final int userId;
  final String userName;
  final int rating;
  final String comment;
  bool isPublished;
  final String createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.isPublished,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      userId: json['userId'] as int,
      userName: json['userName'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String,
      isPublished: json['isPublished'] as bool,
      createdAt: json['createdAt'] as String,
    );
  }
}

class ReviewsModerationScreen extends StatefulWidget {
  const ReviewsModerationScreen({super.key});

  @override
  State<ReviewsModerationScreen> createState() => _ReviewsModerationScreenState();
}

class _ReviewsModerationScreenState extends State<ReviewsModerationScreen> {
  List<Review> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await ApiService.getToken();
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/reviews/admin/all'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _reviews = data.map((e) => Review.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Ошибка загрузки: ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Ошибка: $e'; _loading = false; });
    }
  }

  Future<void> _togglePublish(Review review, bool publish) async {
    try {
      final token = await ApiService.getToken();
      final res = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/reviews/admin/${review.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isPublished': publish}),
      );
      if (res.statusCode == 200) {
        setState(() => review.isPublished = publish);
      }
    } catch (e) {
      _showSnack('Ошибка: $e');
    }
  }

  Future<void> _delete(Review review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить отзыв?'),
        content: Text('Отзыв от ${review.userName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final token = await ApiService.getToken();
      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/reviews/admin/${review.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => _reviews.remove(review));
        _showSnack('Отзыв удалён');
      }
    } catch (e) {
      _showSnack('Ошибка: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Модерация отзывов')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _reviews.length,
                    itemBuilder: (context, i) {
                      final r = _reviews[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(r.userName.isNotEmpty ? r.userName[0] : '?'),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.userName, style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text('${'★' * r.rating}${'☆' * (5 - r.rating)}', style: TextStyle(color: Colors.amber)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _delete(r),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(r.comment),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text('Опубликован:'),
                                  SizedBox(width: 8),
                                  Switch(
                                    value: r.isPublished,
                                    onChanged: (v) => _togglePublish(r, v),
                                  ),
                                  const Spacer(),
                                  Text(
                                    r.createdAt.substring(0, 16).replaceAll('T', ' '),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
