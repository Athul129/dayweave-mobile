import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/providers.dart';

final currentUserIdProvider = Provider<String?>((ref) => ref.watch(authServiceProvider).currentUser?.id);
