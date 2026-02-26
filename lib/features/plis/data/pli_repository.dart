import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pli_runner/core/models/pli.dart';

class PliRepository {
  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/plis.json');
  }

  Future<List<Pli>> getAll() async {
    try {
      final file = await _file;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list
          .map((e) => Pli.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> save(Pli pli) async {
    final all = await getAll();
    final index = all.indexWhere((p) => p.id == pli.id);
    if (index >= 0) {
      all[index] = pli;
    } else {
      all.insert(0, pli);
    }
    await _writeAll(all);
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((p) => p.id == id);
    await _writeAll(all);
  }

  Future<void> _writeAll(List<Pli> plis) async {
    final file = await _file;
    await file.writeAsString(jsonEncode(plis.map((p) => p.toJson()).toList()));
  }
}
