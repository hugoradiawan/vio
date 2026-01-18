import 'package:equatable/equatable.dart';

/// A named width/height preset for creating and resizing frames.
class FramePreset extends Equatable {
  const FramePreset({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
  });

  final String id;
  final String name;
  final double width;
  final double height;

  String get sizeLabel => '${width.toInt()}×${height.toInt()}';

  @override
  List<Object?> get props => [id, name, width, height];
}

class FramePresetCategory extends Equatable {
  const FramePresetCategory({
    required this.name,
    required this.items,
  });

  final String name;
  final List<FramePreset> items;

  @override
  List<Object?> get props => [name, items];
}

/// Penpot-inspired presets + a few additions (Dribbble/plugin covers, etc.).
///
/// Source reference:
/// - penpot/common/src/app/common/pages/common.cljs (size-presets)
const framePresetCategories = <FramePresetCategory>[
  FramePresetCategory(
    name: 'iPhone',
    items: [
      FramePreset(
        id: 'iphone-16-pro',
        name: 'iPhone 16 Pro',
        width: 402,
        height: 874,
      ),
      FramePreset(id: 'iphone-16', name: 'iPhone 16', width: 393, height: 852),
      FramePreset(
        id: 'iphone-16-pro-max',
        name: 'iPhone 16 Pro Max',
        width: 440,
        height: 956,
      ),
      FramePreset(
        id: 'iphone-16-plus',
        name: 'iPhone 16 Plus',
        width: 430,
        height: 932,
      ),
      FramePreset(
        id: 'iphone-14-15-pro-max',
        name: 'iPhone 14 & 15 Pro Max',
        width: 430,
        height: 932,
      ),
      FramePreset(
        id: 'iphone-14-15-pro',
        name: 'iPhone 14 & 15 Pro',
        width: 393,
        height: 852,
      ),
      FramePreset(
        id: 'iphone-13-14',
        name: 'iPhone 13 & 14',
        width: 390,
        height: 844,
      ),
      FramePreset(
        id: 'iphone-13-13-pro',
        name: 'iPhone 13 / 13 Pro',
        width: 390,
        height: 844,
      ),
      FramePreset(
        id: 'iphone-13-pro-max',
        name: 'iPhone 13 Pro Max',
        width: 428,
        height: 926,
      ),
      FramePreset(
        id: 'iphone-14-plus',
        name: 'iPhone 14 Plus',
        width: 428,
        height: 926,
      ),
      FramePreset(
        id: 'iphone-13-mini',
        name: 'iPhone 13 mini',
        width: 375,
        height: 812,
      ),
      FramePreset(id: 'iphone-se', name: 'iPhone SE', width: 320, height: 568),
      FramePreset(
        id: 'iphone-11-pro-max',
        name: 'iPhone 11 Pro Max',
        width: 414,
        height: 896,
      ),
      FramePreset(
        id: 'iphone-11-xr',
        name: 'iPhone 11 / XR',
        width: 414,
        height: 896,
      ),
      FramePreset(
        id: 'iphone-11-pro-x',
        name: 'iPhone 11 Pro / X',
        width: 375,
        height: 812,
      ),
      FramePreset(
        id: 'iphone-8-plus',
        name: 'iPhone 8 Plus',
        width: 414,
        height: 736,
      ),
      FramePreset(id: 'iphone-8', name: 'iPhone 8', width: 375, height: 667),
    ],
  ),
  FramePresetCategory(
    name: 'Android',
    items: [
      FramePreset(
        id: 'android-compact',
        name: 'Android Compact',
        width: 412,
        height: 917,
      ),
      FramePreset(
        id: 'android-medium',
        name: 'Android Medium',
        width: 700,
        height: 840,
      ),
      FramePreset(
        id: 'android-expanded',
        name: 'Android Expanded',
        width: 1280,
        height: 800,
      ),
      FramePreset(
        id: 'android-small',
        name: 'Android Small',
        width: 360,
        height: 640,
      ),
      FramePreset(
        id: 'android-large',
        name: 'Android Large',
        width: 360,
        height: 800,
      ),
      FramePreset(
        id: 'google-pixel-2',
        name: 'Google Pixel 2',
        width: 411,
        height: 731,
      ),
      FramePreset(
        id: 'google-pixel-2-xl',
        name: 'Google Pixel 2 XL',
        width: 411,
        height: 823,
      ),
    ],
  ),
  FramePresetCategory(
    name: 'Tablet',
    items: [
      FramePreset(
        id: 'ipad-mini-8-3',
        name: 'iPad mini 8.3',
        width: 744,
        height: 1133,
      ),
      FramePreset(
        id: 'ipad-mini-5',
        name: 'iPad mini 5',
        width: 768,
        height: 1024,
      ),
      FramePreset(
        id: 'ipad-pro-11',
        name: 'iPad Pro 11"',
        width: 834,
        height: 1194,
      ),
      FramePreset(
        id: 'ipad-pro-12-9',
        name: 'iPad Pro 12.9"',
        width: 1024,
        height: 1366,
      ),
      FramePreset(
        id: 'surface-pro-8',
        name: 'Surface Pro 8',
        width: 1440,
        height: 960,
      ),
      FramePreset(
        id: 'surface-pro-4',
        name: 'Surface Pro 4',
        width: 1368,
        height: 912,
      ),
    ],
  ),
  FramePresetCategory(
    name: 'Desktop',
    items: [
      FramePreset(
        id: 'macbook-air',
        name: 'MacBook Air',
        width: 1280,
        height: 832,
      ),
      FramePreset(
        id: 'macbook-pro-14',
        name: 'MacBook Pro 14"',
        width: 1512,
        height: 982,
      ),
      FramePreset(
        id: 'macbook-pro-16',
        name: 'MacBook Pro 16"',
        width: 1728,
        height: 1117,
      ),
      FramePreset(id: 'macbook', name: 'MacBook', width: 1152, height: 700),
      FramePreset(
        id: 'macbook-pro',
        name: 'MacBook Pro',
        width: 1440,
        height: 900,
      ),
      FramePreset(
        id: 'surface-book',
        name: 'Surface Book',
        width: 1500,
        height: 1000,
      ),
      FramePreset(id: 'desktop', name: 'Desktop', width: 1440, height: 1024),
      FramePreset(
        id: 'wireframes',
        name: 'Wireframes',
        width: 1440,
        height: 1024,
      ),
      FramePreset(id: 'imac', name: 'iMac', width: 1280, height: 720),
      FramePreset(
        id: 'macintosh-128k',
        name: 'Macintosh 128k',
        width: 512,
        height: 342,
      ),
    ],
  ),
  FramePresetCategory(
    name: 'Watch',
    items: [
      FramePreset(
        id: 'apple-watch-series-small',
        name: 'Apple Watch Series (small)',
        width: 187,
        height: 223,
      ),
      FramePreset(
        id: 'apple-watch-series-large',
        name: 'Apple Watch Series (large)',
        width: 208,
        height: 248,
      ),
      FramePreset(
        id: 'apple-watch-45mm',
        name: 'Apple Watch 45mm',
        width: 198,
        height: 242,
      ),
      FramePreset(
        id: 'apple-watch-44mm',
        name: 'Apple Watch 44mm',
        width: 184,
        height: 224,
      ),
      FramePreset(
        id: 'apple-watch-41mm',
        name: 'Apple Watch 41mm',
        width: 176,
        height: 215,
      ),
      FramePreset(
        id: 'apple-watch-42mm',
        name: 'Apple Watch 42mm',
        width: 156,
        height: 195,
      ),
      FramePreset(
        id: 'apple-watch-40mm',
        name: 'Apple Watch 40mm',
        width: 162,
        height: 197,
      ),
      FramePreset(
        id: 'apple-watch-38mm',
        name: 'Apple Watch 38mm',
        width: 136,
        height: 170,
      ),
    ],
  ),
  FramePresetCategory(
    name: 'Media',
    items: [
      FramePreset(id: 'tv-720p', name: 'TV', width: 1280, height: 720),
      FramePreset(
        id: 'slide-16-9',
        name: 'Slide 16:9',
        width: 1920,
        height: 1080,
      ),
      FramePreset(id: 'slide-4-3', name: 'Slide 4:3', width: 1024, height: 768),
    ],
  ),
  FramePresetCategory(
    name: 'Print',
    items: [
      FramePreset(id: 'a4', name: 'A4', width: 595, height: 842),
      FramePreset(id: 'a5', name: 'A5', width: 420, height: 595),
      FramePreset(id: 'a6', name: 'A6', width: 297, height: 420),
      FramePreset(id: 'letter', name: 'Letter', width: 612, height: 792),
      FramePreset(id: 'tabloid', name: 'Tabloid', width: 792, height: 1224),
    ],
  ),
  FramePresetCategory(
    name: 'Social',
    items: [
      FramePreset(
        id: 'twitter-post',
        name: 'Twitter post',
        width: 1200,
        height: 675,
      ),
      FramePreset(
        id: 'twitter-header',
        name: 'Twitter header',
        width: 1500,
        height: 500,
      ),
      FramePreset(
        id: 'facebook-post',
        name: 'Facebook post',
        width: 1200,
        height: 630,
      ),
      FramePreset(
        id: 'facebook-cover',
        name: 'Facebook cover',
        width: 820,
        height: 312,
      ),
      FramePreset(
        id: 'instagram-post',
        name: 'Instagram post',
        width: 1080,
        height: 1350,
      ),
      FramePreset(
        id: 'instagram-story',
        name: 'Instagram story',
        width: 1080,
        height: 1920,
      ),
      FramePreset(
        id: 'dribbble-shot',
        name: 'Dribbble shot',
        width: 400,
        height: 300,
      ),
      FramePreset(
        id: 'dribbble-shot-hd',
        name: 'Dribbble shot HD',
        width: 800,
        height: 600,
      ),
      FramePreset(
        id: 'linkedin-cover',
        name: 'LinkedIn cover',
        width: 1584,
        height: 396,
      ),
      FramePreset(
        id: 'plugin-icon',
        name: 'Plugin icon',
        width: 128,
        height: 128,
      ),
      FramePreset(
        id: 'profile-banner',
        name: 'Profile banner',
        width: 1680,
        height: 240,
      ),
      FramePreset(
        id: 'plugin-file-cover',
        name: 'Plugin / file cover',
        width: 1920,
        height: 1080,
      ),
    ],
  ),
];

final Map<String, FramePreset> _presetById = {
  for (final category in framePresetCategories)
    for (final item in category.items) item.id: item,
};

FramePreset? framePresetById(String? id) {
  if (id == null) return null;
  return _presetById[id];
}
