import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/ticket_message.dart';
import '../providers/support_provider.dart';

class TicketChatScreen extends ConsumerStatefulWidget {
  final String ticketId;

  const TicketChatScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends ConsumerState<TicketChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage(bool isAdmin) async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _msgController.clear();
    setState(() => _sending = true);

    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.sendMessage(
        ticketId: widget.ticketId,
        senderId: user.uid,
        senderName: user.displayName,
        senderEmail: user.email ?? '',
        text: text,
        isAdmin: isAdmin,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeTicket() async {
    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.closeTicket(widget.ticketId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket closed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close ticket: $e')),
        );
      }
    }
  }

  Future<void> _reopenTicket() async {
    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.reopenTicket(widget.ticketId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket reopened')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reopen ticket: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminSyncProvider);

    // We need to get the ticket info to know its status. We listen to the
    // messages stream but also fetch the ticket doc for status.
    final messagesAsync = ref.watch(ticketMessagesProvider(widget.ticketId));

    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ticket',
                        style: AppTypography.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Admin close/reopen button
                    if (isAdmin)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: context.textSecondaryColor,
                        ),
                        color: context.cardBg,
                        onSelected: (value) {
                          if (value == 'close') _closeTicket();
                          if (value == 'reopen') _reopenTicket();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'close',
                            child: Text('Close Ticket'),
                          ),
                          const PopupMenuItem(
                            value: 'reopen',
                            child: Text('Reopen Ticket'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Messages list
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'No messages yet',
                          style: AppTypography.bodyMedium.copyWith(
                            color: context.textTertiaryColor,
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                    );

                    // Check if ticket is closed from the last state
                    // We can't easily get ticket doc in stream, so we check
                    // from the messages and admin actions. We'll use a
                    // separate approach for closed state.
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMine = msg.senderId == user?.uid;
                        final isAdminMsg = msg.isAdmin;

                        return _ChatBubble(
                          message: msg,
                          isMine: isMine && !isAdminMsg,
                          isAdminMsg: isAdminMsg,
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ),

              // Closed ticket banner + input
              _TicketInputArea(
                ticketId: widget.ticketId,
                msgController: _msgController,
                sending: _sending,
                isAdmin: isAdmin,
                onSend: () => _sendMessage(isAdmin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketInputArea extends ConsumerWidget {
  final String ticketId;
  final TextEditingController msgController;
  final bool sending;
  final bool isAdmin;
  final VoidCallback onSend;

  const _TicketInputArea({
    required this.ticketId,
    required this.msgController,
    required this.sending,
    required this.isAdmin,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(ticketId)
          .snapshots(),
      builder: (context, snapshot) {
        String status = 'open';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          if (data != null) {
            status = data['status'] ?? 'open';
          }
        }

        final isClosed = status == 'closed';

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isClosed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: context.textTertiaryColor.withValues(alpha: 0.15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: context.textTertiaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'This ticket is closed',
                      style: AppTypography.labelMedium.copyWith(
                        color: context.textTertiaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: context.borderColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msgController,
                      enabled: (!isClosed || isAdmin) && !sending,
                      style: AppTypography.bodyMedium.copyWith(
                        color: context.textPrimaryColor,
                      ),
                      decoration: InputDecoration(
                        hintText: isClosed && !isAdmin
                            ? 'Ticket is closed'
                            : (isAdmin ? 'Type a reply as admin...' : 'Type a message...'),
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: context.textTertiaryColor,
                        ),
                        filled: true,
                        fillColor: context.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isClosed && !isAdmin
                          ? context.cardBg
                          : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: isClosed && !isAdmin
                                  ? context.textTertiaryColor
                                  : Colors.white,
                              size: 20,
                            ),
                      onPressed: (isClosed && !isAdmin) || sending ? null : onSend,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final TicketMessage message;
  final bool isMine;
  final bool isAdminMsg;

  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.isAdminMsg,
  });

  String _formatTime() {
    if (message.timestamp == null) return '';
    return DateFormat('h:mm a').format(message.timestamp!);
  }

  @override
  Widget build(BuildContext context) {
    final Color bubbleColor;
    if (isAdminMsg) {
      bubbleColor = AppColors.primary.withValues(alpha: 0.25);
    } else if (isMine) {
      bubbleColor = AppColors.primary;
    } else {
      bubbleColor = context.cardBg;
    }

    return Align(
      alignment: isAdminMsg ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment:
              isAdminMsg ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            // Sender label
            if (isAdminMsg)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: AppColors.neonPurple,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Support Team',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.neonPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAdminMsg ? 4 : 16),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(),
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
