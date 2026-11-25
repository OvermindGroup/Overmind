import 'package:audioplayers/audioplayers.dart';

import '../utils/log.dart';

/// Audible cue for a finished training run.
///
/// Owned by the UI layer rather than an API client, and disposed with the screen
/// that uses it.
class SoundCue {
  SoundCue({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  static const String trainingCompleteUrl =
      'https://dpoetry.com/test/games/package/files/constructFiles/Files/025832392-magic-idea-05.wav';

  final AudioPlayer _player;

  /// A remote cue can fail to download; the toast still reports completion, so
  /// the sound is best-effort.
  Future<void> playTrainingComplete() async {
    try {
      await _player.play(UrlSource(trainingCompleteUrl));
    } catch (error) {
      logError('playing the training-complete cue', error);
    }
  }

  void dispose() => _player.dispose();
}
