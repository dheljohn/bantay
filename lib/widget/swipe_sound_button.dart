import 'dart:async';
import 'dart:math';
import 'package:bantay/widget/password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:real_volume/real_volume.dart';
import 'package:sliding_action_button/sliding_action_button.dart';
import 'package:torch_control/torch_control.dart';

class SwipeSoundButton extends StatefulWidget {
  const SwipeSoundButton({super.key});

  @override
  State<SwipeSoundButton> createState() => _SwipeSoundButtonState();
}

class _SwipeSoundButtonState extends State<SwipeSoundButton> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isDialogOpen = false;
  // bool _isTorchOn = false;
  String _password = "1010"; // replace with your secure password

  bool _isFlickering = false;
  Timer? _flickerTimer;
  final Random _random = Random();

  Future<void> _playSound() async {
    _startFlicker();
    // setState(() => _isTorchOn = true);
    setState(() => _isPlaying = true);

    // Load the sound asset
    await _player.setAsset('assets/sounds/alarm.mp3');

    // Force full volume (max) UNCOMMENT when apk release
    await RealVolume.setVolume(1.0, streamType: StreamType.MUSIC);

    // Loop indefinitely
    _player.setLoopMode(LoopMode.one);

    // Play
    await _player.play();
  }

  void _startFlicker() {
    //flashlight flickker
    if (_isFlickering) return;

    _isFlickering = true;

    _flickerTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (!_isFlickering) return;

      // Random flicker: torch on or off
      bool turnOn = _random.nextBool();

      if (turnOn) {
        await TorchControl.turnOn();
      } else {
        await TorchControl.turnOff();
      }
    });
  }

  void _stopFlicker() {
    _isFlickering = false;
    _flickerTimer?.cancel();
    TorchControl.turnOff(); // ensure torch off
  }

  // Future<void> _stopSound() async {
  //   bool correct = false;
  //   while (!correct) {
  //     correct = await _showPasswordDialog();
  //   }
  //   await _player.stop();
  //   setState(() => _isPlaying = false);
  // }

  @override
  Widget build(BuildContext context) {
    return CircleSlideToActionButton(
      width: 250,

      parentBoxRadiusValue: 27,
      circleSlidingButtonSize: 47,
      leftEdgeSpacing: 3,
      rightEdgeSpacing: 3,
      initialSlidingActionLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      finalSlidingActionLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),

      initialSlidingActionLabel:
          _isPlaying ? 'Slide again to Stop' : 'Slide to play siren',
      finalSlidingActionLabel:
          _isPlaying ? 'Release to Stop' : 'Release to Play',
      circleSlidingButtonIcon: Icon(
        Icons.volume_up,
        color: _isPlaying ? Colors.red : Colors.white,
      ),

      parentBoxBackgroundColor:
          _isPlaying ? Colors.red : Color.fromRGBO(18, 24, 43, 1),
      parentBoxDisableBackgroundColor: Colors.grey,
      circleSlidingButtonBackgroundColor:
          _isPlaying
              ? Color.fromRGBO(18, 24, 43, 1)
              : Color.fromRGBO(239, 68, 68, 1),
      isEnable: true,

      onSlideActionCompleted: () async {
        if (!_isPlaying) {
          await _playSound();
          return;
        }

        // Prevent double dialog
        if (_isDialogOpen) return;

        _isDialogOpen = true;

        final correct = await PasswordDialog.show(
          context,
          correctPassword: _password,
        );

        if (!mounted) {
          _isDialogOpen = false;
          return;
        }

        if (correct && _isPlaying) {
          _stopFlicker();
          await _player.stop();
          setState(() => _isPlaying = false);
        }

        _isDialogOpen = false;
      },

      onSlideActionCanceled: () async {
        // if (_isPlaying) {
        //   final correct = await _showPasswordDialog();
        //   if (correct) {
        //     await _player.stop();
        //     setState(() => _isPlaying = false);
        //   }
        // }
      },
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _stopFlicker();

    super.dispose();
  }
}


// GestureDetector(
    //   onHorizontalDragUpdate: (details) {
    //     _dragDistance += details.delta.dx;
    //   },
    //   onHorizontalDragEnd: (details) {
    //     if (_dragDistance.abs() > 100) {
    //       // require real swipe distance
    //       if (!_isPlaying) {
    //         _playSound();
    //       } else {
    //         _stopSound();
    //       }
    //     }
    //     _dragDistance = 0; // reset
    //   },
    //   child: Container(
    //     padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
    //     decoration: BoxDecoration(
    //       color: _isPlaying ? Colors.red : Colors.green,
    //       borderRadius: BorderRadius.circular(12),
    //     ),
    //     child: Center(
    //       child: Text(
    //         _isPlaying ? 'Swipe to Stop' : 'Swipe to Play',
    //         style: const TextStyle(color: Colors.white, fontSize: 18),
    //       ),
    //     ),
    //   ),
    // );