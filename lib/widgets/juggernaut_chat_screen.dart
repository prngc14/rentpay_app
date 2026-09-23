import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import 'rentpay_backdrop.dart';

class _ChatMessage {
  // id ng Firestore document (null kung hindi naka-save, hal. greeting o error)
  final String? id;
  final String text;
  final bool isOwner;

  // True kung may larawang kasama ang message
  final bool hasImage;

  // URL ng larawan sa Firebase Storage (kung na-upload na)
  final String? imageUrl;

  const _ChatMessage({
    this.id,
    required this.text,
    required this.isOwner,
    this.hasImage = false,
    this.imageUrl,
  });
}

// -------------------------------------------------
// CHAT STORE (Firestore)
// users/{uid}/juggernaut_messages/{messageId}
// -------------------------------------------------
class _ChatStore {
  _ChatStore(this.uid);

  final String uid;

  // Ilan ang huling messages na ilo-load
  static const int _historyLimit = 100;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('juggernaut_messages');

  String newId() => _col.doc().id;

  // Live na listahan ng messages, luma -> bago
  Stream<List<_ChatMessage>> watch() {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(_historyLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      return list.reversed.toList();
    });
  }

  _ChatMessage _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _ChatMessage(
      id: doc.id,
      text: (data['text'] ?? '').toString(),
      isOwner: data['isOwner'] == true,
      hasImage: data['hasImage'] == true,
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  // Hindi nagbabato ng error. Ibinabalik ang error code kung pumalya
  // ang save (null kung maayos).
  Future<String?> save({
    String? id,
    required String text,
    required bool isOwner,
    bool hasImage = false,
  }) async {
    try {
      final doc = id == null ? _col.doc() : _col.doc(id);

      await doc.set({
        'text': text,
        'isOwner': isOwner,
        'hasImage': hasImage,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (error) {
      debugPrint('Juggernaut save error: $error');

      return error is FirebaseException ? error.code : 'unknown';
    }
  }

  // I-upload ang larawan ng resibo sa Firebase Storage at ilagay
  // ang URL sa message document. Hindi nagbabato ng error.
  Future<void> uploadAndAttachImage({
    required String messageId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final ext = mimeType == 'image/png'
          ? 'png'
          : mimeType == 'image/webp'
              ? 'webp'
              : 'jpg';

      final ref = FirebaseStorage.instance.ref(
        'juggernaut_receipts/$uid/$messageId.$ext',
      );

      await ref.putData(
        bytes,
        SettableMetadata(contentType: mimeType),
      );

      final url = await ref.getDownloadURL();

      await _col.doc(messageId).set(
        {'imageUrl': url},
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint('Juggernaut image upload error: $error');
    }
  }

  // Burahin lahat ng messages (paunti-unti, may limit ang batch)
  // kasama ang mga larawan sa Storage
  Future<void> clear() async {
    final db = FirebaseFirestore.instance;

    while (true) {
      final snap = await _col.limit(400).get();

      if (snap.docs.isEmpty) break;

      final batch = db.batch();

      for (final doc in snap.docs) {
        final url = doc.data()['imageUrl'];

        if (url is String && url.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(url).delete();
          } catch (error) {
            debugPrint('Juggernaut image delete error: $error');
          }
        }

        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }
}

class JuggernautChatScreen extends StatefulWidget {
  const JuggernautChatScreen({super.key});

  @override
  State<JuggernautChatScreen> createState() => _JuggernautChatScreenState();
}

class _JuggernautChatScreenState extends State<JuggernautChatScreen> {
  // Para sa fallback icon lang (puti ang background ng avatar sa dalawang mode)
  static const Color _navy = Color(0xFF164563);

  // Mga uri ng larawang tinatanggap ng function
  static const List<String> _allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];

  // 5 MB ang limit sa app (6 MB ang limit sa function)
  static const int _maxImageBytes = 5 * 1024 * 1024;

  // Greeting ni Juggernaut, laging nasa taas ng chat (hindi sine-save)
  static const _ChatMessage _greeting = _ChatMessage(
    text: 'Hello, I’m Juggernaut, your RentPay AI assistant. '
        'Attach a tenant’s payment receipt and I’ll screen it '
        'for signs of editing or AI generation.',
    isOwner: false,
  );

  // Cache ng mga larawang kaka-send lang, para agad makita habang
  // ina-upload pa sa Firebase Storage (mabilis din pag bumalik sa chat).
  static final Map<String, Uint8List> _imageCache = <String, Uint8List>{};
  static const int _maxCachedImages = 10;

  static void _cacheImage(String id, Uint8List bytes) {
    _imageCache[id] = bytes;

    while (_imageCache.length > _maxCachedImages) {
      _imageCache.remove(_imageCache.keys.first);
    }
  }

  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final ImagePicker _picker = ImagePicker();

  // Pansamantalang mensahe (errors, warnings). Hindi sine-save
  // at nawawala pag umalis sa screen o nag-send ulit.
  final List<_ChatMessage> _notices = [];

  bool _isLoading = false;
  String _loadingLabel = 'Juggernaut is typing...';

  // Larawang naka-attach pero hindi pa naipapadala
  Uint8List? _pendingImageBytes;
  String _pendingMimeType = 'image/jpeg';

  late final FirebaseFunctions _functions;

  _ChatStore? _store;
  Stream<List<_ChatMessage>>? _messagesStream;

  int _lastItemCount = 0;
  bool _initialScrollDone = false;
  bool _saveErrorShown = false;

  @override
  void initState() {
    super.initState();

    _functions = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    );

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _store = _ChatStore(user.uid);
      _messagesStream = _store!.watch();
    }
  }

  Widget _buildJuggernautAvatar(double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        padding: EdgeInsets.all(size * 0.06),
        child: Image.asset('assets/images/juggernaut_logo.png',
            fit: BoxFit.contain),
      ),
    );
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final target = _scrollController.position.maxScrollExtent;

      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Auto-scroll pababa tuwing may bagong message
  void _autoScroll(int itemCount, bool hasData) {
    if (itemCount == _lastItemCount) return;

    _lastItemCount = itemCount;

    // Unang load ng history: diretso sa baba, walang animation
    final jump = hasData && !_initialScrollDone;

    if (hasData) _initialScrollDone = true;

    _scrollToBottom(jump: jump);
  }

  // Pansamantalang mensahe mula kay Juggernaut (hindi sine-save)
  void _addNotice(String text) {
    if (!mounted) return;

    setState(() {
      _notices.add(
        _ChatMessage(
          text: text,
          isOwner: false,
        ),
      );
    });
  }

  // Kung pumalya ang pag-save sa Firestore, ipakita sa chat kung bakit
  // (hal. permission-denied = kulang ang Firestore rules)
  void _persist(Future<String?> saving) {
    unawaited(
      saving.then((errorCode) {
        if (errorCode == null || _saveErrorShown) return;

        _saveErrorShown = true;

        _addNotice(
          'Your chat could not be saved ($errorCode), so it may '
          'not be here the next time you open Juggernaut.',
        );
      }),
    );
  }

  String _errorCode(Object? error) {
    return error is FirebaseException ? error.code : 'unknown';
  }

  // -------------------------------------------------
  // IMAGE PICKER
  // -------------------------------------------------
  String _guessMimeType(XFile file) {
    final mime = file.mimeType;

    if (mime != null && _allowedMimeTypes.contains(mime)) {
      return mime;
    }

    final path = file.path.toLowerCase();

    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';

    return 'image/jpeg';
  }

  Future<void> _pickReceipt() async {
    if (_isLoading) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (bytes.length > _maxImageBytes) {
        _addNotice(
          'That image is too large. '
          'Please choose a smaller screenshot.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _pendingImageBytes = bytes;
        _pendingMimeType = _guessMimeType(picked);
      });
    } catch (error) {
      debugPrint('Image pick error: $error');

      _addNotice(
        'I could not open that image. Please try again.',
      );
    }
  }

  void _removePendingImage() {
    if (_isLoading) return;

    setState(() {
      _pendingImageBytes = null;
    });
  }

  // -------------------------------------------------
  // ERROR MESSAGES (walang teknikal na detalye sa chat)
  // -------------------------------------------------
  String _friendlyError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Only owner accounts can use Juggernaut.';
      case 'unauthenticated':
        return 'Your session has expired. Please log in again.';
      case 'resource-exhausted':
        return 'Juggernaut is busy right now. '
            'Please try again in a few minutes.';
      case 'invalid-argument':
        return error.message ??
            'Please check your message or image and try again.';
      default:
        return 'Sorry, Juggernaut could not process your request. '
            'Please try again.';
    }
  }

  // -------------------------------------------------
  // SEND
  // -------------------------------------------------
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final imageBytes = _pendingImageBytes;
    final mimeType = _pendingMimeType;

    if ((text.isEmpty && imageBytes == null) || _isLoading) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final store = _store;

    if (currentUser == null || store == null) {
      _addNotice(
        'Your session has expired. Please log in again.',
      );
      return;
    }

    final displayText = text.isEmpty ? 'Please check this receipt.' : text;

    final messageId = store.newId();

    if (imageBytes != null) {
      _cacheImage(messageId, imageBytes);
    }

    setState(() {
      _notices.clear();
      _pendingImageBytes = null;
      _isLoading = true;
      _loadingLabel = imageBytes != null
          ? 'Juggernaut is checking the receipt...'
          : 'Juggernaut is typing...';
    });

    _messageController.clear();

    // I-save agad ang mensahe ng owner. Lalabas ito sa chat
    // sa pamamagitan ng stream (kahit offline, may local cache).
    _persist(
      store.save(
        id: messageId,
        text: displayText,
        isOwner: true,
        hasImage: imageBytes != null,
      ),
    );

    // I-upload ang larawan sa Firebase Storage at ilagay ang URL sa
    // message. Tuloy ito kahit umalis ang owner sa screen.
    if (imageBytes != null) {
      unawaited(
        store.uploadAndAttachImage(
          messageId: messageId,
          bytes: imageBytes,
          mimeType: mimeType,
        ),
      );
    }

    try {
      final payload = <String, dynamic>{
        'message': text,
      };

      if (imageBytes != null) {
        payload['imageBase64'] = base64Encode(imageBytes);
        payload['mimeType'] = mimeType;
      }

      final callable = _functions.httpsCallable(
        'juggernautChat',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 90),
        ),
      );

      final result = await callable.call(payload);

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final reply = data['reply']?.toString() ??
          'Sorry, I could not generate a response.';

      // I-save ang sagot kahit umalis na ang owner sa screen,
      // para nandoon na pag bumalik siya.
      _persist(
        store.save(
          text: reply,
          isOwner: false,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'Juggernaut error | code: ${error.code} | '
        'message: ${error.message}',
      );

      _addNotice(_friendlyError(error));
    } catch (error) {
      debugPrint('Juggernaut generic error: $error');

      _addNotice(
        'Something went wrong. '
        'Please check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // -------------------------------------------------
  // CLEAR CHAT
  // -------------------------------------------------
  Future<void> _confirmClearChat() async {
    final store = _store;

    if (store == null || _isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        // Mas maliwanag na pula sa dark mode para mabasa
        final isDark = AppColors.of(dialogContext).isDark;

        return AlertDialog(
          title: const Text('Clear chat?'),
          content: const Text(
            'All your messages with Juggernaut will be '
            'deleted. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Clear',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFEF5350)
                      : const Color(0xFFC62828),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await store.clear();
      _imageCache.clear();

      if (!mounted) return;

      setState(() {
        _notices.clear();
      });
    } catch (error) {
      debugPrint('Juggernaut clear error: $error');

      _addNotice(
        'I could not clear the chat. Please try again.',
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -------------------------------------------------
  // VERDICT BADGE
  // -------------------------------------------------
  String? _extractVerdict(String text) {
    final match = RegExp(
      r'VERDICT:\s*([A-Z ]+)',
      caseSensitive: false,
    ).firstMatch(text);

    final value = match?.group(1)?.trim().toUpperCase();

    if (value == null || value.isEmpty) return null;

    return value;
  }

  Widget _buildVerdictBadge(String verdict) {
    final isDark = AppColors.of(context).isDark;

    final Color color;

    if (verdict.contains('FAKE')) {
      color = isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828);
    } else if (verdict.contains('SUSPICIOUS')) {
      color = isDark ? const Color(0xFFFFA726) : const Color(0xFFEF6C00);
    } else if (verdict.contains('GENUINE')) {
      color = isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
    } else {
      color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        verdict,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // -------------------------------------------------
  // MESSAGE ROW
  // -------------------------------------------------
  Widget _buildMessageRow(
    _ChatMessage message,
    double maxBubbleWidth,
  ) {
    // Mga kulay na sumusunod sa light/dark mode
    final c = AppColors.of(context);

    final isOwner = message.isOwner;

    // Verdict badge para sa sagot ng receipt check
    final verdict = isOwner ? null : _extractVerdict(message.text);

    String displayText = message.text;

    if (verdict != null) {
      displayText = displayText
          .replaceFirst(
            RegExp(
              r'VERDICT:.*\n?',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
    }

    // Larawan: galing sa cache (kung kaka-send lang)
    final id = message.id;
    final imageBytes = id == null ? null : _imageCache[id];

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        mainAxisAlignment:
            isOwner ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwner) ...[
            _buildJuggernautAvatar(34),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxBubbleWidth,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isOwner ? c.bubbleOwner : c.card,
                borderRadius: BorderRadius.circular(18),
                border: isOwner
                    ? null
                    : Border.all(
                        color: c.cardBorder,
                      ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        imageBytes,
                        width: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                  ] else if (message.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        message.imageUrl!,
                        width: 180,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;

                          return const SizedBox(
                            width: 180,
                            height: 120,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 180,
                            height: 60,
                            child: Center(
                              child: Text(
                                'Receipt image unavailable',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                  ] else if (message.hasImage) ...[
                    // Nag-a-upload pa o hindi na makuha ang larawan
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: Colors.white.withAlpha(200),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Receipt image',
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                  ],
                  if (verdict != null) ...[
                    _buildVerdictBadge(
                      verdict,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                  ],
                  Text(
                    displayText,
                    style: TextStyle(
                      color: isOwner ? Colors.white : c.text,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mga kulay na sumusunod sa light/dark mode
    final c = AppColors.of(context);

    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.72;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.appBar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.text,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildJuggernautAvatar(42),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Juggernaut',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: c.text,
                  ),
                ),
                Text(
                  'AI Receipt Slasher',
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            iconColor: c.text,
            onSelected: (value) {
              if (value == 'clear') {
                _confirmClearChat();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'clear',
                child: Text('Clear chat'),
              ),
            ],
          ),
        ],
      ),
      body: RentPayBackdrop(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<_ChatMessage>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint(
                      'Juggernaut history error: '
                      '${snapshot.error}',
                    );
                  }

                  final stored = snapshot.data ?? const <_ChatMessage>[];

                  final messages = <_ChatMessage>[
                    _greeting,
                    ...stored,
                    if (snapshot.hasError)
                      _ChatMessage(
                        text: 'I could not load your chat history '
                            '(${_errorCode(snapshot.error)}). '
                            'Please try again later.',
                        isOwner: false,
                      ),
                    ..._notices,
                  ];

                  _autoScroll(
                    messages.length,
                    snapshot.hasData,
                  );

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageRow(
                        messages[index],
                        maxBubbleWidth,
                      );
                    },
                  );
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    _buildJuggernautAvatar(28),
                    const SizedBox(width: 8),
                    Text(
                      _loadingLabel,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            if (_pendingImageBytes != null)
              Container(
                color: c.bar,
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  8,
                  0,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _pendingImageBytes!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Receipt attached. Add a note '
                        '(optional) and send.',
                        style: TextStyle(
                          color: c.text,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading ? null : _removePendingImage,
                      icon: Icon(
                        Icons.close_rounded,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              color: c.bar,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isLoading ? null : _pickReceipt,
                        icon: Icon(
                          Icons.attach_file_rounded,
                          color: c.text,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textInputAction: TextInputAction.send,
                          enabled: !_isLoading,
                          onSubmitted: (_) => _sendMessage(),
                          style: TextStyle(color: c.text),
                          decoration: InputDecoration(
                            hintText: _pendingImageBytes != null
                                ? 'Add a note (optional)...'
                                : 'Message Juggernaut...',
                            hintStyle: TextStyle(
                              color: c.textMuted,
                            ),
                            filled: true,
                            fillColor: c.inputFill,
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
                            _isLoading ? Colors.grey : c.sendButton,
                        child: IconButton(
                          onPressed: _isLoading ? null : _sendMessage,
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
