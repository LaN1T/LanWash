import 'package:flutter/material.dart';
import '../../core/api_client.dart';

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
      final result = await ApiClient.getList('/reviews/admin/all');
      result.when(
        success: (data) {
          setState(() {
            _reviews = data.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
            _loading = false;
          });
        },
        failure: (err) {
          setState(() { _error = 'Ошибка загрузки: ${err.message}'; _loading = false; });
        },
      );
    } catch (e) {
      setState(() { _error = 'Ошибка: $e'; _loading = false; });
    }
  }

  Future<void> _togglePublish(Review review, bool publish) async {
    try {
      final result = await ApiClient.patch(
        '/reviews/admin/${review.id}',
        body: {'isPublished': publish},
      );
      result.when(
        success: (_) => setState(() => review.isPublished = publish),
        failure: (err) => _showSnack('Ошибка: ${err.message}'),
      );
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
      final result = await ApiClient.delete('/reviews/admin/${review.id}');
      result.when(
        success: (_) {
          setState(() => _reviews.remove(review));
          _showSnack('Отзыв удалён');
        },
        failure: (err) => _showSnack('Ошибка: ${err.message}'),
      );
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
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
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
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('${'★' * r.rating}${'☆' * (5 - r.rating)}', style: const TextStyle(color: Colors.amber)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _delete(r),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(r.comment),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text('Опубликован:'),
                                  const SizedBox(width: 8),
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
