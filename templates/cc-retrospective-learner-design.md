# cc-retrospective-learner 設計書

## 概要

セッションデータを活用したふりかえりベースの学習機構。
セッションふりかえり（transcript.jsonl）でLayer 1（観察）を実現し、
pain_count / success_count ベースの昇格でLayer 2-3（記憶・進化）を回す。

- 定期実行不要（日付チェックでセッション開始時に処理）
- ふりかえり・週次昇格はサブエージェントで実行（親コンテキスト保護）

## ふりかえり方式

セットアップ時に2つの方式から選択できる。

### 毎回方式

セッション開始時に「ふりかえりを実施しますか？」と確認し、承認されたら実行する。

- セッション開始時のコスト: 確認プロンプト + ふりかえり実行時間
- ふりかえり拒否時: 何も記録しない（次回のふりかえり対象になる）

### オンデマンド方式

セッション開始時は何もしない。ユーザーが「ふりかえり」等と指示した時にまとめて実行する。

- セッション開始時のコスト: ゼロ
- 未ふりかえりセッションをまとめて処理

## アーキテクチャ

### 毎回方式の処理フロー

```
セッション開始
  │
  ├─ ユーザーに確認「ふりかえりを実施しますか？」
  │   ├─ はい → 未ふりかえりセッション収集 → ふりかえり実行
  │   └─ いいえ → 何もしない
  │
  ├─ 未ふりかえりセッション収集
  │   ├─ reviewed_sessions.md から済み session_id を取得
  │   ├─ ~/.claude/projects/*/*.jsonl を列挙
  │   └─ 差分が未ふりかえり対象
  │
  ├─ session-reviewer 起動（サブエージェント）
  │   ├─ transcript を読んで4視点で分析
  │   ├─ short-term/ に記録
  │   ├─ 既存 feedback_*.md と照合 → カウント更新（経路A）
  │   ├─ 昇格候補を検出
  │   └─ reviewed_sessions.md に登録
  │
  ├─ 昇格候補があればユーザーに提案
  │
  ├─ last_weekly_review.txt 確認
  │   └─ 7日以上前なら weekly-promoter 起動（サブエージェント）
  │       ├─ short-term/ からパターン検出
  │       ├─ long-term/ に集約
  │       ├─ 新規 feedback_*.md 作成（経路B）
  │       ├─ user_*.md 作成/更新
  │       ├─ reinforce_count 更新
  │       ├─ 昇格候補を検出
  │       └─ 結果サマリーを返却
  │
  └─ 昇格候補があればユーザーに提案
```

### オンデマンド方式の処理フロー

```
ユーザーが「ふりかえり」と指示
  │
  ├─ 未ふりかえりセッション収集
  │   ├─ reviewed_sessions.md から済み session_id を取得
  │   ├─ ~/.claude/projects/*/*.jsonl を列挙
  │   └─ 差分が未ふりかえり対象（なければ終了）
  │
  ├─ session-reviewer 起動（サブエージェント）
  │   （毎回方式と同一）
  │
  ├─ 昇格候補があればユーザーに提案
  │
  ├─ last_weekly_review.txt 確認
  │   └─ 7日以上前なら weekly-promoter 起動（サブエージェント）
  │       （毎回方式と同一）
  │
  └─ 昇格候補があればユーザーに提案
```

### ふりかえりの4視点

| 視点 | 内容 |
|------|------|
| フィードバックと改善 | 修正された箇所 + 次回どうすべきか |
| 承認パターン | うまくいったこと・受け入れられた提案 |
| 意思決定と価値観 | 何を選び、なぜそう判断したか、何を重視しているか |
| 作業内容 | 何をやったか（事実の記録） |

### 未ふりかえりセッションの判定

- `~/.claude/projects/<project-key>/<session_id>.jsonl` が transcript ファイル
- `reviewed_sessions.md` に session_id が含まれていれば「済」
- 含まれていなければ「未ふりかえり」
- ファイルの mtime は使用しない（過去セッションの再開で変わるため）

### 昇格階段

#### 経路A（既知のフィードバック — session-reviewer）

```
transcript で既知の feedback_*.md に該当するフィードバックを検出
  → pain_count / success_count を直接更新
  → >= 3 で CLAUDE.md 昇格を提案
```

#### 経路B（新規パターン — weekly-promoter）

```
Lv.0 ふりかえり記録（short-term/）
  ↓ 週次でパターン検出
Lv.1 定着パターン（long-term/ → feedback_*.md 新規作成）
  ↓ pain_count >= 3 or success_count >= 3
Lv.2 CLAUDE.md ルール
```

#### CLAUDE.md → スキル/Hook 昇格（共通）

```
  ↓ pain: 昇格後も違反継続 / success: reinforce_count >= 3
Lv.3 スキル or Hook
  - 「毎回この手順」系 → スキル（~/.claude/commands/）
  - 「前後に必ずやる」系 → Hook（settings.json hooks）
```

## ファイル構成

| ファイル | 読む人 | 役割 |
|---------|--------|------|
| `CLAUDE.md` | Claude Code | ふりかえりプロトコルへの参照 + 学習済みルール（昇格先） |
| `cc-retrospective-learner.md` | Claude Code | プロトコル指示（方式に応じた内容がコピーされる） |
| `cc-retrospective-learner-design.md` | 人間 / Claude Code | 設計書（本ファイル） |
| `cc-retrospective-learner-mode.txt` | セットアップスクリプト | 選択された方式（`everytime` or `ondemand`） |
| `reviewed_sessions.md` | 人間 / session-reviewer | ふりかえり済みセッション一覧 |
| `last_weekly_review.txt` | Claude Code | 週次昇格の最終実行日 |
| `agents/session-reviewer.md` | Claude Code | セッションふりかえりサブエージェント定義 |
| `agents/weekly-promoter.md` | Claude Code | 週次昇格サブエージェント定義 |
| `projects/{key}/memory/short-term/` | session-reviewer / weekly-promoter | セッションごとのふりかえり記録（プロジェクト別） |
| `projects/{key}/memory/long-term/` | weekly-promoter | 週次で定着したパターン（プロジェクト別） |
| `projects/{key}/memory/feedback_*.md` | session-reviewer / weekly-promoter | 個別フィードバック（プロジェクト別） |
| `projects/{key}/memory/user_*.md` | weekly-promoter / Claude Code | ユーザー傾向（昇格対象外、プロジェクト別） |

## ファイルフォーマット仕様

### reviewed_sessions.md

```markdown
# ふりかえり済みセッション

| session_id | 日付 | プロジェクト | 概要 |
|-----------|------|-------------|------|
| abc123 | 2026-04-12 | project-name | 作業概要 |
```

- このファイルに session_id がある = ふりかえり済み
- session-reviewer がふりかえり完了時に追記する

### short-term/ ファイル

ファイル名: `YYYY-MM-DD_<session_id>.md`

```markdown
---
session_id: <session_id>
date: <セッション日時>
project: <プロジェクトパス>
---

## フィードバックと改善
（内容）

## 承認パターン
（内容）

## 意思決定と価値観
（内容）

## 作業内容
（内容）
```

### long-term/ ファイル

ファイル名: `pattern_<テーマ>.md`

```markdown
---
theme: <パターンのテーマ>
first_seen: <最初に検出された日付>
last_seen: <最後に検出された日付>
occurrences: <出現セッション数>
source_sessions:
  - <session_id_1>
  - <session_id_2>
---

## パターン概要
（パターンの説明）

## 該当するふりかえり抜粋
（各セッションからの関連部分）
```

### feedback_*.md

```markdown
---
name: <フィードバック名>
description: <1行の説明>
type: feedback
pain_count: <数値>
success_count: <数値>
reinforce_count: <数値>
promoted_to: <null | "claude-md" | "skill" | "hook">
---

<フィードバックの詳細内容>

**Why:** <なぜこれが重要か>
**How to apply:** <いつ・どこで適用すべきか>
```

### user_*.md

```markdown
---
name: <ユーザー傾向名>
description: <1行の説明>
type: user
---

<傾向の詳細>
```

### last_weekly_review.txt

```
YYYY-MM-DD
```

日付のみ。1行。weekly-promoter が実行後に更新する。

### cc-retrospective-learner-mode.txt

```
everytime
```

または

```
ondemand
```

方式名のみ。1行。セットアップスクリプトが作成する。

## セットアップ（別PC展開）

### 前提条件

- Claude Code がインストール済み
- `~/.claude/` ディレクトリが存在する
- bash が利用可能（Git Bash 等）

### 手順

```bash
# リポジトリをクローン
git clone https://github.com/<owner>/cc-retrospective-learner.git
cd cc-retrospective-learner

# 対話的にセットアップ（方式を選択）
bash cc-retrospective-learner-setup.sh install

# または方式を指定してセットアップ
bash cc-retrospective-learner-setup.sh install --mode=everytime
bash cc-retrospective-learner-setup.sh install --mode=ondemand
```

セットアップスクリプトが以下を実行する:
1. 既存ファイルのバックアップ（`~/.claude/backups/pre-cc-retrospective-learner/`）
2. 共通テンプレートファイルを `~/.claude/` にコピー
3. 方式に応じたプロトコルファイルを `~/.claude/cc-retrospective-learner.md` としてコピー
4. セットアップスクリプトを `~/.claude/` にコピー
5. 選択方式を `~/.claude/cc-retrospective-learner-mode.txt` に記録
6. CLAUDE.md に方式に応じたセクションを追記（マーカー付き）
7. 各プロジェクトの memory/ に short-term/, long-term/ ディレクトリを作成

### ロールバック

```bash
bash cc-retrospective-learner-setup.sh rollback
```

または手動: `~/.claude/backups/pre-cc-retrospective-learner/rollback.md` を参照。

ロールバックで消えるもの: 仕組み（プロトコル、サブエージェント定義、hooks、short-term/, long-term/）
ロールバックで残るもの: 学習成果（feedback_*.md, user_*.md, CLAUDE.md の昇格済みルール, 昇格済みスキル/Hook）

## 拡張ガイド

### 新しいデータソースの追加（例: Slack連携）

1. `~/.claude/agents/` に新しいサブエージェント定義を作成
   - 例: `slack-observer.md`
2. 出力先は `~/.claude/projects/{key}/memory/short-term/` に統一
   - 既存の short-term フォーマットに従う
3. `cc-retrospective-learner.md` にサブエージェント起動の条件を追加
4. weekly-promoter は short-term/ を読むだけなので変更不要

### 昇格先のカスタマイズ

- スキル: `~/.claude/commands/` にマークダウンファイルを追加
- Hook: `settings.json` の `hooks` セクションに追加（要ユーザー承認）
