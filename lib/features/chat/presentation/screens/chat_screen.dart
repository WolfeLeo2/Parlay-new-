import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;

  const ChatScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<types.Message> _messages = [];
  final _uuid = const Uuid();
  bool _isRecording = false;
  late FlutterSoundRecorder _recorder;
  late FlutterSoundPlayer _audioPlayer;
  String? _recordingPath;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _loadSampleMessages();
  }

  Future<void> _initializeRecorder() async {
    try {
      _recorder = FlutterSoundRecorder();
      _audioPlayer = FlutterSoundPlayer();

      // Always request microphone permission first
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        print('Microphone permission not granted: $status');
        await _showPermissionDeniedDialog();
        return;
      }

      // Initialize recorder
      await _recorder.openRecorder();
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 10));

      // Initialize player
      await _audioPlayer.openPlayer();

      setState(() {
        _isRecorderInitialized = true;
        _isPlayerInitialized = true;
      });

      print('Recorder and player initialized successfully');
    } catch (e) {
      print('Error initializing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize audio: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showPermissionDeniedDialog() async {
    if (!mounted) return;

    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'Parlay needs microphone access to record voice messages. '
          'Please enable it in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, true);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldOpenSettings == true) {
      // Wait a bit before checking permission again
      await Future.delayed(const Duration(seconds: 1));
      final newStatus = await Permission.microphone.status;
      if (newStatus.isGranted && mounted) {
        _initializeRecorder();
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_isRecorderInitialized) {
      _recorder.closeRecorder();
      _isRecorderInitialized = false;
    }
    if (_isPlayerInitialized) {
      _audioPlayer.closePlayer();
      _isPlayerInitialized = false;
    }
    super.dispose();
  }

  void _loadSampleMessages() {
    final sampleMessages = [
      types.TextMessage(
        author: types.User(id: 'user1'),
        createdAt: DateTime.now().millisecondsSinceEpoch - 1000 * 60 * 60 * 2,
        id: _uuid.v4(),
        text: 'Hey everyone! Welcome to the group!',
      ),
      types.TextMessage(
        author: types.User(id: 'user2'),
        createdAt: DateTime.now().millisecondsSinceEpoch - 1000 * 60 * 105,
        id: _uuid.v4(),
        text: 'Thanks for creating the group!',
      ),
      types.TextMessage(
        author: types.User(id: widget.currentUserId),
        createdAt: DateTime.now().millisecondsSinceEpoch - 1000 * 60 * 90,
        id: _uuid.v4(),
        text: 'Hey team! I was thinking about our project timeline.',
      ),
    ];

    setState(() {
      _messages.addAll(sampleMessages);
    });
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      final image = types.ImageMessage(
        author: types.User(id: widget.currentUserId),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: 1440,
        id: _uuid.v4(),
        name: result.name,
        size: bytes.length,
        uri: result.path,
        width: 1440,
      );

      _addMessage(image);
    }
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final size = await file.length();
      final mimeType = lookupMimeType(file.path);

      final message = types.FileMessage(
        author: types.User(id: widget.currentUserId),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: _uuid.v4(),
        mimeType: mimeType,
        name: result.files.single.name,
        size: size,
        uri: result.files.single.path!,
      );

      _addMessage(message);
    }
  }

  Future<void> _startRecording() async {
    try {
      // Check microphone permission
      final hasPermission = await _checkMicrophonePermission();
      if (!hasPermission) {
        return;
      }

      // Double check if recorder is initialized
      if (!_isRecorderInitialized) {
        await _initializeRecorder();
        if (!_isRecorderInitialized) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to initialize audio recorder'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }

      if (!_isRecorderInitialized) {
        print('Reinitializing recorder...');
        await _initializeRecorder();
        if (!_isRecorderInitialized) {
          print('Failed to initialize recorder');
          return;
        }
      }

      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
      print('Starting recording to: $_recordingPath');

      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
      });
      print('Recording started successfully');
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) return;

      String? path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      if (path != null && File(path).existsSync()) {
        final file = File(path);
        final size = await file.length();

        final message = types.AudioMessage(
          author: types.User(id: widget.currentUserId),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          duration: const Duration(seconds: 0), // You might want to track actual duration
          id: _uuid.v4(),
          name: 'Voice Message',
          size: size,
          uri: path,
        );

        _addMessage(message);
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _handleVoiceMessage() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final message = types.TextMessage(
      author: types.User(id: widget.currentUserId),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _uuid.v4(),
      text: text,
    );

    _addMessage(message);
    _messageController.clear();
  }

  void _handleAttachmentPressed() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo, color: Colors.blue),
                ),
                title: const Text('Photo'),
                subtitle: const Text('Share a photo from your gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.attach_file, color: Colors.green),
                ),
                title: const Text('Document'),
                subtitle: const Text('Share a document or file'),
                onTap: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(types.Message message) {
    final isCurrentUser = message.author.id == widget.currentUserId;
    final messageIndex = _messages.indexWhere((m) => m.id == message.id);
    final isFirstInSequence = messageIndex == 0 || 
        _messages[messageIndex - 1].author.id != message.author.id;

    final isPartOfSequence = messageIndex > 0 && _messages[messageIndex - 1].author.id == message.author.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0),
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(left: 32.0, bottom: 0.5),
              child: Text(
                message.author.id, // Displaying user ID as a placeholder
                style: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: isCurrentUser ? 40.0 : 2.0,
              right: isCurrentUser ? 4.0 : 0.0,
              bottom: isPartOfSequence ? 0.5 : 2.0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0, bottom: 1.0),
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.grey[300],
                      child: Text(
                        message.author.id.isNotEmpty ? message.author.id[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    child: _buildMessageContent(message, isCurrentUser, isFirstInSequence),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(types.Message message, bool isCurrentUser, bool isFirstInSequence) {
    if (message is types.TextMessage) {
      return BubbleSpecialThree(
        text: message.text,
        color: isCurrentUser
            ? const Color(0xFF4F46E5)
            : Colors.grey[200]!,
        tail: isFirstInSequence,
        textStyle: TextStyle(
          color: isCurrentUser ? Colors.white : Colors.black87,
          fontSize: 14,
          height: 1.2,
        ),
        isSender: isCurrentUser,
      );
    } else if (message is types.ImageMessage) {
      return GestureDetector(
        onTap: () => _showImage(message),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isCurrentUser ? const Color(0xFF4F46E5) : Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(message.uri),
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else if (message is types.FileMessage) {
      return GestureDetector(
        onTap: () => _openFile(message),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4.0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isCurrentUser ? const Color(0xFF4F46E5) : Colors.grey[200],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.attach_file,
                color: isCurrentUser ? Colors.white : Colors.black87,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.name,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black87,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (message is types.AudioMessage) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isCurrentUser ? const Color(0xFF4F46E5) : Colors.grey[200],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.play_arrow,
                color: isCurrentUser ? Colors.white : Colors.black87,
              ),
              onPressed: () => _playAudio(message),
            ),
            const SizedBox(width: 8),
            Text(
              'Voice Message',
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(); // Fallback for unsupported message types
    }
  }

  void _showImage(types.ImageMessage message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(imageUri: message.uri),
      ),
    );
  }

  void _openFile(types.FileMessage message) async {
    final file = File(message.uri);
    if (await file.exists()) {
      OpenFilex.open(message.uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found')),
      );
    }
  }

  Future<void> _playAudio(types.AudioMessage message) async {
    try {
      if (File(message.uri).existsSync()) {
        await _audioPlayer.startPlayer(
          fromURI: message.uri,
          codec: Codec.aacADTS,
        );
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<bool> _checkMicrophonePermission() async {
    var status = await Permission.microphone.status;

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        await _showPermissionDeniedDialog();
      }
      return false;
    }

    return status.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.groupName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {
              // TODO: Implement more options
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: EdgeInsets.only(
                  top: 8.0,
                  bottom: 8.0 + bottomInset + bottomPadding,
                  left: 8.0,
                  right: 8.0,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        child: Row(
          children: [
            // Message input pill with plus inside (with circular border)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Plus icon inside the pill, with a thinner and tighter circular border
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(0xFF4F46E5), width: 1.2),
                        color: Colors.transparent,
                      ),
                      child: InkWell(
                        onTap: _handleAttachmentPressed,
                        customBorder: const CircleBorder(),
                        child: const Icon(Icons.add, color: Color(0xFF4F46E5), size: 22),
                      ),
                    ),
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: '',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                        ),
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onChanged: (_) {
                          setState(() {}); // To trigger icon change
                        },
                        onSubmitted: (_) => _handleSendMessage(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Voice/send button outside the pill
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: _messageController.text.trim().isEmpty
                    ? GestureDetector(
                        key: const ValueKey('soundwave'),
                        onLongPress: _startRecording,
                        onLongPressEnd: (_) => _stopRecording(),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: _isRecording ? Colors.red : const Color(0xFF4F46E5),
                          child: Icon(
                            _isRecording ? Icons.mic : Icons.graphic_eq,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        key: const ValueKey('send'),
                        radius: 22,
                        backgroundColor: const Color(0xFF4F46E5),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          onPressed: _handleSendMessage,
                          splashRadius: 22,
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

class FullScreenImagePage extends StatelessWidget {
  final String imageUri;

  const FullScreenImagePage({Key? key, required this.imageUri}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Image.file(
            File(imageUri),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
