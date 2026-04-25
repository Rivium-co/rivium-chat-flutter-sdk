import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// State of the voice recorder.
enum VoiceRecorderState {
  idle,
  recording,
  locked,
  cancelled,
}

/// Result of a voice recording.
class VoiceRecordingResult {
  final File file;
  final Duration duration;
  final List<double>? waveform;

  const VoiceRecordingResult({
    required this.file,
    required this.duration,
    this.waveform,
  });
}

/// A voice message recorder widget with hold-to-record and slide-to-cancel.
/// Similar to WhatsApp and Telegram voice recording.
///
/// Note: This widget provides the UI and gesture handling.
/// Actual audio recording requires a platform-specific implementation
/// (e.g., record package, flutter_sound, etc.)
class VoiceMessageRecorder extends StatefulWidget {
  /// Called when recording starts.
  final VoidCallback? onRecordingStart;

  /// Called when recording is cancelled.
  final VoidCallback? onRecordingCancel;

  /// Called when recording is completed with the result.
  final void Function(VoiceRecordingResult result)? onRecordingComplete;

  /// Called periodically during recording with current duration.
  final void Function(Duration duration)? onRecordingUpdate;

  /// Function to start recording. Should return the output file path.
  final Future<String> Function()? startRecording;

  /// Function to stop recording. Should return the recorded file.
  final Future<File?> Function()? stopRecording;

  /// Function to cancel recording.
  final Future<void> Function()? cancelRecording;

  /// Maximum recording duration.
  final Duration maxDuration;

  /// Minimum recording duration to be valid.
  final Duration minDuration;

  /// Slide distance to cancel (as fraction of screen width).
  final double cancelSlideThreshold;

  /// Slide distance to lock recording.
  final double lockSlideThreshold;

  /// The mic button icon.
  final IconData micIcon;

  /// The recording indicator color.
  final Color? recordingColor;

  /// The cancel indicator color.
  final Color? cancelColor;

  const VoiceMessageRecorder({
    super.key,
    this.onRecordingStart,
    this.onRecordingCancel,
    this.onRecordingComplete,
    this.onRecordingUpdate,
    this.startRecording,
    this.stopRecording,
    this.cancelRecording,
    this.maxDuration = const Duration(minutes: 5),
    this.minDuration = const Duration(seconds: 1),
    this.cancelSlideThreshold = 0.3,
    this.lockSlideThreshold = 0.15,
    this.micIcon = Icons.mic,
    this.recordingColor,
    this.cancelColor,
  });

  @override
  State<VoiceMessageRecorder> createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder>
    with SingleTickerProviderStateMixin {
  VoiceRecorderState _state = VoiceRecorderState.idle;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  double _dragOffsetX = 0;
  double _dragOffsetY = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startRecording() async {
    HapticFeedback.mediumImpact();

    if (widget.startRecording != null) {
      try {
        await widget.startRecording!();
      } catch (e) {
        debugPrint('Failed to start recording: $e');
        return;
      }
    }

    setState(() {
      _state = VoiceRecorderState.recording;
      _recordingDuration = Duration.zero;
      _dragOffsetX = 0;
      _dragOffsetY = 0;
    });

    _pulseController.repeat(reverse: true);

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration += const Duration(seconds: 1);
      });

      widget.onRecordingUpdate?.call(_recordingDuration);

      if (_recordingDuration >= widget.maxDuration) {
        _completeRecording();
      }
    });

    widget.onRecordingStart?.call();
  }

  void _updateDrag(DragUpdateDetails details) {
    if (_state != VoiceRecorderState.recording) return;

    setState(() {
      _dragOffsetX += details.delta.dx;
      _dragOffsetY += details.delta.dy;
    });

    final screenWidth = MediaQuery.of(context).size.width;

    // Check for cancel (slide left)
    if (_dragOffsetX < -screenWidth * widget.cancelSlideThreshold) {
      _cancelRecording();
    }

    // Check for lock (slide up)
    if (_dragOffsetY < -100 * widget.lockSlideThreshold) {
      _lockRecording();
    }
  }

  void _endDrag() {
    if (_state == VoiceRecorderState.recording) {
      _completeRecording();
    }
  }

  void _lockRecording() {
    HapticFeedback.lightImpact();
    setState(() {
      _state = VoiceRecorderState.locked;
    });
  }

  void _cancelRecording() async {
    HapticFeedback.lightImpact();

    _durationTimer?.cancel();
    _pulseController.stop();

    if (widget.cancelRecording != null) {
      await widget.cancelRecording!();
    }

    setState(() {
      _state = VoiceRecorderState.idle;
      _recordingDuration = Duration.zero;
    });

    widget.onRecordingCancel?.call();
  }

  void _completeRecording() async {
    if (_recordingDuration < widget.minDuration) {
      _cancelRecording();
      return;
    }

    _durationTimer?.cancel();
    _pulseController.stop();

    File? recordedFile;
    if (widget.stopRecording != null) {
      recordedFile = await widget.stopRecording!();
    }

    final previousDuration = _recordingDuration;

    setState(() {
      _state = VoiceRecorderState.idle;
      _recordingDuration = Duration.zero;
    });

    if (recordedFile != null) {
      widget.onRecordingComplete?.call(VoiceRecordingResult(
        file: recordedFile,
        duration: previousDuration,
      ));
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final recordingColor =
        widget.recordingColor ?? Theme.of(context).colorScheme.error;
    final cancelColor =
        widget.cancelColor ?? Theme.of(context).colorScheme.error;

    if (_state == VoiceRecorderState.idle) {
      return _buildIdleState(context);
    }

    if (_state == VoiceRecorderState.locked) {
      return _buildLockedState(context, recordingColor);
    }

    return _buildRecordingState(context, recordingColor, cancelColor);
  }

  Widget _buildIdleState(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (details) => _updateDrag(DragUpdateDetails(
        delta: details.offsetFromOrigin - Offset(_dragOffsetX, _dragOffsetY),
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      )),
      onLongPressEnd: (_) => _endDrag(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.micIcon,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildRecordingState(
    BuildContext context,
    Color recordingColor,
    Color cancelColor,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cancelProgress =
        (_dragOffsetX.abs() / (screenWidth * widget.cancelSlideThreshold))
            .clamp(0.0, 1.0);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Recording indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: recordingColor
                      .withValues(alpha: 0.5 + _pulseController.value * 0.5),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(_recordingDuration),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const Spacer(),

          // Slide to cancel indicator
          Opacity(
            opacity: 1 - cancelProgress,
            child: Row(
              children: [
                Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                Text(
                  'Slide to cancel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Lock indicator (slide up)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              Icon(
                Icons.keyboard_arrow_up,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Mic button (draggable)
          GestureDetector(
            onPanUpdate: _updateDrag,
            onPanEnd: (_) => _endDrag(),
            child: Transform.translate(
              offset: Offset(_dragOffsetX.clamp(-100.0, 0.0), 0),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    recordingColor,
                    cancelColor,
                    cancelProgress,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  cancelProgress > 0.8 ? Icons.delete : widget.micIcon,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedState(BuildContext context, Color recordingColor) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Recording indicator
          AnimatedBuilder(
            animation: _pulseController..repeat(reverse: true),
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: recordingColor
                      .withValues(alpha: 0.5 + _pulseController.value * 0.5),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(_recordingDuration),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const Spacer(),

          // Cancel button
          IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.delete_outline),
            color: Theme.of(context).colorScheme.error,
          ),

          // Send button
          IconButton.filled(
            onPressed: _completeRecording,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

/// A widget to display a voice message with waveform and playback controls.
class VoiceMessagePlayer extends StatefulWidget {
  /// The audio file to play.
  final File? file;

  /// URL of the audio file.
  final String? url;

  /// Duration of the audio.
  final Duration duration;

  /// Waveform data for visualization.
  final List<double>? waveform;

  /// Whether this message is from the current user.
  final bool isMe;

  /// Called when play/pause is toggled.
  final void Function(bool isPlaying)? onPlayPause;

  /// Called when seeking to a position.
  final void Function(Duration position)? onSeek;

  /// Current playback position.
  final Duration position;

  /// Whether audio is currently playing.
  final bool isPlaying;

  const VoiceMessagePlayer({
    super.key,
    this.file,
    this.url,
    required this.duration,
    this.waveform,
    this.isMe = false,
    this.onPlayPause,
    this.onSeek,
    this.position = Duration.zero,
    this.isPlaying = false,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  @override
  Widget build(BuildContext context) {
    final progress = widget.duration.inMilliseconds > 0
        ? widget.position.inMilliseconds / widget.duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: () => widget.onPlayPause?.call(!widget.isPlaying),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMe
                    ? Colors.white
                    : Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Waveform or progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.waveform != null)
                  _WaveformVisualizer(
                    waveform: widget.waveform!,
                    progress: progress,
                    isMe: widget.isMe,
                    onSeek: (p) {
                      final position = Duration(
                        milliseconds:
                            (widget.duration.inMilliseconds * p).round(),
                      );
                      widget.onSeek?.call(position);
                    },
                  )
                else
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: widget.isMe
                        ? Colors.white.withValues(alpha: 0.3)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(
                      widget.isMe
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(
                      widget.isPlaying ? widget.position : widget.duration),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _WaveformVisualizer extends StatelessWidget {
  final List<double> waveform;
  final double progress;
  final bool isMe;
  final void Function(double progress)? onSeek;

  const _WaveformVisualizer({
    required this.waveform,
    required this.progress,
    required this.isMe,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
        onSeek?.call(progress);
      },
      child: CustomPaint(
        size: const Size(double.infinity, 32),
        painter: _WaveformPainter(
          waveform: waveform,
          progress: progress,
          playedColor:
              isMe ? Colors.white : Theme.of(context).colorScheme.primary,
          unplayedColor: isMe
              ? Colors.white.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final barWidth = size.width / waveform.length;
    final maxHeight = size.height * 0.8;
    final centerY = size.height / 2;

    for (var i = 0; i < waveform.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final barProgress = i / waveform.length;
      final isPlayed = barProgress <= progress;

      final paint = Paint()
        ..color = isPlayed ? playedColor : unplayedColor
        ..strokeWidth = barWidth * 0.6
        ..strokeCap = StrokeCap.round;

      final height = waveform[i] * maxHeight;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveform != waveform;
  }
}
