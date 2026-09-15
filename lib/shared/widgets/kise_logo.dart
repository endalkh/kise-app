/// The Kise mark: a flat gold coin stamped with ኪ.
///
/// ኪሴ means "my pocket", and the coin is what goes in it. The very same coin is the website's logo
/// and favicon (`backend/static/coin.svg`) and the launcher icon: the icons and the asset drawn here
/// are rendered from that SVG by `tool/icons/render.sh`, so the app and the website carry one mark.
/// Shipped as an image rather than painted, because the ኪ glyph needs an Ethiopic font and Android's
/// coverage is inconsistent.
library;

import 'package:flutter/material.dart';

class KiseLogo extends StatelessWidget {
  const KiseLogo({super.key, this.size = 32});

  /// Side of the square the coin is drawn in. The coin itself fills roughly 85% of it, the rest is
  /// the soft shadow baked into the asset.
  final double size;

  static const String asset = 'assets/brand/coin.png';

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Kise',
        excludeFromSemantics: false,
      );
}
