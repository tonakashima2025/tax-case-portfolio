# 税務案件管理システム (Tax Case Portfolio)

採用担当者向けポートフォリオプロジェクト

## プロジェクト概要

このプロジェクトは、税理士事務所向けの案件管理システムをSalesforceプラットフォーム上で構築したポートフォリオです。税務申告の期限管理と業務タスクの自動化により、効率的な申告業務をサポートします。

## 主要機能

### 1. 申告案件クイック作成 (Lightning Web Component)
- **ファイル**: `force-app/main/default/lwc/taxCaseQuickCreate/`
- **機能**:
  - アカウント（顧客）ページから申告案件を迅速に作成
  - 申告種別選択により期限を自動計算
  - 決算月に基づく正確な月末期限設定

#### 技術的特徴
- 税目別期限計算ロジック（法人税・消費税：決算月+2ヶ月末日）
- タイムゾーンセーフな日付処理
- リアルタイムバリデーション

### 2. 自動タスク生成機能 (Apex)
- **ファイル**: `force-app/main/default/classes/TaxCaseTaskGenerator.cls`
- **機能**:
  - 申告案件作成時に必要業務タスクを自動生成
  - Custom Metadataベースの柔軟なタスクテンプレート設定
  - 営業日ベースの期日計算

#### 技術的特徴
- トリガーハンドラパターン実装
- Custom Metadataを活用した設定外部化
- フォールバック機能付きのデフォルトタスク

### 3. 設定可能なタスクテンプレート (Custom Metadata)
- **ファイル**: `force-app/main/default/customMetadata/Tax_Task_Template.*.md-meta.xml`
- **機能**:
  - 税目別のタスクテンプレート管理
  - 期限前日数とソート順の設定
  - コード修正不要な業務設定変更

## 技術スタック

- **プラットフォーム**: Salesforce Lightning Platform
- **フロントエンド**: Lightning Web Components (LWC)
- **バックエンド**: Apex
- **設定管理**: Custom Metadata Types
- **テスト**: Apex Test Classes
- **開発環境**: Salesforce CLI, Visual Studio Code

## アーキテクチャ設計の特徴

### 1. 保守性の重視
- Custom Metadataによる設定の外部化
- 単一責任原則に基づくクラス設計
- 包括的なエラーハンドリング

### 2. ユーザビリティの追求
- 直感的なUI/UX設計
- リアルタイムフィードバック
- アクセシビリティ対応

### 3. 拡張性の確保
- モジュラー設計
- 設定ベースのカスタマイズ
- 新税目への対応容易性

## プロジェクト構成

```
force-app/main/default/
├── lwc/taxCaseQuickCreate/          # Lightning Web Component
│   ├── taxCaseQuickCreate.html      # UIテンプレート
│   ├── taxCaseQuickCreate.js        # ロジック実装
│   └── taxCaseQuickCreate.js-meta.xml # メタデータ設定
├── classes/                         # Apex クラス
│   ├── TaxCaseTaskGenerator.cls     # タスク生成ロジック
│   └── TaxCaseTaskGeneratorTest.cls # テストクラス
└── customMetadata/                  # Custom Metadata
    └── Tax_Task_Template.*.md-meta.xml # タスクテンプレート
```

## テスト実装

- **テストカバレッジ**: 100%を目標とした包括的テスト
- **テストシナリオ**:
  - 正常フロー（各税目の期限計算）
  - エラーハンドリング（データ未設定時の挙動）
  - Custom Metadataフォールバック機能

## 開発・運用コマンド

```bash
# Linting
npm run lint

# テスト実行
npm run test

# フォーマット
npm run prettier

# デプロイ
sf project deploy start --source-dir force-app
```

## デモンストレーション

このシステムにより実現される業務改善：

1. **手作業削減**: 申告案件作成から必要タスク生成まで自動化
2. **期限管理精度向上**: 税目別の正確な期限計算
3. **業務標準化**: テンプレートベースの一貫した業務フロー
4. **カスタマイズ性**: ノーコードでの設定変更対応

## 技術的ハイライト

### 日付計算の精度
```javascript
// タイムゾーンセーフな日付フォーマット
const finalYear = deadline.getFullYear();
const finalMonth = String(deadline.getMonth() + 1).padStart(2, '0');
const finalDay = String(deadline.getDate()).padStart(2, '0');
return `${finalYear}-${finalMonth}-${finalDay}`;
```

### 営業日ベースの期日計算
```apex
// 土日を除外した営業日計算
private static Date addBusinessDays(Date startDate, Integer days) {
    // 土日スキップロジック実装
}
```

---

**開発者**: 中島敏夫
**作成目的**: Salesforce開発スキルのポートフォリオ
**開発期間**: 2025年9月
**ライセンス**: MIT License