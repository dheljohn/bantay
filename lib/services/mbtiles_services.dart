// // Option A: Bundle in assets (only feasible if < ~100MB, so z0-z12 only)
// // pubspec.yaml: assets: - assets/luzon.mbtiles
// // then copy to documents dir on first launch:
// import 'dart:io';

// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
// import 'package:flutter/services.dart' show rootBundle;

// // Future<void> copyBundledMbTiles() async {
// //   final dir = await getApplicationDocumentsDirectory();
// //   final dest = File(
// //     p.join(dir.path, 'maps', 'osm-2020-02-10-v3.11_asia_philippines.mbtiles'),
// //   );
// //   if (!dest.existsSync()) {
// //     final data = await rootBundle.load(
// //       'assets/maps/osm-2020-02-10-v3.11_asia_philippines.mbtiles',
// //     );
// //     await dest.writeAsBytes(data.buffer.asUint8List());
// //   }
// // }

// Future<String> copyBundledMbTiles() async {
//   print("Copying bundled MBTiles to documents directory...");
//   final dir = await getApplicationDocumentsDirectory();

//   // Use your exact filename here
//   final String fileName = 'osm-2020-02-10-v3.11_asia_philippines.mbtiles';
//   final String localFilePath = p.join(dir.path, 'maps', fileName);

//   final File file = File(localFilePath);

//   if (!await file.exists()) {
//     await file.parent.create(recursive: true);

//     // This matches your project folder: assets/maps/osm...
//     final data = await rootBundle.load('assets/maps/$fileName');

//     await file.writeAsBytes(
//       data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
//       flush: true,
//     );
//   }

//   return file.path; // Pass this path to your MbTilesTileProvider
// }

// // Option B: Download from your own server on first launch (recommended for 1-3GB)
// Future<void> downloadMbTiles({
//   required void Function(double progress) onProgress,
// }) async {
//   final dir = await getApplicationDocumentsDirectory();
//   final dest = File(
//     p.join(
//       dir.path,
//       'assets',
//       'maps',
//       'osm-2020-02-10-v3.11_asia_philippines.mbtiles',
//     ),
//   );
//   if (dest.existsSync()) return; // Already downloaded

//   final client = http.Client();
//   final request = await client.send(
//     http.Request(
//       'GET',
//       Uri.parse(
//         'https://data.maptiler.com/my-extracts/?dataset=osm&division=asia/philippines',
//       ),
//     ),
//   );

//   final total = request.contentLength ?? 0;
//   int received = 0;
//   final sink = dest.openWrite();

//   await request.stream.listen((chunk) {
//     sink.add(chunk);
//     received += chunk.length;
//     if (total > 0) onProgress(received / total);
//   }).asFuture();

//   await sink.close();
//   client.close();
// }
