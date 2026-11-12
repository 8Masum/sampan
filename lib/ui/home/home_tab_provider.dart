import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom navigation tabs of the home shell.
abstract final class HomeTab {
  static const int radar = 0;
  static const int chat = 1;
  static const int hub = 2;
}

/// Currently selected home tab, so sheets and empty states can switch tabs
/// (e.g. "Invite via Hub" on the radar jumps to the Hub tab).
final StateProvider<int> homeTabIndexProvider =
    StateProvider<int>((Ref ref) => HomeTab.radar);
