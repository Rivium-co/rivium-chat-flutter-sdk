import 'package:dio/dio.dart';
import '../config.dart';
import '../models/models.dart';

/// REST API service for RiviumChat backend.
class ApiService {
  final RiviumChatConfig _config;
  late final Dio _dio;

  ApiService(this._config) {
    _dio = Dio(BaseOptions(
      baseUrl: RiviumChatConfig.baseUrl,
      headers: {
        'x-api-key': _config.apiKey,
        'Content-Type': 'application/json',
      },
    ));
  }

  // ============ Room Methods ============

  /// Creates a new chat room.
  Future<Room> createRoom({
    RoomType type = RoomType.direct,
    String? name,
    required List<Map<String, dynamic>> participants,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _dio.post('/api/v1/rooms', data: {
      'type': type.name,
      if (name != null) 'name': name,
      'participants': participants,
      if (metadata != null) 'metadata': metadata,
    });
    return Room.fromJson(response.data);
  }

  /// Finds an existing room by external ID or creates a new one.
  Future<Room> findOrCreateRoom({
    required String externalId,
    RoomType type = RoomType.direct,
    String? name,
    required List<Map<String, dynamic>> participants,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _dio.post('/api/v1/rooms/find-or-create', data: {
      'externalId': externalId,
      'type': type.name,
      if (name != null) 'name': name,
      'participants': participants,
      if (metadata != null) 'metadata': metadata,
    });
    // API returns { room: {...}, created: bool }
    final data = response.data;
    if (data is Map && data.containsKey('room')) {
      return Room.fromJson(data['room'] as Map<String, dynamic>);
    }
    return Room.fromJson(data);
  }

  /// Gets a room by its external ID.
  Future<Room> getRoomByExternalId(String externalId) async {
    final response =
        await _dio.get('/api/v1/rooms/by-external-id/$externalId');
    return Room.fromJson(response.data);
  }

  /// Lists all rooms for a user.
  Future<List<Room>> listRooms(String userId) async {
    final response = await _dio.get('/api/v1/rooms', queryParameters: {
      'userId': userId,
    });
    return (response.data as List).map((e) => Room.fromJson(e)).toList();
  }

  /// Gets a room by ID.
  Future<Room> getRoom(String roomId) async {
    final response = await _dio.get('/api/v1/rooms/$roomId');
    return Room.fromJson(response.data);
  }

  /// Adds a participant to a room.
  Future<Participant> addParticipant(
    String roomId, {
    required String externalUserId,
    String? displayName,
    String? locale,
    ParticipantRole role = ParticipantRole.member,
  }) async {
    final response = await _dio.post('/api/v1/rooms/$roomId/participants',
        data: {
          'externalUserId': externalUserId,
          if (displayName != null) 'displayName': displayName,
          if (locale != null) 'locale': locale,
          'role': role.name,
        });
    return Participant.fromJson(response.data);
  }

  // ============ Message Methods ============

  /// Sends a message to a room.
  Future<Message> sendMessage(
    String roomId, {
    required String senderUserId,
    required String content,
    MessageType type = MessageType.text,
    List<Attachment>? attachments,
    Map<String, dynamic>? metadata,
    String? replyToId,
  }) async {
    final response = await _dio.post('/api/v1/rooms/$roomId/messages', data: {
      'senderUserId': senderUserId,
      'content': content,
      'type': type.name,
      if (attachments != null)
        'attachments': attachments.map((a) => {
              'url': a.url,
              if (a.mimeType != null) 'mimeType': a.mimeType,
              if (a.name != null) 'name': a.name,
              if (a.size != null) 'size': a.size,
            }).toList(),
      if (metadata != null) 'metadata': metadata,
      if (replyToId != null) 'replyToId': replyToId,
    });
    return Message.fromJson(response.data);
  }

  /// Gets messages for a room with pagination.
  Future<PaginatedMessages> getMessages(
    String roomId, {
    required String userId,
    int limit = 50,
    String? before,
  }) async {
    final response = await _dio.get('/api/v1/rooms/$roomId/messages',
        queryParameters: {
          'userId': userId,
          'limit': limit,
          if (before != null) 'before': before,
        });
    return PaginatedMessages(
      messages: (response.data['messages'] as List)
          .map((e) => Message.fromJson(e))
          .toList(),
      hasMore: response.data['hasMore'] as bool,
    );
  }

  /// Marks messages in a room as read.
  Future<void> markAsRead(String roomId, String userId) async {
    await _dio.post('/api/v1/rooms/$roomId/read', data: {
      'userId': userId,
    });
  }

  /// Deletes a message.
  Future<void> deleteMessage(String messageId, String userId) async {
    await _dio.delete('/api/v1/messages/$messageId', queryParameters: {
      'userId': userId,
    });
  }

  /// Edits a message.
  Future<Message> editMessage(
    String messageId, {
    required String userId,
    required String content,
  }) async {
    final response = await _dio.put('/api/v1/messages/$messageId', data: {
      'userId': userId,
      'content': content,
    });
    return Message.fromJson(response.data);
  }

  /// Searches messages in a room.
  Future<List<Message>> searchMessages(
    String roomId, {
    required String userId,
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get('/api/v1/rooms/$roomId/messages/search',
        queryParameters: {
          'userId': userId,
          'q': query,
          'limit': limit,
          'offset': offset,
        });
    return (response.data as List).map((e) => Message.fromJson(e)).toList();
  }

  // ============ Reaction Methods ============

  /// Adds a reaction to a message.
  Future<Reaction> addReaction(
    String messageId, {
    required String userId,
    required String emoji,
  }) async {
    final response = await _dio.post('/api/v1/messages/$messageId/reactions',
        data: {
          'userId': userId,
          'emoji': emoji,
        });
    return Reaction.fromJson(response.data);
  }

  /// Removes a reaction from a message.
  Future<void> removeReaction(
    String messageId, {
    required String userId,
    required String emoji,
  }) async {
    await _dio.delete('/api/v1/messages/$messageId/reactions', data: {
      'userId': userId,
      'emoji': emoji,
    });
  }

  /// Gets all reactions for a message.
  Future<List<Reaction>> getReactions(String messageId) async {
    final response = await _dio.get('/api/v1/messages/$messageId/reactions');
    return (response.data as List).map((e) => Reaction.fromJson(e)).toList();
  }

  // ============ Pin Methods ============

  /// Pins a message.
  Future<Message> pinMessage(String messageId, {required String userId}) async {
    final response = await _dio.post('/api/v1/messages/$messageId/pin', data: {
      'userId': userId,
    });
    return Message.fromJson(response.data);
  }

  /// Unpins a message.
  Future<void> unpinMessage(String messageId, {required String userId}) async {
    await _dio.delete('/api/v1/messages/$messageId/pin', data: {
      'userId': userId,
    });
  }

  /// Gets all pinned messages in a room.
  Future<List<Message>> getPinnedMessages(String roomId) async {
    final response = await _dio.get('/api/v1/rooms/$roomId/pinned');
    return (response.data as List).map((e) => Message.fromJson(e)).toList();
  }

  // ============ Other Methods ============

  /// Gets unread message summary for a user.
  Future<UnreadSummary> getUnreadSummary(String userId) async {
    final response = await _dio.get('/api/v1/rooms/unread-summary',
        queryParameters: {'userId': userId});
    return UnreadSummary.fromJson(response.data);
  }

  /// Gets messages where a user was mentioned.
  Future<List<Message>> getMentions(
    String roomId, {
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response =
        await _dio.get('/api/v1/rooms/$roomId/mentions', queryParameters: {
      'userId': userId,
      'limit': limit,
      'offset': offset,
    });
    return (response.data as List).map((e) => Message.fromJson(e)).toList();
  }

  /// Gets online users in a room via the server API (no subscription needed).
  Future<Set<String>> getRoomPresence(String roomId) async {
    final response = await _dio.get('/api/v1/rooms/$roomId/presence');
    final online = response.data['online'] as List?;
    if (online == null) return {};
    return online.map((e) => e as String).toSet();
  }

  /// Gets a Centrifugo connection token.
  Future<String> getCentrifugoToken(
    String userId, {
    Map<String, dynamic>? info,
  }) async {
    final response = await _dio.post('/api/v1/centrifugo/token', data: {
      'userId': userId,
      if (info != null) 'info': info,
    });
    return response.data['token'] as String;
  }

  /// Disposes resources.
  void dispose() {
    _dio.close();
  }
}
