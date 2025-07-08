class ChatRoom {
  final String id;
  final String name;
  final String? imageUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isGroup;

  ChatRoom({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = true,
  });

  // For testing purposes
  static List<ChatRoom> get testChats => [
        ChatRoom(
          id: '1',
          name: 'Team Standup',
          lastMessage: 'Let\'s discuss the project updates',
          lastMessageTime: DateTime.now().subtract(const Duration(minutes: 15)),
          unreadCount: 2,
          isGroup: true,
        ),
        ChatRoom(
          id: '2',
          name: 'Design Review',
          lastMessage: 'I\'ve updated the mockups',
          lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
          unreadCount: 0,
          isGroup: true,
        ),
        ChatRoom(
          id: '3',
          name: 'Weekend Plans',
          lastMessage: 'Who\'s free this weekend?',
          lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
          unreadCount: 5,
          isGroup: true,
        ),
      ];

  String get formattedLastMessageTime {
    final now = DateTime.now();
    final difference = now.difference(lastMessageTime);

    if (difference.inDays > 7) {
      return '${lastMessageTime.day}/${lastMessageTime.month}/${lastMessageTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
