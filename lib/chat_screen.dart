import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'services/chat_service.dart';
import 'services/push_service.dart';
import 'services/subscription_state.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String? otherDisplayName;
  final String? otherAvatarUrl;
  final String? initialMessageId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    this.otherDisplayName,
    this.otherAvatarUrl,
    this.initialMessageId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supa = Supabase.instance.client;
  final _subscription = SubscriptionState.instance;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  Timer? _cooldownTimer;
  Timer? _typingDebounceTimer;
  Timer? _initialFallbackTimer;
  Timer? _highlightTimer;

  RealtimeChannel? _typingChannel;
  RealtimeChannel? _presenceChannel;

  bool _otherIsTyping = false;
  bool _chatBlocked = false;

  final List<_Msg> _messages = [];
  final Map<String, GlobalKey> _messageKeys = {};

  bool _sending = false;
  bool _uploadingMedia = false;
  bool _refreshing = false;
  String? _error;

  int _cooldownSeconds = 0;

  bool _otherIsOnline = false;

  String? _otherDisplayName;
  String? _otherAvatarUrl;
  String? _myAvatarUrl;

  String? _debugStatus;
  String? _pendingScrollMessageId;
  String? _highlightMessageId;

  bool _initialScrollDone = false;
  bool _isNearBottom = true;

  String get _myId => _supa.auth.currentUser?.id ?? '';

  bool get _canSendImages => _subscription.isPremium;
  bool get _canSendShorts => _subscription.isGold;

  @override
  void initState() {
    super.initState();
    _otherDisplayName = widget.otherDisplayName;
    _otherAvatarUrl = widget.otherAvatarUrl;
    _pendingScrollMessageId = widget.initialMessageId;

    PushService.setCurrentOpenConversation(widget.conversationId);
    PushService.registerScrollToMessageCallback(_scrollToMessageFromPush);

    _subscription.addListener(_onSubscriptionChanged);
    _scrollController.addListener(_handleScroll);
    _controller.addListener(_onTextChangedForTyping);
    _bootstrap();
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadMyProfile(),
      _loadOtherUserProfile(),
      _loadBlockedState(),
      _loadMessages(jumpToBottom: widget.initialMessageId == null),
      _subscription.refreshFromSupabase(),
    ]);

    if (_chatBlocked) {
      return;
    }

    await _setChatPresence();
    await _subscribeTypingRealtime();
    await _subscribePresenceRealtime();

    _listenRealtime();
    _scheduleInitialFallbackRefresh();
    await _markAsRead();
  }

  @override
  void dispose() {
    PushService.setCurrentOpenConversation(null);
    PushService.registerScrollToMessageCallback(null);

    _sub?.cancel();
    _cooldownTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _initialFallbackTimer?.cancel();
    _highlightTimer?.cancel();

    _subscription.removeListener(_onSubscriptionChanged);

    unawaited(_disposeRealtimeChannels());
    unawaited(_clearChatPresence());

    _scrollController.removeListener(_handleScroll);
    _controller.removeListener(_onTextChangedForTyping);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _disposeRealtimeChannels() async {
    if (_typingChannel != null) {
      await _supa.removeChannel(_typingChannel!);
      _typingChannel = null;
    }
    if (_presenceChannel != null) {
      await _supa.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
  }

  void _scheduleInitialFallbackRefresh() {
    _initialFallbackTimer?.cancel();
    _initialFallbackTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted || _chatBlocked) return;
      await _refreshChatSilently();
    });
  }

  Future<void> _refreshChatSilently() async {
    try {
      await Future.wait([
        _loadBlockedState(),
        _loadMessages(),
        _markAsRead(),
        _loadOtherUserProfile(),
        _loadMyProfile(),
      ]);
    } catch (_) {}
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
    });

    try {
      await _refreshChatSilently();
      if (!_chatBlocked) {
        await _setChatPresence();
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
      });
    }
  }

  Future<void> _loadBlockedState() async {
    final blocked = await ChatService.isUserBlocked(widget.otherUserId);

    if (!mounted) return;

    if (_chatBlocked != blocked) {
      setState(() {
        _chatBlocked = blocked;
      });
    }

    if (_chatBlocked) {
      await _sub?.cancel();
      _sub = null;
      await _disposeRealtimeChannels();
      await _clearChatPresence();
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    _isNearBottom = (max - current) < 80;
  }

  void _onTextChangedForTyping() {
    final me = _supa.auth.currentUser;
    if (me == null || _chatBlocked) return;

    final hasText = _controller.text.trim().isNotEmpty;
    if (!hasText) return;

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        await _supa.from('chat_typing').upsert(
          {
            'user_id': me.id,
            'conversation_id': widget.conversationId,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        );
      } catch (e) {
        debugPrint('chat_typing upsert failed: $e');
      }
    });
  }

  Future<void> _subscribeTypingRealtime() async {
    final me = _supa.auth.currentUser;
    if (me == null || _chatBlocked) return;

    if (_typingChannel != null) {
      await _supa.removeChannel(_typingChannel!);
      _typingChannel = null;
    }

    _typingChannel = _supa.channel('typing-${widget.conversationId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_typing',
        callback: (payload) {
          final row = payload.newRecord;

          final userId = row['user_id']?.toString();
          final conversationId = row['conversation_id']?.toString();
          final updatedAtStr = row['updated_at']?.toString();

          if (userId != widget.otherUserId) return;
          if (conversationId != widget.conversationId) return;

          final updatedAt = DateTime.tryParse(updatedAtStr ?? '');
          final isTyping = updatedAt != null &&
              DateTime.now().difference(updatedAt).inSeconds < 4;

          if (!mounted) return;

          setState(() {
            _otherIsTyping = isTyping;
          });
        },
      )
      ..subscribe((status, [error]) {
        debugPrint('[ChatScreen] typing realtime status: $status error=$error');
      });
  }

  Future<void> _subscribePresenceRealtime() async {
    final me = _supa.auth.currentUser;
    if (me == null || _chatBlocked) return;

    if (_presenceChannel != null) {
      await _supa.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }

    _presenceChannel = _supa.channel('presence-${widget.conversationId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_presence',
        callback: (payload) {
          final row = payload.newRecord;

          final userId = row['user_id']?.toString();
          final updatedAtStr = row['updated_at']?.toString();

          if (userId != widget.otherUserId) return;

          final updatedAt = DateTime.tryParse(updatedAtStr ?? '');
          final isOnline = updatedAt != null &&
              DateTime.now().difference(updatedAt).inSeconds < 30;

          if (!mounted) return;

          setState(() {
            _otherIsOnline = isOnline;
          });
        },
      )
      ..subscribe((status, [error]) {
        debugPrint(
          '[ChatScreen] presence realtime status: $status error=$error',
        );
      });
  }

  Future<void> _setChatPresence() async {
    final me = _supa.auth.currentUser;
    if (me == null || _chatBlocked) {
      if (!mounted) return;
      setState(() {
        _debugStatus = _chatBlocked
            ? 'Chat ist blockiert'
            : 'chat_presence: kein eingeloggter User';
      });
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _debugStatus =
              'set_chat_presence startet: user=${me.id}, conv=${widget.conversationId}';
        });
      }

      await _supa.rpc(
        'set_chat_presence',
        params: {
          'p_conversation_id': widget.conversationId,
        },
      );

      if (!mounted) return;
      setState(() {
        _debugStatus = 'chat_presence erfolgreich gesetzt';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _debugStatus = 'set_chat_presence FEHLER: $e';
        _error = 'set_chat_presence FEHLER: $e';
      });
      debugPrint('set_chat_presence failed: $e');
    }
  }

  Future<void> _clearChatPresence() async {
    final me = _supa.auth.currentUser;
    if (me == null) return;

    try {
      await _supa.from('chat_presence').delete().eq('user_id', me.id);
    } catch (e) {
      debugPrint('clear_chat_presence failed: $e');
    }
  }

  Future<void> _loadMyProfile() async {
    final me = _supa.auth.currentUser?.id;
    if (me == null) return;

    try {
      final row = await _supa
          .from('profiles')
          .select('avatar_url')
          .eq('user_id', me)
          .maybeSingle();

      if (!mounted) return;

      final avatarUrl = row?['avatar_url']?.toString();
      if (_myAvatarUrl != avatarUrl) {
        setState(() {
          _myAvatarUrl = avatarUrl;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadOtherUserProfile() async {
    try {
      final row = await _supa
          .from('profiles')
          .select('display_name, avatar_url, is_online')
          .eq('user_id', widget.otherUserId)
          .maybeSingle();

      if (!mounted) return;

      final newDisplayName =
          row?['display_name']?.toString() ?? _otherDisplayName;
      final newAvatarUrl = row?['avatar_url']?.toString() ?? _otherAvatarUrl;
      final newIsOnline = row?['is_online'] == true;

      if (_otherDisplayName != newDisplayName ||
          _otherAvatarUrl != newAvatarUrl ||
          _otherIsOnline != newIsOnline) {
        setState(() {
          _otherDisplayName = newDisplayName;
          _otherAvatarUrl = newAvatarUrl;
          _otherIsOnline = newIsOnline;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMessages({bool jumpToBottom = false}) async {
    if (_chatBlocked) return;

    try {
      final rows = await _supa
          .from('messages')
          .select(
            'id, conversation_id, sender_id, recipient_id, body, created_at, is_read, read_at, message_type, media_url, thumbnail_url, duration_seconds',
          )
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      final serverList = (rows as List)
          .map((e) => _Msg.fromRow(e as Map<String, dynamic>))
          .toList();

      final merged = _mergeServerAndLocalMessages(serverList);

      if (!mounted) return;

      final hadMessages = _messages.isNotEmpty;
      final oldLastId = hadMessages ? _messages.last.stableIdentity : null;
      final newLastId = merged.isNotEmpty ? merged.last.stableIdentity : null;
      final hasNewTailMessage = oldLastId != newLastId;

      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
      });

      _scheduleScrollToPendingMessageIfNeeded();

      if (jumpToBottom ||
          (!_initialScrollDone && _pendingScrollMessageId == null)) {
        _initialScrollDone = true;
        _scheduleBottomScroll(force: true);
        return;
      }

      if (hasNewTailMessage &&
          _isNearBottom &&
          _pendingScrollMessageId == null) {
        _scheduleBottomScroll(force: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Nachrichten konnten nicht geladen werden: $e');
    }
  }

  List<_Msg> _mergeServerAndLocalMessages(List<_Msg> serverList) {
    final localOnly = _messages.where((m) => m.isLocalOnly).toList();
    if (localOnly.isEmpty) return serverList;

    final merged = <_Msg>[...serverList];

    for (final local in localOnly) {
      if (local.isSending || local.isFailed) {
        merged.add(local);
      }
    }

    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  void _listenRealtime() {
    if (_chatBlocked) return;

    _sub?.cancel();

    _sub = _supa.from('messages').stream(primaryKey: ['id']).listen((rows) async {
      if (_chatBlocked) return;

      final filtered = rows.where((r) {
        final row = r as Map<String, dynamic>;
        return row['conversation_id']?.toString() == widget.conversationId;
      }).toList();

      final serverList =
          filtered.map((r) => _Msg.fromRow(r as Map<String, dynamic>)).toList();

      final merged = _mergeServerAndLocalMessages(serverList);

      if (!mounted) return;

      final hadMessages = _messages.isNotEmpty;
      final oldLastId = hadMessages ? _messages.last.stableIdentity : null;
      final newLastId = merged.isNotEmpty ? merged.last.stableIdentity : null;
      final hasNewTailMessage = oldLastId != newLastId;

      final sameLength = _messages.length == merged.length;
      final sameLastId = oldLastId == newLastId;

      if (sameLength && sameLastId) {
        await _markAsRead();
        _scheduleScrollToPendingMessageIfNeeded();
        return;
      }

      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
      });

      _scheduleScrollToPendingMessageIfNeeded();

      if (hasNewTailMessage &&
          _isNearBottom &&
          _pendingScrollMessageId == null) {
        _scheduleBottomScroll(force: false);
      }

      await _markAsRead();
    });
  }

  void _scheduleBottomScroll({required bool force}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final delays = <int>[0, 80, 180, 320, 520];

      for (final ms in delays) {
        Future.delayed(Duration(milliseconds: ms), () {
          if (!mounted || !_scrollController.hasClients) return;

          if (!force && !_isNearBottom) return;

          _jumpToBottom();
        });
      }
    });
  }

  void _scrollToMessageFromPush(String messageId) {
    if (!mounted || _chatBlocked) return;

    setState(() {
      _pendingScrollMessageId = messageId;
    });

    _scheduleScrollToPendingMessageIfNeeded();
  }

  void _scheduleScrollToPendingMessageIfNeeded() {
    final targetId = _pendingScrollMessageId;
    if (targetId == null || targetId.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToMessageById(targetId);
    });
  }

  void _scrollToMessageById(String messageId) {
    final key = _messageKeys[messageId];
    final context = key?.currentContext;

    if (context == null) {
      return;
    }

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.35,
    );

    _highlightTimer?.cancel();
    setState(() {
      _highlightMessageId = messageId;
      _pendingScrollMessageId = null;
      _initialScrollDone = true;
    });

    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_highlightMessageId == messageId) {
        setState(() {
          _highlightMessageId = null;
        });
      }
    });
  }

  String _newLocalKey() => 'local_${DateTime.now().microsecondsSinceEpoch}';

  void _insertLocalMessage(_Msg message) {
    setState(() {
      _messages.add(message);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    _scheduleBottomScroll(force: true);
  }

  void _removeLocalMessage(String localKey) {
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((m) => m.localKey == localKey);
    });
  }

  void _markLocalMessageFailed(String localKey, String errorText) {
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((m) => m.localKey == localKey);
      if (index == -1) return;
      _messages[index] = _messages[index].copyWith(
        isSending: false,
        isFailed: true,
        localError: errorText,
      );
    });
  }

  Future<void> _send() async {
    if (_chatBlocked) {
      _showSnack('Dieser Chat ist blockiert.');
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_cooldownSeconds > 0) {
      _showSnack('Bitte warte ${_formatWait(_cooldownSeconds)}.');
      return;
    }

    final localKey = _newLocalKey();
    final localMsg = _Msg.local(
      localKey: localKey,
      conversationId: widget.conversationId,
      senderId: _myId,
      recipientId: widget.otherUserId,
      body: text,
      createdAt: DateTime.now(),
      messageType: 'text',
    );

    _insertLocalMessage(localMsg);

    _controller.clear();

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _supa.rpc('send_message', params: {
        'p_conversation_id': widget.conversationId,
        'p_other_user_id': widget.otherUserId,
        'p_body': text,
      });

      _removeLocalMessage(localKey);
      await _loadMessages(jumpToBottom: true);
      await _markAsRead();
      await _setChatPresence();

      try {
        final me = _supa.auth.currentUser;
        if (me != null) {
          await _supa.from('chat_typing').delete().eq('user_id', me.id);
        }
      } catch (_) {}
    } catch (e) {
      _markLocalMessageFailed(localKey, e.toString());
      _handleSendError(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_chatBlocked) {
      _showSnack('Dieser Chat ist blockiert.');
      return;
    }

    if (!_subscription.loaded) {
      _showSnack('Abo-Status wird noch geladen...');
      return;
    }

    if (!_canSendImages) {
      _showSnack('Nur Premium oder Gold können Bilder senden.');
      return;
    }

    if (_cooldownSeconds > 0) {
      _showSnack('Bitte warte ${_formatWait(_cooldownSeconds)}.');
      return;
    }

    setState(() {
      _debugStatus = '1) Bildauswahl wird geöffnet...';
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      setState(() {
        _debugStatus = 'Abgebrochen: keine Datei gewählt.';
      });
      _showSnack('Keine Datei ausgewählt.');
      return;
    }

    final file = result.files.first;

    setState(() {
      _debugStatus = '2) Datei gewählt: ${file.name}';
    });

    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _debugStatus = 'Fehler: file.bytes ist null.';
      });
      _showSnack('Bild konnte nicht gelesen werden.');
      return;
    }

    setState(() {
      _debugStatus = '3) Bytes geladen: ${file.size} Bytes';
    });

    final ext = (file.extension ?? 'jpg').toLowerCase();
    final me = _supa.auth.currentUser;
    if (me == null) {
      setState(() {
        _debugStatus = 'Fehler: kein eingeloggter User.';
      });
      _showSnack('Nicht eingeloggt.');
      return;
    }

    final path =
        '${me.id}/images/chat_${DateTime.now().millisecondsSinceEpoch}.$ext';

    setState(() {
      _uploadingMedia = true;
      _error = null;
      _debugStatus = '4) Upload startet: $path';
    });

    try {
      await _supa.storage.from('chat-images').uploadBinary(path, bytes);
      setState(() {
        _debugStatus = '5) Upload erfolgreich.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingMedia = false;
        _debugStatus = 'Upload-Fehler: $e';
      });
      _showSnack('Upload fehlgeschlagen: $e');
      return;
    }

    final mediaUrl = _supa.storage.from('chat-images').getPublicUrl(path);
    final localKey = _newLocalKey();

    _insertLocalMessage(
      _Msg.local(
        localKey: localKey,
        conversationId: widget.conversationId,
        senderId: _myId,
        recipientId: widget.otherUserId,
        body: '',
        createdAt: DateTime.now(),
        messageType: 'image',
        mediaUrl: mediaUrl,
      ),
    );

    try {
      setState(() {
        _debugStatus = '6) RPC send_image_message startet...';
      });

      await _supa.rpc('send_image_message', params: {
        'p_conversation_id': widget.conversationId,
        'p_other_user_id': widget.otherUserId,
        'p_media_url': mediaUrl,
      });

      _removeLocalMessage(localKey);
      await _loadMessages(jumpToBottom: true);
      await _markAsRead();
      await _setChatPresence();

      setState(() {
        _debugStatus = 'Fertig: Bild gesendet.';
      });

      _showSnack('Bild gesendet.');
    } catch (e) {
      _markLocalMessageFailed(localKey, e.toString());
      _handleSendError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _uploadingMedia = false);
      }
    }
  }

  Future<void> _pickAndSendShort() async {
    if (_chatBlocked) {
      _showSnack('Dieser Chat ist blockiert.');
      return;
    }

    if (!_subscription.loaded) {
      _showSnack('Abo-Status wird noch geladen...');
      return;
    }

    if (!_canSendShorts) {
      _showSnack('Nur Gold kann Shorts senden.');
      return;
    }

    if (_cooldownSeconds > 0) {
      _showSnack('Bitte warte ${_formatWait(_cooldownSeconds)}.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      _showSnack('Video konnte nicht gelesen werden.');
      return;
    }

    final ext = (file.extension ?? 'mp4').toLowerCase();
    final me = _supa.auth.currentUser;
    if (me == null) {
      _showSnack('Nicht eingeloggt.');
      return;
    }

    final path =
        '${me.id}/shorts/short_${DateTime.now().millisecondsSinceEpoch}.$ext';

    setState(() {
      _uploadingMedia = true;
      _error = null;
      _debugStatus = 'Short-Upload startet...';
    });

    try {
      await _supa.storage.from('chat-shorts').uploadBinary(path, bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingMedia = false;
        _debugStatus = 'Short-Upload Fehler: $e';
      });
      _showSnack('Short-Upload fehlgeschlagen: $e');
      return;
    }

    final mediaUrl = _supa.storage.from('chat-shorts').getPublicUrl(path);
    final localKey = _newLocalKey();

    _insertLocalMessage(
      _Msg.local(
        localKey: localKey,
        conversationId: widget.conversationId,
        senderId: _myId,
        recipientId: widget.otherUserId,
        body: '',
        createdAt: DateTime.now(),
        messageType: 'short',
        mediaUrl: mediaUrl,
      ),
    );

    try {
      await _supa.rpc('send_short_message', params: {
        'p_conversation_id': widget.conversationId,
        'p_other_user_id': widget.otherUserId,
        'p_media_url': mediaUrl,
        'p_thumbnail_url': null,
        'p_duration_seconds': null,
      });

      _removeLocalMessage(localKey);
      await _loadMessages(jumpToBottom: true);
      await _markAsRead();
      await _setChatPresence();

      setState(() {
        _debugStatus = 'Short gesendet.';
      });

      _showSnack('Short gesendet.');
    } catch (e) {
      _markLocalMessageFailed(localKey, e.toString());
      _handleSendError(e.toString());
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _retryLocalMessage(_Msg msg) async {
    if (!msg.isLocalOnly || !msg.isFailed) return;
    if (msg.isSending || _chatBlocked) return;

    final localKey = msg.localKey;
    if (localKey == null) return;

    setState(() {
      final index = _messages.indexWhere((m) => m.localKey == localKey);
      if (index == -1) return;
      _messages[index] = _messages[index].copyWith(
        isSending: true,
        isFailed: false,
        localError: null,
        createdAt: DateTime.now(),
      );
    });

    try {
      if (msg.messageType == 'text') {
        await _supa.rpc('send_message', params: {
          'p_conversation_id': widget.conversationId,
          'p_other_user_id': widget.otherUserId,
          'p_body': (msg.body ?? '').trim(),
        });
      } else if (msg.messageType == 'image') {
        await _supa.rpc('send_image_message', params: {
          'p_conversation_id': widget.conversationId,
          'p_other_user_id': widget.otherUserId,
          'p_media_url': msg.mediaUrl ?? '',
        });
      } else if (msg.messageType == 'short') {
        await _supa.rpc('send_short_message', params: {
          'p_conversation_id': widget.conversationId,
          'p_other_user_id': widget.otherUserId,
          'p_media_url': msg.mediaUrl ?? '',
          'p_thumbnail_url': msg.thumbnailUrl,
          'p_duration_seconds': msg.durationSeconds,
        });
      }

      _removeLocalMessage(localKey);
      await _loadMessages(jumpToBottom: true);
      await _markAsRead();
      await _setChatPresence();
    } catch (e) {
      _markLocalMessageFailed(localKey, e.toString());
      _handleSendError(e.toString());
    }
  }

  void _handleSendError(String msg) {
    if (msg.contains('BLOCKED')) {
      setState(() {
        _chatBlocked = true;
      });
      _showSnack('Dieser Chat wurde blockiert.');
      return;
    }

    final wait = _parseWaitSeconds(msg);
    if (wait != null && wait > 0) {
      setState(() {
        _cooldownSeconds = wait;
        _debugStatus = 'Rate limit aktiv: ${_formatWait(wait)}';
      });
      _startCooldownTicker();
      _showSnack('Bitte warte ${_formatWait(wait)}');
      return;
    }

    if (msg.contains('NO_MATCH')) {
      _showSnack('Nur Gold kann ohne Match anschreiben.');
      return;
    }

    if (msg.contains('PREMIUM_REQUIRED_FOR_IMAGES')) {
      _showSnack('Nur Premium oder Gold können Bilder senden.');
      return;
    }

    if (msg.contains('GOLD_REQUIRED_FOR_SHORTS')) {
      _showSnack('Nur Gold kann Shorts senden.');
      return;
    }

    if (msg.contains('SHORT_TOO_LONG')) {
      _showSnack('Short ist zu lang.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _error = msg;
      _debugStatus = 'RPC-Fehler: $msg';
    });
    _showSnack('Fehler: $msg');
  }

  int? _parseWaitSeconds(String msg) {
    final idx = msg.indexOf('RATE_LIMIT:');
    if (idx == -1) return null;

    final after = msg.substring(idx + 'RATE_LIMIT:'.length).trim();
    final match = RegExp(r'^(\d+)').firstMatch(after);

    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  void _startCooldownTicker() {
    _cooldownTimer?.cancel();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _markAsRead() async {
    final me = _supa.auth.currentUser?.id;
    if (me == null || _chatBlocked) return;

    try {
      await _supa
          .from('messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', widget.conversationId)
          .eq('recipient_id', me)
          .eq('is_read', false);
    } catch (_) {}
  }

  void _goHome() {
    PushService.setCurrentOpenConversation(null);
    PushService.registerScrollToMessageCallback(null);
    unawaited(_clearChatPresence());
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  }

  Future<void> _openOtherProfile() async {
    PushService.setCurrentOpenConversation(null);
    PushService.registerScrollToMessageCallback(null);

    final blocked = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: widget.otherUserId),
          ),
        ) ??
        false;

    PushService.setCurrentOpenConversation(widget.conversationId);
    PushService.registerScrollToMessageCallback(_scrollToMessageFromPush);

    if (!mounted) return;

    if (blocked == true) {
      setState(() {
        _chatBlocked = true;
      });
      return;
    }

    await Future.wait([
      _setChatPresence(),
      _loadOtherUserProfile(),
      _loadBlockedState(),
    ]);
  }

  Future<void> _openMyProfile() async {
    PushService.setCurrentOpenConversation(null);
    PushService.registerScrollToMessageCallback(null);

    await Navigator.pushNamed(context, '/profile-edit');

    PushService.setCurrentOpenConversation(widget.conversationId);
    PushService.registerScrollToMessageCallback(_scrollToMessageFromPush);

    await Future.wait([
      _setChatPresence(),
      _loadMyProfile(),
      _loadBlockedState(),
    ]);
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatWait(int seconds) {
    final mm = (seconds ~/ 60).toString();
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  _Msg? get _lastOwnMessage {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].senderId == _myId) return _messages[i];
    }
    return null;
  }

  bool _isLastOwnMessage(_Msg m) {
    final last = _lastOwnMessage;
    if (last == null) return false;
    return last.stableIdentity == m.stableIdentity;
  }

  Widget _buildStatusRow(_Msg m, bool isLastOwn) {
    if (m.isLocalOnly) {
      if (m.isSending) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 6),
            Text(
              'Wird gesendet...',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        );
      }

      if (m.isFailed) {
        return GestureDetector(
          onTap: () => _retryLocalMessage(m),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline, size: 16, color: Colors.red),
              SizedBox(width: 4),
              Text(
                'Fehlgeschlagen • Tippen zum Wiederholen',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(m.createdAt),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
        if (isLastOwn && !m.isLocalOnly) ...[
          const SizedBox(width: 8),
          Icon(
            m.isRead ? Icons.done_all : Icons.done,
            size: 16,
            color: m.isRead ? Colors.blue : Colors.black45,
          ),
          const SizedBox(width: 4),
          Text(
            m.isRead ? 'Gelesen' : 'Gesendet',
            style: TextStyle(
              fontSize: 11,
              color: m.isRead ? Colors.blue : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMessageContent(_Msg m) {
    if (m.messageType == 'text') {
      return Text((m.body ?? '').trim());
    }

    if (m.messageType == 'image') {
      if ((m.mediaUrl ?? '').isNotEmpty) {
        return _ImageBubble(url: m.mediaUrl ?? '');
      }

      return Container(
        width: 220,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text('📷 Bild'),
      );
    }

    if (m.messageType == 'short') {
      if ((m.mediaUrl ?? '').isNotEmpty) {
        return _VideoBubble(url: m.mediaUrl ?? '');
      }

      return Container(
        width: 220,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text('🎬 Short'),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBlockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Dieser Chat ist blockiert.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Du kannst keine Nachrichten mehr senden oder empfangen.',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.68),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Zurück zur Übersicht'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sendDisabled = _sending ||
        _uploadingMedia ||
        _cooldownSeconds > 0 ||
        _refreshing ||
        _chatBlocked;

    final canShowImageButton =
        _subscription.loaded && _canSendImages && !_chatBlocked;
    final canShowShortButton =
        _subscription.loaded && _canSendShorts && !_chatBlocked;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openOtherProfile,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: (_otherAvatarUrl != null &&
                            _otherAvatarUrl!.isNotEmpty)
                        ? NetworkImage(_otherAvatarUrl!)
                        : null,
                    child: (_otherAvatarUrl == null || _otherAvatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _chatBlocked
                            ? Colors.red
                            : (_otherIsOnline ? Colors.green : Colors.grey),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _otherDisplayName ?? 'Chat',
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _chatBlocked
                          ? 'Blockiert'
                          : _otherIsTyping
                              ? 'schreibt...'
                              : (_otherIsOnline ? 'Online' : 'Offline'),
                      style: TextStyle(
                        fontSize: 12,
                        color: _chatBlocked
                            ? Colors.redAccent
                            : _otherIsTyping
                                ? Colors.greenAccent
                                : Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_rounded),
            onPressed: _goHome,
          ),
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshing ? null : _manualRefresh,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: _openMyProfile,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    (_myAvatarUrl != null && _myAvatarUrl!.isNotEmpty)
                        ? NetworkImage(_myAvatarUrl!)
                        : null,
                child: (_myAvatarUrl == null || _myAvatarUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_sending || _uploadingMedia || _refreshing)
            const LinearProgressIndicator(),
          if (_debugStatus != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.amber.withOpacity(0.2),
              child: Text(
                _debugStatus!,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (_cooldownSeconds > 0 && !_chatBlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Du kannst in ${_formatWait(_cooldownSeconds)} wieder senden.',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _chatBlocked
                ? _buildBlockedView()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    reverse: false,
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final isMe = m.senderId == _myId;
                      final isLastOwn = isMe && _isLastOwnMessage(m);

                      final key = _messageKeys.putIfAbsent(
                        m.id,
                        () => GlobalKey(debugLabel: 'msg_${m.id}'),
                      );

                      final isHighlighted = _highlightMessageId == m.id;

                      return Align(
                        key: key,
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? Colors.yellow.shade200
                                : (isMe
                                    ? Colors.pink.shade100
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                            border: m.isFailed
                                ? Border.all(color: Colors.red.withOpacity(0.4))
                                : (isHighlighted
                                    ? Border.all(
                                        color: Colors.orange,
                                        width: 1.5,
                                      )
                                    : null),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              _buildMessageContent(m),
                              const SizedBox(height: 4),
                              _buildStatusRow(m, isLastOwn),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_chatBlocked)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    if (canShowImageButton)
                      IconButton(
                        tooltip: 'Bild senden',
                        onPressed: sendDisabled ? null : _pickAndSendImage,
                        icon: const Icon(Icons.image_outlined),
                      ),
                    if (canShowShortButton)
                      IconButton(
                        tooltip: 'Short senden',
                        onPressed: sendDisabled ? null : _pickAndSendShort,
                        icon: const Icon(Icons.videocam_outlined),
                      ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !sendDisabled,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: sendDisabled
                              ? (_cooldownSeconds > 0
                                  ? 'Warte ${_formatWait(_cooldownSeconds)}…'
                                  : 'Bitte warten…')
                              : 'Nachricht schreiben...',
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => sendDisabled ? null : _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: sendDisabled ? null : _send,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final String url;

  const _ImageBubble({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const Text('Bild konnte nicht geladen werden');
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullScreenImage(url: url),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 220,
            height: 140,
            color: Colors.grey.shade300,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }
}

class _VideoBubble extends StatefulWidget {
  final String url;

  const _VideoBubble({required this.url});

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  VideoPlayerController? _videoController;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.url.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await controller.initialize();
    controller.setLooping(false);

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _videoController = controller;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _videoController == null) {
      return Container(
        width: 220,
        height: 140,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return GestureDetector(
      onTap: () {
        final c = _videoController!;
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
        setState(() {});
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 220,
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_videoController!),
                if (!_videoController!.value.isPlaying)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
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

class _FullScreenImage extends StatelessWidget {
  final String url;

  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }
}

class _Msg {
  final String id;
  final String? localKey;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final String? body;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final String messageType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final bool isLocalOnly;
  final bool isSending;
  final bool isFailed;
  final String? localError;

  const _Msg({
    required this.id,
    required this.localKey,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.readAt,
    required this.messageType,
    required this.mediaUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.isLocalOnly,
    required this.isSending,
    required this.isFailed,
    required this.localError,
  });

  factory _Msg.fromRow(Map<String, dynamic> row) {
    return _Msg(
      id: row['id'].toString(),
      localKey: null,
      conversationId: row['conversation_id'].toString(),
      senderId: row['sender_id'].toString(),
      recipientId: (row['recipient_id'] ?? '').toString(),
      body: (row['body'] ?? '').toString(),
      createdAt: DateTime.parse(row['created_at'].toString()),
      isRead: row['is_read'] == true,
      readAt: row['read_at'] != null
          ? DateTime.tryParse(row['read_at'].toString())
          : null,
      messageType: (row['message_type'] ?? 'text').toString(),
      mediaUrl: row['media_url']?.toString(),
      thumbnailUrl: row['thumbnail_url']?.toString(),
      durationSeconds: row['duration_seconds'] as int?,
      isLocalOnly: false,
      isSending: false,
      isFailed: false,
      localError: null,
    );
  }

  factory _Msg.local({
    required String localKey,
    required String conversationId,
    required String senderId,
    required String recipientId,
    required String? body,
    required DateTime createdAt,
    required String messageType,
    String? mediaUrl,
    String? thumbnailUrl,
    int? durationSeconds,
  }) {
    return _Msg(
      id: localKey,
      localKey: localKey,
      conversationId: conversationId,
      senderId: senderId,
      recipientId: recipientId,
      body: body ?? '',
      createdAt: createdAt,
      isRead: false,
      readAt: null,
      messageType: messageType,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      isLocalOnly: true,
      isSending: true,
      isFailed: false,
      localError: null,
    );
  }

  _Msg copyWith({
    String? id,
    String? localKey,
    String? conversationId,
    String? senderId,
    String? recipientId,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    String? messageType,
    String? mediaUrl,
    String? thumbnailUrl,
    int? durationSeconds,
    bool? isLocalOnly,
    bool? isSending,
    bool? isFailed,
    String? localError,
  }) {
    return _Msg(
      id: id ?? this.id,
      localKey: localKey ?? this.localKey,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      isSending: isSending ?? this.isSending,
      isFailed: isFailed ?? this.isFailed,
      localError: localError ?? this.localError,
    );
  }

  String get stableIdentity => localKey ?? id;
}