# 出店レジ — LIGHT REGISTER

iOS・Android向けの出店用レジです。Flutterで画面と処理をアプリ内に同梱し、商品・注文・売上を端末内のSQLiteに保存します。インストール後の初回起動から、インターネット接続もログインも不要です。

## 実装機能

- 商品の登録・編集：商品名、税込販売価格、カテゴリ、商品ボタンの色
- 商品の販売終了：レジから非表示にし、過去の売上は保持
- レジ：商品タップ、検索、カテゴリ選択、数量増減、注文クリア
- 現金会計：テンキー、ちょうど・定額預りボタン、預り不足の判定、釣り銭表示
- 売上一覧：日別、商品別、個々の会計履歴と明細
- 表示期間：今日、直近7日、今月、任意の日付範囲
- 永続化：商品・会計途中の注文・確定済み売上をアプリ再起動後に復元
- スマートフォン・タブレットの縦横画面に応じたレイアウト
- データ管理：全期間の売上記録消去、商品・注文・売上の全消去（確認画面付き）

## 利用手順

1. 初期画面の「最初の商品を登録」から商品名と販売価格を登録します。
2. レジで商品をタップします。1回のタップで1点追加します。
3. スマートフォンでは「注文を確認」を開きます。横幅の広い画面では注文を横に表示します。
4. 注文内容を確認し「お会計へ」を押します。
5. お預り金額を入力し、釣り銭を確認して「会計を確定する」を押します。
6. 完了画面に釣り銭を表示します。「次のお会計へ」で次の注文を開始します。
7. 「売上」で日別・商品別集計や会計履歴を確認します。

サンプル商品・架空の売上は初期データに入れていません。

商品一覧は検索欄・カテゴリを含めて縦にスクロールできます。横画面などで高さが足りない場合は、注文欄の見出し・明細・合計・会計ボタンもまとめてスクロールします。高さに余裕がある場合は、注文欄の見出しと合計・会計ボタンを固定表示します。

## データの消去

画面右上の歯車アイコン「データ管理」から操作します。対象を選び、確認画面の消去ボタンを押すと実行します。「キャンセル」では何も変更しません。

| 操作 | 消去するデータ | 残るデータ |
| --- | --- | --- |
| 売上記録消去 | 全期間の売上・会計明細（日別・商品別の集計元を含む） | 登録商品（販売終了済みも含む）、会計前の注文 |
| データ全消去 | 登録商品（販売終了済みも含む）、会計前の注文、全期間の売上・会計明細 | アプリ自体は残り、空の注文で再開 |

売上画面で選択した表示期間にかかわらず、売上記録消去は全期間が対象です。どちらもアプリからは取り消し・復元できません。処理はSQLiteトランザクション内で実行し、途中で失敗した場合は消去前の状態を維持します。成功後は売上表示を更新し、全消去ではレジを初期画面に戻します。

消去対象はこの端末のアプリ内データです。OSが保持するバックアップなどの外部コピーは対象外です。記憶媒体上のデータを復元不能にする物理的な完全消去を保証する機能ではありません。

## 保存・会計の仕様

- 通貨は日本円。金額は整数で扱い、小数点の丸め誤差を回避します。
- 販売価格は税込で入力します。税率の管理、消費税額の分離計算、インボイス発行は含みません。
- 商品単価：0〜999,999円。1明細の数量：1〜999点。合計・預り金額：0〜999,999,999円。
- 売上と注文クリアは同じSQLiteトランザクションで確定します。途中で保存に失敗すれば、両方をロールバックします。
- 注文IDを売上の主キーに使い、同じ注文の確定を再試行しても二重計上しません。
- 会計時の商品ID、商品名、単価、カテゴリ、数量を明細に記録します。商品編集・販売終了で過去の明細は変わりません。
- 未会計の商品も追加時点の単価を保持します。途中で価格を変更した商品を追加すると、別明細になります。
- 商品別集計は商品ID単位で価格変更前後を合算します。表示名は期間内の最後の会計で使用した名前です。同名の別商品は別集計です。
- 売上日は会計確定時の端末のローカル日付で固定し、時差も記録します。後から端末のタイムゾーンを変えても、記録済みの売上日は変わりません。
- 保存先はアプリ専用領域の `light_register.db` です。クラウドへの送信は実装していません。

## 開発・起動

開発環境は Flutter 3.47.3 / Dart 3.13.3 です。Flutterの対応範囲に合わせ、iOSの最低バージョンは15.0、Androidの最低APIレベルは24です。iOS 13・14は対象外になりました。更新後のiOSビルド・実行はMacでの再検証が必要です。

| ツール | 更新後のバージョン |
| --- | --- |
| Flutter / Dart | 3.47.3 / 3.13.3 |
| Gradle | 9.7.1（配布ZIPのSHA-256検証あり） |
| Android Gradle Plugin（AGP） | 9.4.0 |
| Kotlin | 2.4.20（AGPの組み込みKotlinを使用） |
| Androidビルド用JDK | Oracle JDK 26.0.2.1 |
| Android NDK | r30 / 30.0.16248370 |
| Android Studio | Quail 4 / 2026.1.4 |

AndroidのcompileSdk・targetSdkはFlutter既定値の36を使用します。Java・Kotlinの出力バイトコードは既存のJava 11相当を維持し、ビルドを実行するJDKとは区別します。Flutterプラグインとの互換性のため `android.newDsl=false` を設定しています。

直接依存は `intl 0.20.3`、`path 1.9.1`、`sqflite 2.4.4`、`uuid 4.6.0`、開発用は `sqflite_common_ffi 2.4.3`、`flutter_lints 6.0.0` へ更新しました。間接依存の `material_color_utilities` と `test_api` はFlutter SDKの指定バージョンを使用します。別PCでは同じFlutterを導入し、`pubspec.lock` を保持して `flutter pub get` を実行してください。

```sh
flutter pub get
flutter run -d <device-id>
```

SQLiteプラグインを使用するため、対象はiOS・Androidです。Web向けの実装はありません。

```sh
# 静的解析とローカル自動テスト
flutter analyze
flutter test

# ネイティブSQLiteを含む端末・シミュレータ・エミュレータでの統合テスト
flutter test integration_test/register_test.dart -d <device-id>

# Android 16以降のタブレットなど、アプリから方向を固定できない端末
dart run tool/test_android_integration.dart <device-id>

# 開発用ビルド
flutter build apk --debug --target lib/main.dart
flutter build ios --simulator --debug --no-codesign --target lib/main.dart
```

### WindowsでAndroidを実行する場合

Androidのビルドには、Gradle 9.7.1とJDK 26.0.2.1を使用します。使用中のJavaは `flutter doctor -v` で確認できます。以前のGradle 8.12で発生した `What went wrong: 25.0.3`（`JavaVersion.parse` の例外）は、旧Gradleと新しいJavaの組み合わせによる問題でした。

JDK 26.0.2.1をインストールした後、次の設定でFlutterが使用するJavaを指定します。インストール先は各PCの実際のパスに置き換えてください。この設定はそのPCのFlutterプロジェクト全体に適用されます。Android Studioから直接Gradleを実行する場合も、Gradle JDKを同じJDKに設定してください。開いているIDEは設定後に再起動してください。

```sh
flutter config --jdk-dir "<JDK 26.0.2.1のインストール先>"
flutter doctor -v
flutter devices
flutter run -d <device-id> --target lib/main.dart
```

エミュレータはAndroid StudioのDevice Manager、または `flutter emulators --launch <emulator-id>` で起動します。`flutter emulators` の仮想端末IDと、起動後の `flutter devices` に表示される実行用端末IDは異なります。通常アプリは `lib/main.dart` を指定して実行してください。

Android 16以降を対象とするアプリでは、幅600dp以上の画面でアプリからの画面方向指定が無視されます。タブレットの統合テストは上記のDartスクリプトをプロジェクト直下で実行してください。PATH上の `flutter` と、`ANDROID_HOME`・`ANDROID_SDK_ROOT`・`android/local.properties` の順で見つけたSDKのADBを使い、端末を実際に回転させて画面サイズを検証します。終了時に元の回転設定を復元します。テスト中は対象端末をほかの操作に使用しないでください。アプリに方向固定の制限回避設定は追加していません。

参考：[GradleとJavaの互換性](https://docs.gradle.org/current/userguide/compatibility.html)、[Flutterで使用するJavaの指定](https://docs.flutter.dev/release/breaking-changes/android-java-gradle-migration-guide)、[画面方向指定の制約](https://api.flutter.dev/flutter/services/SystemChrome/setPreferredOrientations.html)、[Flutterの対応OS](https://docs.flutter.dev/reference/supported-platforms)。

## 構成

- `lib/domain/models.dart`：商品・注文・売上のモデル、金額検証、集計
- `lib/data/register_database.dart`：SQLiteスキーマ、保存、注文の版管理、会計トランザクション
- `lib/register_controller.dart`：画面状態と保存処理の排他制御
- `lib/ui/`：レジ、商品管理、会計、売上の画面
- `test/`：実SQLiteによる保存・会計検証とスマホ・タブレットの画面操作検証
- `integration_test/`：iOS・Androidネイティブプラグインを通した操作・再接続検証
- `tool/test_android_integration.dart`：ADBで画面を回転させるAndroid統合テスト実行スクリプト

## 更新前の確認結果（2026-09-11、Flutter 3.35.7）

- `flutter analyze`：指摘なし
- ローカル自動テスト23件：成功（実SQLiteによる16件、スマホ・タブレット画面操作7件）。消去機能に加え、844×390・667×375の横画面で12商品を含む注文の数量変更・会計・釣り銭表示、画面回転時の注文・検索の保持、安全領域と文字1.3倍での操作を検証
- iPhone 16 / iOS 18.4シミュレータの統合テスト：横画面への回転・数量変更・会計、売上消去・全消去を含めて成功
- Pixel 8 Pro / Android API 36エミュレータの統合テスト：機内モードON・Wi-Fi OFFで横画面への回転・数量変更・会計、売上消去・全消去を含めて成功
- iOSシミュレータ向けdebugビルド、Android debug APKビルド：成功
- 初回実装時に両OSへインストールし、通常アプリの初期画面と表示を確認済み。追加した消去画面は上記の画面操作・統合テストで検証

統合テストは商品登録、SQLiteの接続を閉じて再オープンした注文復元、横画面での数量増減・会計・釣り銭表示、縦画面への復帰、確定売上の再読込、売上消去後の商品・注文の保持、全消去後の初期状態を確認します。実機、OSによるプロセス強制終了、ストア配布・署名は未検証です。

### 更新前のWindowsでの追加確認（2026-09-11、Flutter 3.41.2）

- 環境：Windows 11、Flutter 3.41.2 / Dart 3.11.0、Temurin JDK 21.0.12.1、Gradle 8.12。
- Java 25.0.3でのビルド失敗を再現し、FlutterのJDK設定を21へ変更して解消。初回ビルドで不足していたNDK 28.2.13676358・Build Tools 35.0.0・CMake 3.22.1も取得。
- `flutter build apk --debug --target lib/main.dart --no-pub` と `flutter run --debug --no-pub -d <device-id> --target lib/main.dart`：成功。
- Android 16（API 36）の10.1インチ仮想タブレット（1280×800、160dpi）で通常アプリをインストール・起動し、商品一覧と注文欄の初期表示を確認。確認時のAndroidRuntime / Flutterエラーログはなし。
- このWindows環境での追加確認はビルドと通常起動まで。上記のローカル自動テスト・統合テスト・iOS検証は今回再実行していない。`flutter doctor -v` のAndroidライセンス状態不明の警告は残っているが、必要なSDKのライセンスはビルド中に受諾済みと判定され、ビルド・起動は成功した。

## バージョン更新後の確認結果（2026-09-11、Windows）

- 上記のFlutter 3.47.3 / Dart 3.13.3 / JDK 26.0.2.1 / Gradle 9.7.1 / AGP 9.4.0 / Kotlin 2.4.20 / NDK r30で検証。Android Studioは既に2026.1.4だったため再インストールしていない。
- `flutter analyze --no-pub`：指摘なし。更新したFlutterで検出されたListTileの背景・タップ効果を隠す構造を、共通カードをMaterialに変更して修正した。
- `flutter test --no-pub`：23件成功（SQLite関連16件・画面操作7件）。小型スマホの横画面・タブレット・文字拡大を含む既存の操作テストを再実行した。
- `dart run tool/test_android_integration.dart <device-id>`：Android 16 / API 36の10.1インチタブレット（1280×800、160dpi）で成功。機内モードON・Wi-Fi OFFで、商品登録、注文復元、実際の画面回転、数量増減、会計・釣り銭、売上復元、売上消去、全消去を検証。独立した一時DBを使用し、終了後に通信・回転設定を復元した。
- Gradleの構成チェックが成功し、`kotlinCompilerClasspath` が2.4.20へ解決されることを確認。AGPより先に古いKotlinが読み込まれないよう、Kotlinの依存指定を `android/settings.gradle.kts` に配置した。
- 統合テスト後に `flutter build apk --debug --target lib/main.dart --no-pub`：成功。
- 通常の `lib/main.dart` をエミュレータへインストールして起動し、10.1インチ横画面の商品選択・注文欄の初期表示を確認。デバッガを切り離してアプリを起動状態で残した。確認時のFlutter / AndroidRuntimeエラーログはなし。
- `flutter doctor -v`：Android toolchain正常、Androidライセンス受諾済み。Windowsデスクトップ用Visual Studioの未導入のみ指摘されるが、このプロジェクトの対象OSには含めていない。
- 残る警告はGradleのJava native access、およびFlutterが使用するAGPの旧DSL・既存Jetifier設定の非推奨通知。ビルド失敗は発生していない。

iOSの最低バージョン設定はFlutterの移行処理に合わせ15.0へ更新し、plistのXML構文を確認した。WindowsではXcode/CocoaPodsを実行できないため、更新後のiOSビルド・統合テストと `ios/Podfile.lock` の再生成は未実施。Macでは `flutter pub get` の後に `cd ios && pod install` を実行し、プロジェクト直下へ戻ってiOSビルド・統合テストを行うこと。実機・ストア配布・署名も未検証。

## 配布と現状の範囲

現在のiOS Bundle IDは `jp.lightregister.lightRegister`、Android applicationIdは `jp.lightregister.light_register` です。配布前に組織の識別子・Apple署名チーム・Androidリリース署名を設定してください。Androidのrelease設定に開発用署名は流用していません。

現金以外の決済、決済端末連携、レシート印刷、返品・取消、在庫管理、複数端末の同期、バックアップの書き出し・復元は含みません。保存データはアプリの削除・端末初期化・端末故障で失われる可能性があります。OSによるバックアップはOSと端末の設定に依存し、アプリ自身では制御・保証しません。

実店舗での運用前に、対象実機の機内モードで商品登録・会計・強制終了後の復元を確認してください。日付と時刻は端末設定を使用します。

技術仕様の参考： [Flutterのオフライン設計](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)、[SQLiteによる永続化](https://docs.flutter.dev/cookbook/persistence/sqlite)、[sqflite](https://pub.dev/packages/sqflite)。
