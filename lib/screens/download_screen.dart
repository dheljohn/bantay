// import 'package:flutter/material.dart';
// import '../services/tile_cache_service.dart';

// class DownloadScreen extends StatelessWidget {
//   const DownloadScreen({super.key});

//   Future<String> _getCacheSize() async {
//     return await TileCacheService.getCacheSize();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<String>(
//       future: _getCacheSize(),
//       builder: (context, snapshot) {
//         final cacheSize = snapshot.data ?? '';

//         return Container(
//           height: 166,
//           width: 300,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(15),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withOpacity(0.5),
//                 spreadRadius: 5,
//                 blurRadius: 7,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               const Text(
//                 'Luzon Island  •  Zoom 5–15',
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
//               ),

//               const Text('~900,000 tiles  •  Est. 2–4 GB'),
//               const Text('Use WiFi — may take several hours'),
//               const SizedBox(height: 5),
//               if (cacheSize.isNotEmpty)
//                 Text(
//                   'Currently cached: $cacheSize',
//                   style: const TextStyle(color: Colors.green),
//                 ),

//               TextButton(
//                 onPressed: () {
//                   TileCacheService.clearCache();
//                 },
//                 child: const Text('Clear cache'),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
