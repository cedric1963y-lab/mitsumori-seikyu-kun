import 'dart:io';

import 'package:mitsumori_seikyu/plan/limits.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

void main() {
  test('Info.plist has the Japanese name and no unused permission strings', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>見積・請求くん</string>'));
    expect(plist, contains('<key>ITSAppUsesNonExemptEncryption</key>'));
    expect(plist, isNot(contains('UsageDescription')));
    expect(plist, isNot(contains('UISupportedInterfaceOrientations~ipad')));
  });

  test('seal picker uses PHPicker, so no photo library permission text', () {
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(delegate, contains('PHPickerViewController'));
    expect(delegate, isNot(contains('PHPhotoLibrary')));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('image_picker')));
  });

  test('privacy manifest: no tracking, no collected data, in the target', () {
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    expect(privacy, contains('<key>NSPrivacyTracking</key>'));
    expect(privacy, contains('<false/>'));
    expect(privacy, contains('<key>NSPrivacyCollectedDataTypes</key>'));
    expect(privacy, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(
      project,
      contains('PRODUCT_BUNDLE_IDENTIFIER = ${PlanLimits.bundleId};'),
    );
    expect(project, contains('TARGETED_DEVICE_FAMILY = 1;'));
    expect(project, isNot(contains('shashinnippo')));
    expect(project, isNot(contains('dezura')));
  });

  test('StoreKit config matches the product ids and group', () {
    final store = File('ios/Runner/Products.storekit').readAsStringSync();
    expect(store, contains(PlanLimits.monthlyProductId));
    expect(store, contains(PlanLimits.yearlyProductId));
    expect(store, contains(PlanLimits.subscriptionGroupName));
    expect(store, contains('"recurringSubscriptionPeriod" : "P1M"'));
    expect(store, contains('"recurringSubscriptionPeriod" : "P1Y"'));
    expect(store, contains('"displayPrice" : "100"'));
    expect(store, contains('"displayPrice" : "1200"'));
    final scheme = File(
      'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
    ).readAsStringSync();
    expect(scheme, contains('Runner/Products.storekit'));
  });

  test('app icon is a full-bleed opaque 1024 image', () {
    final icon = im.decodePng(
      File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      ).readAsBytesSync(),
    );
    expect(icon, isNotNull);
    expect(icon!.width, 1024);
    expect(icon.height, 1024);
    expect(icon.numChannels, 3);
    final corner = icon.getPixel(0, 0);
    final center = icon.getPixel(512, 512);
    expect(corner.r != center.r || corner.g != center.g, isTrue);
  });

  test('legal links point at the Apple EULA and the published pages', () {
    expect(
      AppLinks.appleEula,
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
    );
    expect(
      AppLinks.privacy,
      'https://cedric1963y-lab.github.io/mitsumori-seikyu-kun/privacy.html',
    );
    for (final page in [
      'docs/index.html',
      'docs/privacy.html',
      'docs/terms.html',
    ]) {
      final html = File(page).readAsStringSync();
      expect(html, contains('かんたん見積・請求くん'));
      expect(html, contains('cedric1963y@ezweb.ne.jp'));
      expect(html, contains(PlanLimits.bundleId));
    }
    expect(
      File('docs/terms.html').readAsStringSync(),
      contains(AppLinks.appleEula),
    );
  });

  test('store description ends with the EULA and privacy lines', () {
    final meta = File('store/metadata-ja.md').readAsStringSync();
    final start = meta.indexOf('## 概要');
    final end = meta.indexOf('## ', start + 5);
    final description = meta.substring(start, end).trim().split('\n');
    expect(
      description[description.length - 2],
      '利用規約（EULA）: ${AppLinks.appleEula}',
    );
    expect(description.last, 'プライバシーポリシー: ${AppLinks.privacy}');
    final promoStart = meta.indexOf('## プロモーションテキスト');
    final promo = meta.substring(
      promoStart,
      meta.indexOf('## ', promoStart + 5),
    );
    expect(promo, isNot(contains('¥')));
    expect(promo, isNot(contains('円')));
  });
}
