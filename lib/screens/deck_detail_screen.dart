import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../providers/flashcard_provider.dart';
import 'add_card_screen.dart';
import 'study_screen.dart';

class DeckDetailScreen extends StatefulWidget {
  final Deck deck;
  const DeckDetailScreen({super.key, required this.deck});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FlashcardProvider>().loadFlashcards(widget.deck.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<FlashcardProvider>(
            builder: (context, provider, _) {
              if (provider.dueCount == 0) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(
                    '${provider.dueCount} thẻ cần ôn',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<FlashcardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.flashcards.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.credit_card_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có thẻ nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Nhấn + để thêm thẻ đầu tiên',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.flashcards.length,
            itemBuilder: (context, index) {
              return _FlashcardTile(
                card: provider.flashcards[index],
                deckId: widget.deck.id!, // ← String tự động nhờ model đã đổi
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<FlashcardProvider>(
            builder: (context, provider, _) {
              if (provider.dueCount == 0) return const SizedBox();
              return FloatingActionButton.extended(
                heroTag: 'study',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudyScreen(
                        deckId: widget.deck.id!,
                        deckName: widget.deck.name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Ôn tập'),
                backgroundColor: Colors.orange,
              );
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () async {
              final provider = context.read<FlashcardProvider>();
              final deckProvider = context.read<DeckProvider>();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCardScreen(deckId: widget.deck.id!),
                ),
              );
              if (mounted) {
                provider.loadFlashcards(widget.deck.id!);
                deckProvider.loadDecks();
              }
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _FlashcardTile extends StatefulWidget {
  final Flashcard card;
  final String deckId;
  const _FlashcardTile({required this.card, required this.deckId});

  @override
  State<_FlashcardTile> createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<_FlashcardTile> {
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    final isDue = !widget.card.nextReview.isAfter(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _isFlipped = !_isFlipped),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Leading icon
              CircleAvatar(
                backgroundColor: isDue
                    ? Colors.orange.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                child: Icon(
                  isDue ? Icons.notification_important : Icons.check,
                  color: isDue ? Colors.orange : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Content — flip khi tap
              Expanded(
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _isFlipped
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.card.front,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (widget.card.pronunciation != null &&
                          widget.card.pronunciation!.isNotEmpty)
                        Text(
                          widget.card.pronunciation!,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      Text(
                        'Nhấn để xem nghĩa',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.card.back,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.teal,
                        ),
                      ),
                      if (widget.card.example != null &&
                          widget.card.example!.isNotEmpty)
                        Text(
                          widget.card.example!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      Text(
                        'Nhấn để ẩn',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá thẻ?'),
        content: Text('Xoá "${widget.card.front}" khỏi bộ thẻ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              context.read<FlashcardProvider>().deleteFlashcard(
                widget.card.id!,
                widget.deckId,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}
