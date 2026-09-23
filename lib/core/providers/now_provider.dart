import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injected DateTime.now() — override in tests with a fixed date.
///
/// Without this, tests depend on the machine's clock and would fail
/// if run at exactly midnight.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);
