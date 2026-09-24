import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_warning_banner.dart';
import '../../widgets/rentpay_backdrop.dart';
import '../../services/cloudinary_service.dart';

// =====================================================
// MESSAGES (Owner <-> Tenant chat, parang Messenger)
//
// Firestore:
//   chats/{ownerId}_{tenantId}
//     ownerId, tenantId, lastMessage, lastMessageAt,
//     lastSenderId, unreadOwner, unreadTenant
//   chats/{ownerId}_{tenantId}/messages/{messageId}
//     senderId, text, imageUrl, createdAt
//
// Larawan:
//   Ina-upload sa Cloudinary (uploadToCloudinary), at ang URL lang
//   ang sine-save sa Firestore (imageUrl).
//
// - Owner: listahan ng mga tenant niya -> pindutin para mag-chat
// - Tenant: direktang chat nila sa owner nila
// =====================================================

// -------------------------------------------------
// COLORS (sumusunod sa dark mode)
// -------------------------------------------------
class _Palette {
  _Palette(this.isDark);

  final bool isDark;

  static _Palette of(BuildContext context) {
    return _Palette(Theme.of(context).brightness == Brightness.dark);
  }

  Color get textPrimary =>
      isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);
  Color get textSecondary =>
      isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);
  Color get panel => isDark ? const Color(0xCC1B2124) : const Color(0xB8FFFFFF);
  Color get panelBorder =>
      isDark ? const Color(0x14FFFFFF) : const Color(0xD1FFFFFF);
  Color get mineBubble =>
      isDark ? const Color(0xFF2B5F7F) : const Color(0xFF164563);
  Color get otherBubble => isDark ? const Color(0xFF232A2E) : Colors.white;
  Color get otherBorder =>
      isDark ? const Color(0xFF2F383D) : const Color(0xFFDCEBF0);
  Color get inputFill =>
      isDark ? const Color(0xFF232A2E) : const Color(0xFFF3F6F8);
  Color get barBg => isDark ? const Color(0xEB15191B) : const Color(0xEBFFFFFF);
}

// -------------------------------------------------
// AVATAR (larawan o unang letra ng pangalan)
// -------------------------------------------------
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    this.imageUrl,
    this.radius = 22,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();

    final fallback = Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.9,
        ),
      ),
    );

    final String url = imageUrl ?? '';
    final bool hasImage = url.isNotEmpty;

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: Container(
          color: const Color(0xFF111111),
          child: hasImage
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}

// -------------------------------------------------
// EMPTY / ERROR STATE
// -------------------------------------------------
class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        title: Text(
          'Messages',
          style: TextStyle(
            color: p.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RentPayBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: p.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// MessagesScreen
// Kinikilala kung owner o tenant ang naka-login:
// - owner  -> listahan ng mga tenant
// - tenant -> chat nila sa owner nila
// =====================================================
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Messages user error: ${snapshot.error}');

          return const _EmptyMessages(
            title: 'Unable to load messages',
            subtitle: 'Please try again later.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        final role = (data['role'] ?? '').toString();

        if (role == 'owner') {
          return _OwnerMessagesList(ownerId: user.uid);
        }

        final ownerId = (data['ownerId'] ?? '').toString();

        if (ownerId.isEmpty) {
          return const _EmptyMessages(
            title: 'No owner connected yet',
            subtitle: 'Connect to your owner first to start chatting.',
          );
        }

        return _TenantChat(
          tenantId: user.uid,
          ownerId: ownerId,
        );
      },
    );
  }
}


class _TenantChat extends StatelessWidget {
  const _TenantChat({
    required this.tenantId,
    required this.ownerId,
  });

  final String tenantId;
  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};

        final name = (data['name'] ?? 'Owner').toString();
        final image = data['profileImageUrl']?.toString();

        return _ChatScreen(
          key: ValueKey('${ownerId}_$tenantId'),
          ownerId: ownerId,
          tenantId: tenantId,
          myRole: 'tenant',
          otherName: name.isEmpty ? 'Owner' : name,
          otherImageUrl: image,
          subtitle: 'Owner',
          showBack: false,
        );
      },
    );
  }
}


class _TenantEntry {
  _TenantEntry({
    required this.id,
    required this.name,
    required this.room,
    required this.imageUrl,
    required this.chat,
  });

  final String id;
  final String name;
  final String room;
  final String? imageUrl;
  final Map<String, dynamic>? chat;

  DateTime? get lastMessageAt {
    final value = chat?['lastMessageAt'];

    if (value is Timestamp) return value.toDate();

    // Bagong message na hinihintay pa ang oras mula sa server
    if (chat?['lastMessage'] != null) return DateTime.now();

    return null;
  }
}

class _OwnerMessagesList extends StatelessWidget {
  const _OwnerMessagesList({required this.ownerId});

  final String ownerId;

  String _formatListTime(DateTime date) {
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return sameDay
        ? DateFormat('h:mm a').format(date)
        : DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        title: Text(
          'Messages',
          style: TextStyle(
            color: p.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RentPayBackdrop(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'tenant')
              .where('ownerId', isEqualTo: ownerId)
              .snapshots(),
          builder: (context, tenantSnapshot) {
            if (tenantSnapshot.hasError) {
              debugPrint('Messages tenants error: ${tenantSnapshot.error}');

              return Center(
                child: Text(
                  'Unable to load tenants',
                  style: TextStyle(color: p.textSecondary),
                ),
              );
            }

            if (!tenantSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('ownerId', isEqualTo: ownerId)
                  .snapshots(),
              builder: (context, chatSnapshot) {
                if (chatSnapshot.hasError) {
                  debugPrint('Messages chats error: ${chatSnapshot.error}');
                }

                final chats = <String, Map<String, dynamic>>{};

                for (final doc in chatSnapshot.data?.docs ?? []) {
                  final data = doc.data();
                  chats[(data['tenantId'] ?? '').toString()] = data;
                }

                final tenants = tenantSnapshot.data!.docs.map((doc) {
                  final data = doc.data();

                  return _TenantEntry(
                    id: doc.id,
                    name: (data['name'] ?? 'Tenant').toString(),
                    room: (data['room'] ?? '').toString(),
                    imageUrl: data['profileImageUrl']?.toString(),
                    chat: chats[doc.id],
                  );
                }).toList();

                if (tenants.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No tenants yet. Tenants who connect to your '
                        'owner code will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.textSecondary),
                      ),
                    ),
                  );
                }

              
                tenants.sort((a, b) {
                  final aTime = a.lastMessageAt;
                  final bTime = b.lastMessageAt;

                  if (aTime != null && bTime != null) {
                    return bTime.compareTo(aTime);
                  }

                  if (aTime != null) return -1;
                  if (bTime != null) return 1;

                  return a.name.toLowerCase().compareTo(
                        b.name.toLowerCase(),
                      );
                });

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: tenants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tenant = tenants[index];
                    final chat = tenant.chat;

                    final unread = (chat?['unreadOwner'] as num?)?.toInt() ?? 0;
                    final lastMessage = chat?['lastMessage']?.toString();
                    final lastSenderId = chat?['lastSenderId']?.toString();
                    final lastAt = tenant.lastMessageAt;

                    String subtitle;

                    if (lastMessage != null && lastMessage.isNotEmpty) {
                      subtitle = lastSenderId == ownerId
                          ? 'You: $lastMessage'
                          : lastMessage;
                    } else if (tenant.room.isNotEmpty) {
                      subtitle = 'Room ${tenant.room}';
                    } else {
                      subtitle = 'Tap to start chatting';
                    }

                    return Material(
                      color: p.panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: p.panelBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _ChatScreen(
                                ownerId: ownerId,
                                tenantId: tenant.id,
                                myRole: 'owner',
                                otherName: tenant.name,
                                otherImageUrl: tenant.imageUrl,
                                subtitle: tenant.room.isNotEmpty
                                    ? 'Room ${tenant.room}'
                                    : 'Tenant',
                                showBack: true,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              _Avatar(
                                name: tenant.name,
                                imageUrl: tenant.imageUrl,
                                radius: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tenant.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: unread > 0
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: unread > 0
                                            ? p.textPrimary
                                            : p.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (lastAt != null)
                                    Text(
                                      _formatListTime(lastAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: p.textSecondary,
                                      ),
                                    ),
                                  if (unread > 0) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                        minHeight: 20,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE93636),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        unread > 99 ? '99+' : '$unread',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}


class OwnerTenantChatScreen extends StatelessWidget {
  const OwnerTenantChatScreen({
    super.key,
    required this.ownerId,
    required this.tenantId,
    required this.tenantName,
    this.tenantImageUrl,
    this.room,
  });

  final String ownerId;
  final String tenantId;
  final String tenantName;
  final String? tenantImageUrl;
  final String? room;

  @override
  Widget build(BuildContext context) {
    final String roomLabel = room ?? '';

    return _ChatScreen(
      ownerId: ownerId,
      tenantId: tenantId,
      myRole: 'owner',
      otherName: tenantName.isEmpty ? 'Tenant' : tenantName,
      otherImageUrl: tenantImageUrl,
      subtitle: roomLabel.isNotEmpty ? 'Room $roomLabel' : 'Tenant',
      showBack: true,
    );
  }
}


class _ChatScreen extends StatefulWidget {
  const _ChatScreen({
    super.key,
    required this.ownerId,
    required this.tenantId,
    required this.myRole,
    required this.otherName,
    required this.showBack,
    this.otherImageUrl,
    this.subtitle,
  });

  final String ownerId;
  final String tenantId;

  // 'owner' o 'tenant'
  final String myRole;

  final String otherName;
  final String? otherImageUrl;
  final String? subtitle;
  final bool showBack;

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  static const int _maxImageBytes = 5 * 1024 * 1024;

  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late final DocumentReference<Map<String, dynamic>> _chatRef;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _chatSub;

  // Larawang naka-attach pero hindi pa naipapadala
  Uint8List? _pendingImage;
  String? _pendingImagePath;

  bool _isSending = false;
  bool _chatReady = false;

  bool get _isOwner => widget.myRole == 'owner';

  String get _chatId => '${widget.ownerId}_${widget.tenantId}';
  String get _myId => _isOwner ? widget.ownerId : widget.tenantId;
  String get _myUnreadField => _isOwner ? 'unreadOwner' : 'unreadTenant';
  String get _otherUnreadField => _isOwner ? 'unreadTenant' : 'unreadOwner';

  @override
  void initState() {
    super.initState();

    _chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);

    _init();
  }

  Future<void> _init() async {
    // Gawin muna ang chat document bago mag-subscribe, para hindi
    // ma-deny ang unang basa ng bagong usapan.
    try {
      await _chatRef.set(
        {
          'ownerId': widget.ownerId,
          'tenantId': widget.tenantId,
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 8));

      _chatReady = true;
    } catch (error) {
      debugPrint('Chat ensure error: $error');
    }

    if (!mounted) return;

    setState(() {
      // Pinakabago muna (descending), kasi naka-reverse ang listahan
      _messagesStream = _chatRef
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots();
    });

    // Habang bukas ang chat, i-reset ang unread count ko
    _chatSub = _chatRef.snapshots().listen(
      (snap) {
        final data = snap.data();

        if (data == null) return;

        final unread = (data[_myUnreadField] as num?)?.toInt() ?? 0;

        if (unread > 0) {
          _chatRef.update({_myUnreadField: 0}).catchError((Object error) {
            debugPrint('Chat mark read error: $error');
          });
        }
      },
      onError: (Object error) {
        debugPrint('Chat listen error: $error');
      },
    );
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _controller.dispose();
    super.dispose();
  }


  Future<void> _pickImage() async {
    if (_isSending) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (!mounted) return;

      if (bytes.length > _maxImageBytes) {
        showAppWarningBanner(
          context,
          'That image is too large. Please choose a smaller one.',
        );
        return;
      }

      setState(() {
        _pendingImage = bytes;
        _pendingImagePath = picked.path;
      });
    } catch (error) {
      debugPrint('Chat image pick error: $error');

      if (!mounted) return;

      showAppWarningBanner(
        context,
        'Unable to open that image. Please try again.',
      );
    }
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Unable to load image')),
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _send() async {
    debugPrint('========== CHAT DEBUG ==========');
    debugPrint('AUTH UID: ');
    debugPrint('MY ID: ');
    debugPrint('OWNER ID: ');
    debugPrint('TENANT ID: ');
    debugPrint('CHAT ID: ');
    debugPrint('================================');
    final text = _controller.text.trim();
    final image = _pendingImage;
    final imagePath = _pendingImagePath;

    if ((text.isEmpty && image == null) || _isSending) return;

    setState(() {
      _isSending = true;
    });

    // Tiyakin munang may chat document (unang message ng bagong usapan)
    if (!_chatReady) {
      try {
        await _chatRef.set({
          'ownerId': widget.ownerId,
          'tenantId': widget.tenantId,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
        _chatReady = true;
      } catch (error) {
        debugPrint('Chat ensure error: $error');
      }
    }

    final messageRef = _chatRef.collection('messages').doc();
    String? imageUrl;

    // 1) I-upload muna ang larawan sa Cloudinary (kung mayroon)
    if (image != null && imagePath != null) {
      try {
        imageUrl = await uploadToCloudinary(File(imagePath));

        if (imageUrl == null || imageUrl.isEmpty) {
          throw Exception('Cloudinary did not return an image URL');
        }
      } catch (error) {
        debugPrint('Chat image upload error: $error');

        if (!mounted) return;

        setState(() {
          _isSending = false;
        });

        showAppWarningBanner(
          context,
          'Unable to send the image. Please check your connection '
          'and try again.',
        );
        return;
      }
    }

    // 2) I-save ang message at i-update ang buod ng usapan
    final batch = FirebaseFirestore.instance.batch();

    batch.set(messageRef, {
      'senderId': _myId,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _chatRef,
      {
        'ownerId': widget.ownerId,
        'tenantId': widget.tenantId,
        'lastMessage': text.isNotEmpty ? text : 'Photo',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': _myId,
        _otherUnreadField: FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );


    unawaited(
      batch.commit().catchError((Object error) {
        debugPrint('Chat send error: $error');

        if (mounted) {
          showAppWarningBanner(
            context,
            'Message could not be sent. Please try again.',
          );
        }
      }),
    );

    _controller.clear();

    if (!mounted) return;

    setState(() {
      _pendingImage = null;
      _pendingImagePath = null;
      _isSending = false;
    });
  }


  String _formatTime(dynamic value) {
    if (value is! Timestamp) return 'Sending...';

    final date = value.toDate();
    final now = DateTime.now();

    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return sameDay
        ? DateFormat('h:mm a').format(date)
        : DateFormat('MMM d, h:mm a').format(date);
  }

  Widget _buildBubble(
    Map<String, dynamic> data,
    bool isMine,
    _Palette p,
    double maxWidth,
  ) {
    final text = (data['text'] ?? '').toString();
    final String imageUrl = (data['imageUrl'] ?? '').toString();
    final bool hasImage = imageUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isMine ? p.mineBubble : p.otherBubble,
              borderRadius: BorderRadius.circular(18),
              border: isMine ? null : Border.all(color: p.otherBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage)
                  GestureDetector(
                    onTap: () => _openImage(imageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;

                          return SizedBox(
                            width: 200,
                            height: 140,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.textSecondary,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => SizedBox(
                          width: 200,
                          height: 60,
                          child: Center(
                            child: Text(
                              'Image unavailable',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isMine ? Colors.white70 : p.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (hasImage && text.isNotEmpty) const SizedBox(height: 8),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: TextStyle(
                      color: isMine ? Colors.white : p.textPrimary,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
            child: Text(
              _formatTime(data['createdAt']),
              style: TextStyle(
                fontSize: 10,
                color: p.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.72;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBack,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.textPrimary,
        titleSpacing: widget.showBack ? 0 : 16,
        title: Row(
          children: [
            _Avatar(
              name: widget.otherName,
              imageUrl: widget.otherImageUrl,
              radius: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: p.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: RentPayBackdrop(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('Chat messages error: ${snapshot.error}');

                    return Center(
                      child: Text(
                        'Unable to load messages',
                        style: TextStyle(color: p.textSecondary),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No messages yet. Say hello to '
                          '${widget.otherName}!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textSecondary),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final isMine = data['senderId'] == _myId;

                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _buildBubble(
                          data,
                          isMine,
                          p,
                          maxBubbleWidth,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_pendingImage != null)
              Container(
                color: p.barBg,
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _pendingImage!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Photo attached. Add a message (optional) '
                        'and send.',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSending
                          ? null
                          : () {
                              setState(() {
                                _pendingImage = null;
                                _pendingImagePath = null;
                              });
                            },
                      icon: Icon(
                        Icons.close_rounded,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              color: p.barBg,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: _isSending ? null : _pickImage,
                        icon: Icon(
                          Icons.image_outlined,
                          color: p.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_isSending,
                          minLines: 1,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(color: p.textPrimary),
                          decoration: InputDecoration(
                            hintText: _pendingImage != null
                                ? 'Add a message (optional)...'
                                : 'Message...',
                            hintStyle: TextStyle(color: p.textSecondary),
                            filled: true,
                            fillColor: p.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      CircleAvatar(
                        backgroundColor:
                            _isSending ? Colors.grey : p.mineBubble,
                        child: IconButton(
                          onPressed: _isSending ? null : _send,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
