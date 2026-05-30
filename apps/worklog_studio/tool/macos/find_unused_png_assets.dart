import 'dart:io';

void main() async {
  final assetsDir = Directory(
    '../../packages/worklog_studio_style_system/assets/images',
  );
  final libDir = Directory('lib');

  final assetFiles = assetsDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.png'))
      .toList();

  final libFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final libContent = StringBuffer();

  for (final file in libFiles) {
    libContent.write(await file.readAsString());
  }

  final content = libContent.toString();

  final unused = <String>[];
  final used = <String>[];

  for (final asset in assetFiles) {
    final name = asset.uri.pathSegments.last
        .replaceAll('.png', '')
        .replaceAll('-', '')
        .replaceAll('_', '');

    if (content.contains(name)) {
      used.add(asset.path);
    } else {
      unused.add(asset.path);
    }
  }

  print('✅ USED: ${used.length}');
  for (final u in used) {
    print(u);
  }
  print('❌ UNUSED: ${unused.length}\n');

  for (final u in unused) {
    print(u);

    // Uncomment to delete all unused
    //
    // final file = File(u);
    // if (file.existsSync()) {
    //   file.deleteSync();
    //   print('🗑 Deleted: $u');
    // }
  }
}
