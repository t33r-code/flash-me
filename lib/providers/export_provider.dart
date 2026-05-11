import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/services/export_service.dart';

// Provides the ExportService singleton — stateless, so a plain Provider is fine.
final exportServiceProvider = Provider<ExportService>((_) => ExportService());
