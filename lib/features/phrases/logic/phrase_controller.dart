import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/phrase_book.dart';
import '../../../core/services/speech_service.dart';
import '../data/phrase_repository.dart';

final phraseRepositoryProvider =
    Provider<PhraseRepository>((ref) => PhraseRepository());

final speechServiceProvider = Provider<SpeechService>((ref) {
  final speech = SpeechService();
  ref.onDispose(speech.stop);
  return speech;
});

/// The bundled phrasebook, loaded once.
final phraseBookProvider = FutureProvider<PhraseBook>(
    (ref) => ref.watch(phraseRepositoryProvider).load());

/// Ids of the phrases the user marked as known, per language code.
final knownPhrasesProvider =
    AsyncNotifierProvider.family<KnownPhrasesController, Set<String>, String>(
        KnownPhrasesController.new);

class KnownPhrasesController extends AsyncNotifier<Set<String>> {
  KnownPhrasesController(this.language);

  final String language;

  @override
  Future<Set<String>> build() =>
      ref.watch(phraseRepositoryProvider).known(language);

  Future<void> setKnown(String phraseId, bool known) async {
    final ids = {...(state.value ?? const <String>{})};
    known ? ids.add(phraseId) : ids.remove(phraseId);
    state = AsyncData(ids);
    await ref.read(phraseRepositoryProvider).saveKnown(language, ids);
  }

  Future<void> reset() async {
    state = const AsyncData({});
    await ref.read(phraseRepositoryProvider).saveKnown(language, const {});
  }
}
