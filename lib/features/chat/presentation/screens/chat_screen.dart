import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:audio_waveforms/audio_waveforms.dart' as audio_waveforms;
import 'dart:io';
import 'dart:async';

// Import our custom AudioRecorderWidget
import '../widgets/audio_recorder_widget.dart';

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
    // Check microphone permission first
    final hasPermission = await _checkMicrophonePermission();
    if (!hasPermission) {
      return;
    }
    
    // Show the audio recorder in a modal bottom sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.6,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: AudioRecorderWidget(
                      onRecordingComplete: (path, duration) {
                        // Create and add the audio message
                        if (path.isNotEmpty && File(path).existsSync()) {
                          final file = File(path);
                          final size = file.lengthSync();
                          
                          final message = types.AudioMessage(
                            author: types.User(id: widget.currentUserId),
                            createdAt: DateTime.now().millisecondsSinceEpoch,
                            duration: duration,
                            id: _uuid.v4(),
                            name: 'Voice Message',
                            size: size,
                            uri: path,
                          );
                          
                          _addMessage(message);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addMessage(types.Message message) {
    // Stop any currently playing audio when adding a new message
    _stopAllAudioPlayback();
    
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
  
  void _stopAllAudioPlayback() {
    // Access the static members from the AudioMessageBubble state
    if (_AudioMessageBubbleState._globalPlayingController != null &&
        _AudioMessageBubbleState._currentlyPlayingBubble != null) {
      try {
        _AudioMessageBubbleState._globalPlayingController!.stopPlayer();
        if (_AudioMessageBubbleState._currentlyPlayingBubble!.mounted) {
          _AudioMessageBubbleState._currentlyPlayingBubble!.setState(() {
            _AudioMessageBubbleState._currentlyPlayingBubble!._isPlaying = false;
            _AudioMessageBubbleState._currentlyPlayingBubble!._position = Duration.zero;
          });
        }
        _AudioMessageBubbleState._globalPlayingController = null;
        _AudioMessageBubbleState._currentlyPlayingBubble = null;
      } catch (e) {
        print('Error stopping audio playback: $e');
      }
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
      return AudioMessageBubble(
        audioPath: message.uri,
        isCurrentUser: isCurrentUser,
        backgroundColor: isCurrentUser ? const Color(0xFF4F46E5) : Colors.grey[200]!,
        waveColor: isCurrentUser ? Colors.white : Colors.black87,
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
                        onTap: _handleVoiceMessage,  // Changed to use our new modal recording UI
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF4F46E5),
                          child: Icon(
                            Icons.mic,
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

class AudioMessageBubble extends StatefulWidget {
  final String audioPath;
  final bool isCurrentUser;
  final Color backgroundColor;
  final Color waveColor;

  const AudioMessageBubble({
    Key? key,
    required this.audioPath,
    required this.isCurrentUser,
    required this.backgroundColor,
    required this.waveColor,
  }) : super(key: key);

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  audio_waveforms.PlayerController? _playerController;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isDisposed = false;
  bool _canReplay = true;
  
  // Static controller to manage global playback state
  static audio_waveforms.PlayerController? _globalPlayingController;
  static _AudioMessageBubbleState? _currentlyPlayingBubble;
  static String? _currentlyPlayingPath;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }
  
  @override
  void didUpdateWidget(AudioMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the audio path changes, reinitialize the controller
    if (oldWidget.audioPath != widget.audioPath) {
      _disposeCurrentController();
      _initializeController();
    }
  }
  
  void _disposeCurrentController() {
    if (_globalPlayingController == _playerController) {
      _globalPlayingController = null;
      _currentlyPlayingBubble = null;
    }
    _playerController?.dispose();
    _playerController = null;
    _isInitialized = false;
    _isLoading = true;
    _isPlaying = false;
    _position = Duration.zero;
  }
  
  Future<void> _resetPlayerToStart() async {
    if (_playerController != null && !_isDisposed) {
      try {
        await _playerController!.seekTo(0);
        if (mounted) {
          setState(() {
            _position = Duration.zero;
            _isPlaying = false;
          });
        }
      } catch (e) {
        print('Error resetting player: $e');
      }
    }
  }
  
  Future<void> _handlePlayPause() async {
    if (_playerController == null || _isDisposed) return;
    
    try {
      if (_isPlaying) {
        // Pause current playback
        await _playerController!.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
      } else {
        // Stop any other audio that might be playing
        await _stopOtherAudio();
        
        // If this controller is not initialized, reinitialize
        if (!_isInitialized) {
          print('Reinitializing controller for replay: ${widget.audioPath}');
          _createNewController();
          // Wait for initialization
          await Future.delayed(Duration(milliseconds: 500));
          if (!_isInitialized) {
            print('Controller failed to initialize');
            return;
          }
        }
        
        // Start playback
        await _playerController!.seekTo(0);
        await _playerController!.startPlayer();
        
        // Update global state
        _globalPlayingController = _playerController;
        _currentlyPlayingBubble = this;
        _currentlyPlayingPath = widget.audioPath;
        
        setState(() {
          _isPlaying = true;
          _position = Duration.zero;
          _canReplay = false;
        });
      }
    } catch (e) {
      print('Error in play/pause: $e');
      // Reset state on error
      if (mounted && !_isDisposed) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _canReplay = true;
        });
        // Try to reinitialize on next attempt
        _createNewController();
      }
    }
  }
  
  Future<void> _stopOtherAudio() async {
    if (_globalPlayingController != null && 
        _globalPlayingController != _playerController &&
        _currentlyPlayingBubble != null) {
      try {
        await _globalPlayingController!.stopPlayer();
        if (_currentlyPlayingBubble!.mounted) {
          _currentlyPlayingBubble!.setState(() {
            _currentlyPlayingBubble!._isPlaying = false;
            _currentlyPlayingBubble!._position = Duration.zero;
            _currentlyPlayingBubble!._canReplay = true;
          });
        }
      } catch (e) {
        print('Error stopping other audio: $e');
      }
      _globalPlayingController = null;
      _currentlyPlayingBubble = null;
      _currentlyPlayingPath = null;
    }
  }

  void _initializeController() {
    // Delay the controller initialization to avoid MediaQuery issues
    Future.microtask(() {
      if (mounted && !_isDisposed) {
        _createNewController();
      }
    });
  }
  
  void _createNewController() {
    _disposeCurrentController();
    setState(() {
      _playerController = audio_waveforms.PlayerController();
      _isLoading = true;
      _isInitialized = false;
      _canReplay = true;
    });
    _preparePlayer();
  }

  void _preparePlayer() async {
    if (_playerController == null || _isDisposed) return;
    
    // Validate that the audio file exists
    if (!File(widget.audioPath).existsSync()) {
      print('Audio file does not exist: ${widget.audioPath}');
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _isInitialized = false;
        });
      }
      return;
    }
    
    try {
      // Initialize the player with the audio file
      await _playerController!.preparePlayer(
        path: widget.audioPath,
        shouldExtractWaveform: true,
        noOfSamples: 300, // More samples for smoother animation
        volume: 1.0,
      );

      // Get audio duration
      final durationMillis = await _playerController!.getDuration();
      if (mounted && !_isDisposed) {
        setState(() {
          _duration = Duration(milliseconds: durationMillis ?? 0);
          _isInitialized = true;
          _isLoading = false;
        });
      }

      // Listen to player state changes
      _playerController!.onPlayerStateChanged.listen((state) {
        if (mounted && !_isDisposed) {
          setState(() {
            _isPlaying = state == audio_waveforms.PlayerState.playing;
            
            // Update global state
            if (_isPlaying) {
              _globalPlayingController = _playerController;
              _currentlyPlayingBubble = this;
            } else if (_globalPlayingController == _playerController) {
              _globalPlayingController = null;
              _currentlyPlayingBubble = null;
            }
          });
        }
      });

      // Listen to current position
      _playerController!.onCurrentDurationChanged.listen((duration) {
        if (mounted && !_isDisposed) {
          setState(() {
            _position = Duration(milliseconds: duration);
          });
        }
      });

      // When playback completes
      _playerController!.onCompletion.listen((_) {
        if (mounted && !_isDisposed) {
          print('Audio playback completed for: ${widget.audioPath}');
          
          // Clear global state when playback completes
          if (_globalPlayingController == _playerController) {
            _globalPlayingController = null;
            _currentlyPlayingBubble = null;
            _currentlyPlayingPath = null;
          }
          
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
            _canReplay = true;
          });
          
          // Just reset to beginning, don't recreate controller
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted && !_isDisposed && _playerController != null) {
              try {
                _playerController!.seekTo(0);
              } catch (e) {
                print('Error seeking to start: $e');
                // Only recreate if seek fails
                _createNewController();
              }
            }
          });
        }
      });
    } catch (e) {
      print('Error preparing audio player: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeCurrentController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: widget.backgroundColor,
      ),
      child: IntrinsicWidth(
        child: _isLoading 
            ? _buildLoadingWaveform()
            : _isInitialized
                ? _buildPlayableWaveform()
                : _buildErrorWaveform(),
      ),
    );
  }
  
  Widget _buildLoadingWaveform() {
    return SizedBox(
      width: 220,
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.waveColor.withOpacity(0.7),
            ),
          ),
          SizedBox(width: 12),
          Text(
            "Processing audio...",
            style: TextStyle(
              color: widget.waveColor.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorWaveform() {
    return SizedBox(
      width: 220,
      height: 40,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.waveColor.withOpacity(0.1),
            ),
            child: Icon(
              Icons.error_outline,
              color: widget.waveColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Text(
            "Could not load audio",
            style: TextStyle(
              color: widget.waveColor.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlayableWaveform() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        GestureDetector(
          onTap: () async {
            if (_playerController == null || _isDisposed) return;
            
            await _handlePlayPause();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.waveColor.withOpacity(0.1),
            ),
            child: Icon(
              _isPlaying ? Icons.pause : (_canReplay ? Icons.play_arrow : Icons.refresh),
              color: widget.waveColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Waveform
        Container(
          width: 140,
          height: 40,
          child: _playerController != null && _isInitialized ? audio_waveforms.AudioFileWaveforms(
              size: Size(140, 40),
              playerController: _playerController!,
              enableSeekGesture: true,
              continuousWaveform: true,
              playerWaveStyle: audio_waveforms.PlayerWaveStyle(
                fixedWaveColor: widget.waveColor.withOpacity(0.3),
                liveWaveColor: widget.waveColor,
                seekLineColor: widget.waveColor,
                showSeekLine: true,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: widget.waveColor.withOpacity(0.1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ) : Container(
            width: 140,
            height: 40,
            decoration: BoxDecoration(
              color: widget.waveColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.waveColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Duration
        Text(
          _isPlaying
            ? _formatDuration(_position)
            : _formatDuration(_duration),
          style: TextStyle(
            color: widget.waveColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
