import 'package:flutter/material.dart';

/// Brand assets (from the team's /assets folder, copied into the package).
abstract final class BrandAssets {
  static const logo = 'assets/images/ruangin_logo.webp';

  /// Same logo with transparent padding trimmed (for app bars / headers).
  static const logoCropped = 'assets/images/ruangin_logo_cropped.webp';
  static const icon = 'assets/images/ruangin_icon.webp';
  static const discuss = 'assets/images/Ruangin_discuss.webp';
  static const lecturer = 'assets/images/gambar_dosen.webp';

  /// Cropped from image/ui-ux/Hasil_cari1.png (below the search results).
  static const lecturerSitting = 'assets/images/dosen_duduk.png';

  /// Cropped from image/ui-ux/Tidak_ada_Hasil.png (empty search).
  static const noResults = 'assets/images/tidak_ada_hasil.png';
}

abstract final class BrandColors {
  /// Sampled from ruangin_icon.webp.
  static const primary = Color(0xFF0143F7);
  static const ink = Color(0xFF111827);
}
