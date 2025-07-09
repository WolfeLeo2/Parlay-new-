import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Extension to format duration
extension DurationExtension on Duration {
  String toFormattedString() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(inMinutes.remainder(60));
    final seconds = twoDigits(inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class AudioRecorderWidget extends StatefulWidget {
  final Function(String path, Duration duration) onRecordingComplete;
  final Color primaryColor;
  final Color backgroundColor;
  final bool showControls;

  const AudioRecorderWidget({
    Key? key,
    required this.onRecordingComplete,
    this.primaryColor = const Color(0xFF4F46E5),
    this.backgroundColor = Colors.white,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  late final RecorderController _recorderController;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _hasPermission = false;
  bool _isInitialized = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _errorMessage;
  
  // For waveform visualization
  final _waveformKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
    _checkPermissionAndInitialize();
  }

  @override
  void dispose() {
    _stopTimer();
    // Stop any ongoing recording before disposing
    if (_isRecording) {
      _recorderController.stop();
    }
    _recorderController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndInitialize() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        setState(() => _hasPermission = true);
        await _initializeRecorder();
      } else {
        setState(() => _errorMessage = 'Microphone permission denied');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error initializing recorder: $e');
    } finally {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      // Set up recording path
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      // Configure the recorder
      _recorderController
        ..androidEncoder = AndroidEncoder.aac
        ..androidOutputFormat = AndroidOutputFormat.mpeg4
        ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
        ..sampleRate = 44100;
      
      // Initialize the recorder with a small delay to ensure proper setup
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to initialize recorder: $e');
      }
      rethrow;
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      await _checkPermissionAndInitialize();
      if (!_hasPermission) return;
    }

    try {
      // Start recording with the specified path
      await _recorderController.record(path: _recordingPath);
      
      if (mounted) {
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _errorMessage = null;
          _recordingDuration = Duration.zero;
        });
      }
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to start recording: $e');
      }
    }
  }

  Future<void> _pauseResumeRecording() async {
    try {
      if (_isPaused) {
        // In audio_waveforms, we use record() to resume
        await _recorderController.record();
        _startTimer();
      } else {
        await _recorderController.pause();
        _stopTimer();
      }
      if (mounted) {
        setState(() => _isPaused = !_isPaused);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to ${_isPaused ? 'resume' : 'pause'} recording: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    _stopTimer();
    try {
      String? path;
      
      // Try to stop the recording
      try {
        path = await _recorderController.stop();
      } catch (e) {
        debugPrint('Error stopping recorder: $e');
        // Continue with the path we have
        path = _recordingPath;
      }
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
        });
      }
      
      // Verify the file exists
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          widget.onRecordingComplete(path, _recordingDuration);
          return;
        }
      }
      
      // If we get here, the file doesn't exist or is empty
      throw Exception('Recording file was not created or is empty');
      
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error stopping recording: $e');
      }
      rethrow;
    } finally {
      _recordingDuration = Duration.zero;
    }
  }

  void _startTimer() {
    _stopTimer();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && _isRecording && !_isPaused) {
        setState(() {
          _recordingDuration += const Duration(milliseconds: 100);
        });
      }
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waveform visualization
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: AudioWaveforms(
              key: _waveformKey,
              size: Size(MediaQuery.of(context).size.width - 100, 50),
              recorderController: _recorderController,
              waveStyle: WaveStyle(
                waveColor: widget.primaryColor,
                showDurationLabel: true,
                spacing: 4.0,
                durationStyle: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                ),
                showBottom: true,
                showTop: true,
                extendWaveform: true,
                backgroundColor: widget.backgroundColor.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Timer display
              Text(
                _recordingDuration.toFormattedString(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              
              // Record/Stop button
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.red : widget.primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              
              // Pause/Resume button (only visible when recording)
              if (_isRecording)
                GestureDetector(
                  onTap: _pauseResumeRecording,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.primaryColor.withOpacity(0.1),
                    ),
                    child: Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      color: widget.primaryColor,
                      size: 20,
                    ),
                  ),
                )
              else
                const SizedBox(width: 40), // Placeholder for layout
            ],
          ),
        ],
      ),
    );
  }
}
