import 'package:flutter/material.dart';

import '../theme.dart';

class LootScreen extends StatelessWidget {
  const LootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text('Reality to Loot', style: pixel(24))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF1E3A39), borderRadius: BorderRadius.circular(8)),
              child: const Text('Coming soon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.teal)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 240,
          decoration: box(color: C.surface, border: C.line, radius: 18),
          child: const Center(child: PixelArt(sprite: Sprites.boots, size: 160)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: box(color: C.surface, border: C.gold, radius: 16, borderWidth: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Boots of Discipline', style: pixel(22, color: C.gold)),
              const SizedBox(height: 6),
              const Text(
                'Snap a photo of a real object and the app turns it into a pixel-art item with its own stats.',
                style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFFD6D1E2)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF3A2A27), borderRadius: BorderRadius.circular(8)),
                    child: const Text('+5 STR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.coral)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF1E3A39), borderRadius: BorderRadius.circular(8)),
                    child: const Text('+10% exercise XP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.teal)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'This preview shows what an item looks like. Photo scanning arrives in a later version.',
          style: TextStyle(fontSize: 13, color: C.muted, height: 1.5),
        ),
      ],
    );
  }
}
