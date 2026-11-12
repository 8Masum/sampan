import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/spot_presets.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/models/spot_model.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/chat/sos_megaphone_modal.dart';
import 'package:sampan/ui/home/sheets/spots_sheet.dart';

/// Module 2: Minimalist Material Design 3 Expressive Caravan Chat & SOS.
class CaravanChatTab extends ConsumerStatefulWidget {
  const CaravanChatTab({super.key});

  @override
  ConsumerState<CaravanChatTab> createState() => _CaravanChatTabState();
}

class _CaravanChatTabState extends ConsumerState<CaravanChatTab> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await ref.read(sampanControllerProvider.notifier).sendChatMessage(text);
  }

  void _openSosModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SosMegaphoneModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String myId = state.identity?.publicKeyHex ??
        SampanController.kFallbackLocalPublicKeyHex;
    final PeerModel? activeDmPeer = state.activeDmPeer;
    final List<MessageModel> visibleMessages = activeDmPeer == null
        ? state.messages
            .where((MessageModel m) => !m.isDirectMessage)
            .toList(growable: false)
        : state.messages.where((MessageModel m) {
            return (m.senderId == myId && m.recipientId == activeDmPeer.id) ||
                (m.senderId == activeDmPeer.id && m.recipientId == myId);
          }).toList(growable: false);

    return Column(
      children: <Widget>[
        // 1. Minimal Conversation Scope Pills
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  key: const ValueKey<String>('ring-caravan-group'),
                  selected: activeDmPeer == null,
                  onSelected: (_) => controller.setActiveDmPeer(null),
                  avatar: const Icon(Icons.groups_rounded, size: 18),
                  label: const Text('Everyone'),
                ),
                const SizedBox(width: 8),
                ...state.peers.map((PeerModel peer) {
                  final bool isSelected = activeDmPeer?.id == peer.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey<String>('ring-dm-${peer.id}'),
                      selected: isSelected,
                      onSelected: (_) => controller.setActiveDmPeer(peer.id),
                      avatar: Text(peer.avatarIcon),
                      label: Text(peer.displayName.split(' ').first),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // 2. Quick SOS Pill + One-Tap Spot Check-Ins
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('open-sos-megaphone-btn'),
                onPressed: () => _openSosModal(context),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text(
                  'SOS',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SpotStrip(
                  spots: state.spots,
                  onShare: controller.shareSpot,
                ),
              ),
            ],
          ),
        ),

        // 3. Expressive Pill Message Stream (inspired by M3 Hero Chat Screen)
        Expanded(
          child: visibleMessages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      activeDmPeer == null
                          ? 'Say hi 👋 Messages hop phone to phone — no signal needed.'
                          : 'Private offline chat with ${activeDmPeer.displayName.split(' ').first}.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: visibleMessages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final MessageModel msg = visibleMessages[index];
                    final bool isMe = msg.senderId == myId ||
                        msg.senderId == 'local-user';
                    PeerModel? senderPeer;
                    for (final PeerModel p in state.peers) {
                      if (p.id == msg.senderId) {
                        senderPeer = p;
                        break;
                      }
                    }
                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      senderAvatar: senderPeer?.avatarIcon ??
                          (msg.senderRole == 'guide' ? '⛵' : '🏄'),
                      senderColorHex:
                          senderPeer?.colorHex ?? 0xFF6755EF,
                    );
                  },
                ),
        ),

        // 4. Floating Pill Composer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('chat-message-input'),
                  controller: _messageController,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: activeDmPeer == null
                        ? 'Message everyone...'
                        : 'Message ${activeDmPeer.displayName.split(' ').first}...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(SampanTheme.radiusPill),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(SampanTheme.radiusPill),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                key: const ValueKey<String>('send-chat-message-btn'),
                onPressed: _send,
                style: IconButton.styleFrom(
                  backgroundColor: SampanTheme.brandViolet,
                  foregroundColor: SampanTheme.brandLime,
                  fixedSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: 'Send',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Saved spots as one-tap check-ins, plus quick ways to add one.
class _SpotStrip extends StatelessWidget {
  const _SpotStrip({required this.spots, required this.onShare});

  final List<SpotModel> spots;
  final Future<void> Function(SpotModel spot) onShare;

  @override
  Widget build(BuildContext context) {
    const TextStyle labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          ...spots.map((SpotModel spot) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                key: ValueKey<String>('spot-chip-${spot.id}'),
                visualDensity: VisualDensity.compact,
                avatar: Text(spot.emoji),
                label: Text(spot.name, style: labelStyle),
                onPressed: () => onShare(spot),
              ),
            );
          }),
          if (spots.isEmpty)
            for (int i = 0; i < SpotPresets.examples.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  key: ValueKey<String>('spot-example-chip-$i'),
                  visualDensity: VisualDensity.compact,
                  avatar: Text(SpotPresets.examples[i].emoji),
                  label: Text(SpotPresets.examples[i].name, style: labelStyle),
                  onPressed: () => showSpotEditorSheet(
                    context,
                    preset: SpotPresets.examples[i],
                  ),
                ),
              ),
          ActionChip(
            key: const ValueKey<String>('add-spot-chip'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Spot', style: labelStyle),
            onPressed: () => showSpotEditorSheet(context),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.senderAvatar,
    required this.senderColorHex,
  });

  final MessageModel message;
  final bool isMe;
  final String senderAvatar;
  final int senderColorHex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String timeStr =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${message.timestamp.minute.toString().padLeft(2, '0')}';

    if (message.isSos) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.warning_rounded, color: scheme.error, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SOS · ${message.senderName} · $timeStr',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.content,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isMe) ...<Widget>[
            CircleAvatar(
              radius: 15,
              backgroundColor: Color(senderColorHex),
              child: Text(
                senderAvatar,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  child: Text(
                    '${isMe ? 'You' : message.senderName.split(' ').first} · $timeStr',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 310),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? SampanTheme.brandViolet
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 24 : 8),
                      topRight: Radius.circular(isMe ? 8 : 24),
                      bottomLeft: const Radius.circular(24),
                      bottomRight: const Radius.circular(24),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: textTheme.bodyMedium?.copyWith(
                      color: isMe ? Colors.white : scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
