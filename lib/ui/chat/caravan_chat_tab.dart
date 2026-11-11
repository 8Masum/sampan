import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/landmarks.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/chat/sos_megaphone_modal.dart';

/// Module 2: Offline Caravan Chat & Digital Megaphone (SOS)
/// (Section 4, Module 2 of `SAMPAN_BLUEPRINT.md`).
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
        // 1. Concentric Rings Selector (Caravan Group Ring vs 1-to-1 DMs)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              bottom: BorderSide(color: scheme.outline.withAlpha(70)),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  key: const ValueKey<String>('ring-caravan-group'),
                  selected: activeDmPeer == null,
                  onSelected: (_) => controller.setActiveDmPeer(null),
                  avatar: const Icon(Icons.groups_rounded, size: 18),
                  label: const Text(
                    'Caravan Group Ring (E2EE)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
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
                      label: Text(
                        'DM: ${peer.displayName}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // 2. Offline Landmark Ping Chips + Digital Megaphone Trigger
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withAlpha(80),
            border: Border(
              bottom: BorderSide(color: scheme.outline.withAlpha(70)),
            ),
          ),
          child: Row(
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('open-sos-megaphone-btn'),
                onPressed: () => _openSosModal(context),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text(
                  'SOS Megaphone',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: OfflineLandmarks.coxsBazarAndCoastal
                        .map((OfflineLandmark landmark) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          key: ValueKey<String>('landmark-chip-${landmark.id}'),
                          visualDensity: VisualDensity.compact,
                          avatar: Text(landmark.icon),
                          label: Text(
                            landmark.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () =>
                              controller.sendLandmarkPing(landmark),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Message Stream
        Expanded(
          child: visibleMessages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      activeDmPeer == null
                          ? 'No Caravan messages yet. Send an offline message or tap a Landmark Ping chip above!'
                          : 'Start a direct encrypted 1-to-1 conversation with ${activeDmPeer.displayName}.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: visibleMessages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final MessageModel msg = visibleMessages[index];
                    final bool isMe = msg.senderId == myId ||
                        msg.senderId == 'local-user';
                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                    );
                  },
                ),
        ),

        // 4. Offline Message Composer
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(color: scheme.outline.withAlpha(80)),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('chat-message-input'),
                  controller: _messageController,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: activeDmPeer == null
                        ? 'Broadcast to Caravan (ChaCha20 E2EE)...'
                        : 'Encrypted DM to ${activeDmPeer.displayName}...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const ValueKey<String>('send-chat-message-btn'),
                onPressed: _send,
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Send offline P2P packet',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  final MessageModel message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String timeStr =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${message.timestamp.minute.toString().padLeft(2, '0')}';

    if (message.isSos) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.error, width: 2.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.warning_rounded, color: scheme.error, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'DIGITAL MEGAPHONE BROADCAST • $timeStr',
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

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? scheme.primary : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    '${message.senderName} (${message.senderRole == 'guide' ? 'Guide' : 'Traveler'})',
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isMe
                          ? scheme.primaryContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: textTheme.labelSmall?.copyWith(
                    color: isMe
                        ? scheme.onPrimary.withAlpha(200)
                        : scheme.onPrimaryContainer.withAlpha(180),
                  ),
                ),
                if (message.isEncrypted) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 12,
                    color: isMe
                        ? scheme.primaryContainer
                        : scheme.onPrimaryContainer,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message.content,
              style: textTheme.bodyMedium?.copyWith(
                color: isMe ? scheme.onPrimary : scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
