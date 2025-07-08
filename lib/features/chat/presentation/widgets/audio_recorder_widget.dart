import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart' as audio_waveforms;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderWidget extends StatefulWidget {
  final Function(String path, Duration duration) onRecordingComplete;
  final Color primaryColor;
  final Color backgroundColor;

  const AudioRecorderWidget({
    Key? key,
    required this.onRecordingComplete,
    this.primaryColor = const Color(0xFF4F46E5),
    this.backgroundColor = Colors.white,
  }) : super(key: key);

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  audio_waveforms.RecorderController? _recorderController;
  bool _isRecording = false;
  bool _isPaused = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  bool _hasPermission = false;
  bool _isInitialized = false;
  Timer? _durationTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
        });
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _hasPermission = true;
      });
    }

    try {
      // Create and initialize recorder controller
      final controller = audio_waveforms.RecorderController();
      controller.androidEncoder = audio_waveforms.AndroidEncoder.aac;
      controller.androidOutputFormat = audio_waveforms.AndroidOutputFormat.mpeg4;
      controller.iosEncoder = audio_waveforms.IosEncoder.kAudioFormatMPEG4AAC;
      controller.sampleRate = 44100;
      
      if (mounted) {
        setState(() {
          _recorderController = controller;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing recorder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize audio recorder: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission || _recorderController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required to record audio'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Get temp directory for saving the recording
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
      
      // Start recording with waveform extraction
      await _recorderController!.record(path: _recordingPath);
      
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;
      });
      
      // Start a timer to track recording duration
      _startDurationTimer();
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pauseResumeRecording() async {
    if (_recorderController == null || !_isRecording) return;
    
    try {
      if (_isPaused) {
        // Resume recording
        await _recorderController!.record();
        
        setState(() {
          _isPaused = false;
        });
        
        // Restart the duration timer
        _startDurationTimer();
      } else {
        // Pause recording
        await _recorderController!.pause();
        
        // Pause the duration timer
        _durationTimer?.cancel();
        
        setState(() {
          _isPaused = true;
        });
      }
    } catch (e) {
      print('Error pausing/resuming recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pause/resume recording: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_recorderController == null) return;
    
    try {
      // Stop recording and get the path
      final path = await _recorderController!.stop();
      
      // Stop the duration timer
      _durationTimer?.cancel();
      _durationTimer = null;
      
      if (path != null && File(path).existsSync()) {
        // Call the callback with the recording path and duration
        widget.onRecordingComplete(path, _recordingDuration);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording failed or file not found'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && _isRecording && !_isPaused) {
        setState(() {
          _recordingDuration += const Duration(milliseconds: 100);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recorderController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Recording',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: _isRecording ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _formatDuration(_recordingDuration),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Waveform visualization
          _isInitialized && _recorderController != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: audio_waveforms.AudioWaveforms(
                  enableGesture: false,
                  size: Size(MediaQuery.of(context).size.width - 64, 50),
                  recorderController: _recorderController!,
                  waveStyle: audio_waveforms.WaveStyle(
                    waveColor: widget.primaryColor,
                    extendWaveform: true,
                    showMiddleLine: false,
                    spacing: 3,
                    waveThickness: 2,
                    showDurationLabel: false,
                    showBottom: true,
                    showTop: true,
                    scaleFactor: 100,
                  ),
                ),
              )
            : Container(
                width: MediaQuery.of(context).size.width - 64,
                height: 50,
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "Initializing recorder...",
                    style: TextStyle(
                      color: widget.primaryColor.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel button
              TextButton(
                onPressed: () {
                  if (_isRecording) {
                    _recorderController?.stop();
                  }
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Pause/Resume button (only show when recording)
              if (_isRecording)
                CircleAvatar(
                  radius: 24,
                  backgroundColor: widget.primaryColor.withOpacity(0.2),
                  child: IconButton(
                    icon: Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      color: widget.primaryColor,
                      size: 24,
                    ),
                    onPressed: _pauseResumeRecording,
                  ),
                ),
              // Record or Stop button
              CircleAvatar(
                radius: 28,
                backgroundColor: _isRecording ? Colors.red : widget.primaryColor,
                child: IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
