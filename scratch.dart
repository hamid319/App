import 'package:flutter_riverpod/flutter_riverpod.dart';

final p = NotifierProvider<MyNotifier, int>(MyNotifier.new);
class MyNotifier extends Notifier<int> {
  @override
  int build() => 0;
}

void main() {
  final container = ProviderContainer();
  container.read(p.notifier).state = 1;
  print(container.read(p));
}
