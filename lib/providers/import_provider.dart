import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/services/import_service.dart';

final importServiceProvider =
    Provider<ImportService>((_) => ImportService());
