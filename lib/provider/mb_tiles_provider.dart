// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:mbtiles/mbtiles.dart';
// import 'package:flutter_map/flutter_map.dart';

// class MbTilesProvider extends TileProvider {
//   final MbTiles mbtiles;
//   MbTilesProvider(this.mbtiles);

//   @override
//   ImageProvider<Object> getImage(
//     TileCoordinates coordinates,
//     TileLayer options,
//   ) {
//     // MBTiles uses TMS (y is flipped vs XYZ)
//     final int tmsY = (1 << coordinates.z.toInt()) - 1 - coordinates.y.toInt();

//     final tile = mbtiles.getTile(
//       z: coordinates.z.toInt(),
//       x: coordinates.x.toInt(),
//       y: tmsY, // ← flipped!
//     );

//     if (tile != null && tile.isNotEmpty) {
//       return MemoryImage(tile);
//     }

//     // Transparent fallback
//     return MemoryImage(_emptyTile);
//   }

//   // 1x1 transparent PNG fallback
//   static final Uint8List _emptyTile = base64Decode(
//     'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
//   );
// }
