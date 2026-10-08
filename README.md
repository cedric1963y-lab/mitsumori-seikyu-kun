# かんたん見積・請求くん

一人親方・小規模の工事業者向けの iPhone アプリ。品目マスタから数量を入れて見積書を作り、1タップで請求書に変換、A4 縦の PDF を共有シート（LINE・メールなど）で送る。インボイス制度に合わせて税率ごとに対象額と消費税（書類ごと・税率ごとに1回、切り捨て）を出し、登録番号を印字する。状態（未送付／送付済／入金済）と未入金一覧つき。

- Bundle ID: `jp.mitsumori.app` / 1.0.0+1 / iPhone のみ / 日本語
- データは端末内の JSON（`Documents/mitsumori_seikyu`）。アカウント・サーバー・広告・解析なし
- サブスクリプション: `jp.mitsumori.app.premium.monthly`（¥100/月）、`jp.mitsumori.app.premium.yearly`（¥1,200/年）、グループ「かんたん見積・請求くん Premium」、1週間無料体験
- 無料: 取引先2件・品目10件・書類は月3件（見積→請求の変換は数えない）、PDF に小さくフッター。今月・先月の書類と未入金の請求書を表示
- プレミアム: 上限なし、フッターなし、印影・ロゴ、過去の書類の表示と検索、CSV
- 印影・ロゴは `PHPickerViewController`（`ios/Runner/AppDelegate.swift` の `SealPicker`）で選ぶため、写真ライブラリの権限文言は不要

## 開発

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
flutter pub get
flutter analyze
flutter test
```

`ios/Runner/Products.storekit` は Runner スキームのローカル StoreKit テスト用（ビルドには含まれない）。

## ストア用スクリーンショット

シミュレーター（iPhone 15 Pro など 1179×2556）を起動して:

```sh
tool/capture_app_store_screenshots.sh ~/Downloads/mitsumori-screenshots-raw
```

デバッグビルドだけが `SCREENSHOT*` の dart-define を読む（リリースでは無視）。サンプルデータは `tool/seed_demo_data.py`。

## ページ

`docs/` を GitHub Pages で公開: https://cedric1963y-lab.github.io/mitsumori-seikyu-kun/
（サポート / privacy.html / terms.html）

文案は `store/metadata-ja.md`。
