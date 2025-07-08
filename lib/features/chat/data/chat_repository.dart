import 'package:parlay/features/chat/domain/message.dart';

abstract class ChatRepository {
  Stream<List<Message>> getMessages(String groupId);
  Future<void> sendMessage(String groupId, String content);
  Future<void> deleteMessage(String messageId);
}

class MockChatRepository implements ChatRepository {
  @override
  Stream<List<Message>> getMessages(String groupId) async* {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock messages
    final messages = [
      Message(
        id: '1',
        content: 'Hey everyone! Welcome to the group!',
        senderId: 'user1',
        senderName: 'Alex Johnson',
        senderAvatar: 'https://randomuser.me/api/portraits/men/1.jpg',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isCurrentUser: false,
      ),
      Message(
        id: '2',
        content: 'Thanks for creating the group!',
        senderId: 'user2',
        senderName: 'Sam Wilson',
        senderAvatar: 'https://randomuser.me/api/portraits/women/2.jpg',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
        isCurrentUser: false,
      ),
      // First message in sequence
      Message(
        id: '3',
        content: 'Hey team! I was thinking about our project timeline.',
        senderId: 'user3',
        senderName: 'Jordan Lee',
        senderAvatar: 'https://randomuser.me/api/portraits/men/3.jpg',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        isCurrentUser: false,
      ),
      // Second message in sequence (same sender)
      Message(
        id: '4',
        content: 'We need to finalize the design by Friday',
        senderId: 'user3',
        senderName: 'Jordan Lee',
        senderAvatar: 'https://randomuser.me/api/portraits/men/3.jpg',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 28)),
        isCurrentUser: false,
      ),
      // Third message in sequence (same sender)
      Message(
        id: '5',
        content: 'Then we can start development next week',
        senderId: 'user3',
        senderName: 'Jordan Lee',
        senderAvatar: 'https://randomuser.me/api/portraits/men/3.jpg',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 26)),
        isCurrentUser: false,
      ),
      // A message from current user
      Message(
        id: '6',
        content: 'Sounds good! I\'ll update the timeline',
        senderId: 'current_user',
        senderName: 'Me',
        senderAvatar: 'https://randomuser.me/api/portraits/men/4.jpg',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
        isCurrentUser: true,
      ),
    ];
    
    // Sort by timestamp (oldest first)
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Yield the messages
    yield messages;
  }

  @override
  Future<void> sendMessage(String groupId, String content) async {
    // In a real implementation, this would send the message to a server
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    // In a real implementation, this would delete the message from the server
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
