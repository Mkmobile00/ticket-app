import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/city.dart';

/// Persists the visitor's chosen city so it's remembered across launches.
class CityStore {
  static const _id = 'buleto_city_id';
  static const _name = 'buleto_city_name';
  static const _slug = 'buleto_city_slug';
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  Future<City?> read() async {
    final id = await _s.read(key: _id);
    final name = await _s.read(key: _name);
    if (id == null || name == null) return null;
    return City(id: int.tryParse(id) ?? 0, name: name, slug: await _s.read(key: _slug) ?? '');
  }

  Future<void> write(City? c) async {
    if (c == null) {
      await _s.delete(key: _id);
      await _s.delete(key: _name);
      await _s.delete(key: _slug);
      return;
    }
    await _s.write(key: _id, value: c.id.toString());
    await _s.write(key: _name, value: c.name);
    await _s.write(key: _slug, value: c.slug);
  }
}
