import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/app_notification.dart';

/// Persists received push notifications to a JSON file in the app's documents
/// directory, so the in-app notifications list survives restarts.
class NotificationStore {
  static const _max = 100;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/notifications.json');
  }

  Future<List<AppNotification>> all() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return list
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<AppNotification> items) async {
    try {
      final capped = items.take(_max).toList();
      final f = await _file();
      await f.writeAsString(jsonEncode(capped.map((e) => e.toJson()).toList()));
    } catch (_) {/* best-effort */}
  }
}
