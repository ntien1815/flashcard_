import 'package:flashcard_app/screens/deck_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/deck_provider.dart';
import '../models/deck.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // Consumer tự rebuild khi DeckProvider gọi notifyListeners()
      body: Consumer<DeckProvider>(
        builder: (context, provider, _) {
          // Đang load lần đầu
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Chưa có deck nào
          if (provider.decks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có bộ thẻ nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Nhấn + để tạo bộ thẻ đầu tiên',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Có deck → hiển thị danh sách
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.decks.length,
            itemBuilder: (context, index) {
              return _DeckCard(deck: provider.decks[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDeckDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDeckDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo bộ thẻ mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Tên bộ thẻ *',
                hintText: 'VD: TOEIC Vocabulary',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                hintText: 'VD: 500 từ vựng TOEIC',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return; // Không cho tạo nếu thiếu tên

              context.read<DeckProvider>().addDeck(
                name,
                descController.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }
}

// ── Widget riêng cho mỗi deck card ──────────────────────────────
class _DeckCard extends StatelessWidget {
  final Deck deck;
  const _DeckCard({required this.deck});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(deck.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(Icons.style, color: color),
        ),
        title: Text(
          deck.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(deck.description ?? ''),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${deck.cardCount}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'thẻ',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DeckDetailScreen(deck: deck)),
          );
        },
      ),
    );
  }

  Color _parseColor(String? hex) {
    try {
      return Color(int.parse('FF${hex!.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.indigo;
    }
  }
}
