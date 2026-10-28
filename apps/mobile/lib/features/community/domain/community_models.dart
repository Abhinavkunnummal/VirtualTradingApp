class CommunityRoomModel {
  final String roomId;
  final String name;
  final String description;
  final String category;
  final int memberCount;
  final bool isPrivate;

  const CommunityRoomModel({
    required this.roomId,
    required this.name,
    required this.description,
    required this.category,
    required this.memberCount,
    this.isPrivate = false,
  });

  factory CommunityRoomModel.fromJson(Map<String, dynamic> json) {
    return CommunityRoomModel(
      roomId: json['roomId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'GENERAL',
      memberCount: json['memberCount'] as int? ?? 0,
      isPrivate: json['isPrivate'] as bool? ?? false,
    );
  }
}

class CommunityMessageModel {
  final String id;
  final String roomId;
  final String authorName;
  final String content;
  final String type;
  final String? tradeTag;
  final String? sentiment;
  final int likesCount;
  final bool isAiGenerated;
  final String createdAt;

  const CommunityMessageModel({
    required this.id,
    required this.roomId,
    required this.authorName,
    required this.content,
    required this.type,
    this.tradeTag,
    this.sentiment,
    this.likesCount = 0,
    this.isAiGenerated = false,
    required this.createdAt,
  });

  factory CommunityMessageModel.fromJson(Map<String, dynamic> json) {
    return CommunityMessageModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Trader',
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'CHAT',
      tradeTag: json['tradeTag'] as String?,
      sentiment: json['sentiment'] as String?,
      likesCount: json['likesCount'] as int? ?? 0,
      isAiGenerated: json['isAiGenerated'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
