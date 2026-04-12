# cc-retrospective-learner

ふりかえりをベースにした Claude Code の学習機構。

## なぜ必要か

Claude Code の auto memory はセッション単位で記録を残すが、**セッションを跨いだパターン検出や昇格の仕組みがない**。同じ指摘を何度も繰り返したり、うまくいったアプローチが定着しないまま忘れられる。

cc-retrospective-learner は、セッションの transcript を自動で振り返り、繰り返されるフィードバック（痛み）や成功パターンを検出・蓄積し、閾値を超えたパターンを CLAUDE.md ルールやスキル/Hook に昇格させる。

> 着想元: [Claude Codeの進化的メモリ](https://zenn.dev/tokium_dev/articles/claude-code-evolutionary-memory)（Zenn記事）。Windows環境・Slack非依存・transcript活用に再設計。

## 仕組み

### セッション開始時の処理フロー

```
セッション開始
  │
  ├─ CLAUDE.md の指示で cc-retrospective-learner.md を読み込み
  │
  ├─ session-reviewer 起動（カスタムサブエージェント、フォアグラウンド）
  │   ├─ sessions.md から「未」セッションを確認
  │   ├─ transcript を読んで4視点で分析
  │   ├─ short-term/ に記録
  │   ├─ 既存 feedback_*.md と照合 → カウント更新（経路A）
  │   ├─ 昇格候補を検出
  │   ├─ sessions.md を更新
  │   └─ 結果サマリーを返却
  │
  ├─ 昇格候補があればユーザーに提案（承認必須）
  │
  ├─ last_weekly_review.txt 確認
  │   └─ 7日以上前なら weekly-promoter 起動
  │       ├─ short-term/ からパターン検出
  │       ├─ long-term/ に集約
  │       ├─ 新規 feedback_*.md 作成（経路B）
  │       ├─ reinforce_count 更新
  │       ├─ 昇格候補を検出
  │       └─ 結果サマリーを返却
  │
  └─ 昇格候補があればユーザーに提案（承認必須）
```

### 振り返りの4視点

| 視点 | 内容 |
|------|------|
| フィードバックと改善 | 修正された箇所 + 次回どうすべきか |
| 承認パターン | うまくいったこと・受け入れられた提案 |
| 意思決定と価値観 | 何を選び、なぜそう判断したか |
| 作業内容 | 何をやったか（事実の記録） |

該当なしの視点は省略される。

### 昇格階段

**経路A（既知のフィードバック — session-reviewer がセッション開始時に処理）:**
```
transcript で既知の feedback_*.md に該当するパターンを検出
  → pain_count / success_count を直接更新
  → >= 3 で CLAUDE.md 昇格を提案
```

**経路B（新規パターン — weekly-promoter が週次で処理）:**
```
Lv.0 振り返り記録（short-term/）
  ↓ 週次でパターン検出
Lv.1 定着パターン（long-term/ に集約 → feedback_*.md を新規作成）
  ↓ pain_count >= 3 or success_count >= 3
Lv.2 CLAUDE.md ルール
```

**CLAUDE.md → スキル/Hook 昇格（共通）:**
```
  ↓ pain: 昇格後も違反が継続 / success: reinforce_count >= 3
Lv.3 スキル or Hook（パターンの性質で振り分け）
  - 「毎回この手順」系 → スキル（~/.claude/commands/）
  - 「前後に必ずやる」系 → Hook（settings.json hooks）
```

**全ての昇格にユーザーの明示的な承認が必要。** 自動昇格はしない。

## 動作例

### session-reviewer が生成する振り返り記録（short-term/）

```markdown
---
session_id: 93e583ab-a55c-42cc-b4aa-96d0a62d3ab7
date: 2026-04-12 14:19
project: <プロジェクトパス>
---
## フィードバックと改善
- session-reviewer サブエージェントが sessions.md に存在しない過去セッションを
  勝手に追加してしまった問題が発覚。session-reviewer.md に「現在のセッション情報
  のみ登録。過去のセッションを探索・発見して追加してはならない」を明記した

## 承認パターン
- サブエージェントに tools: Read, Glob, Grep の frontmatter を追加する
  アプローチが承認された

## 意思決定と価値観
- サブエージェントが勝手に過去データを探索・追加することを明確に禁止
  → 制御可能性・予測可能性を重視
```

### 昇格提案のイメージ

```
session-reviewer の結果:
  - 振り返り: 1件完了
  - 昇格候補: feedback_no_background_agent.md (pain_count: 3)
    → サブエージェントをバックグラウンドで起動してはならない

CLAUDE.md に昇格しますか？ [y/n]
```

## セットアップ

### 前提条件

- Claude Code がインストール済み
- `~/.claude/` ディレクトリが存在する
- bash が利用可能（Windows の場合は Git Bash 等）
- `jq` がインストール済み（hooks で使用）

### インストール

```bash
git clone https://github.com/echolimitless/cc-retrospective-learner.git
cd cc-retrospective-learner
bash cc-retrospective-learner-setup.sh install
```

セットアップスクリプトが行うこと:

1. `~/.claude/CLAUDE.md` のバックアップを `~/.claude/backups/` に作成
2. テンプレートファイルを `~/.claude/` にコピー
   - `cc-retrospective-learner.md`（プロトコル指示）
   - `cc-retrospective-learner-design.md`（設計書）
   - `sessions.md`（セッション管理台帳）
   - `agents/session-reviewer.md`, `agents/weekly-promoter.md`（サブエージェント）
   - `hooks/guard-memory-write.sh`（書き込み先ガード）
3. 既存プロジェクトに `memory/short-term/`, `memory/long-term/` を作成
4. `CLAUDE.md` にマーカー付きセクションを追記

### ロールバック

```bash
bash cc-retrospective-learner-setup.sh rollback
```

- `CLAUDE.md` からマーカー間のセクションのみ削除（他の変更は保持）
- 追加したファイル・ディレクトリを削除
- スクリプトが動かない場合は `~/.claude/backups/pre-cc-retrospective-learner/rollback.md` に手動手順あり

## 安全性

### 書き込み先ガード

サブエージェント（session-reviewer, weekly-promoter）は PreToolUse フック（`guard-memory-write.sh`）により、書き込み先がホワイトリストに制限される:

- `sessions.md`
- `memory/short-term/`, `memory/long-term/`
- `memory/feedback_*.md`, `memory/user_*.md`, `memory/MEMORY.md`
- `last_weekly_review.txt`

これ以外のファイルへの Write/Edit はブロックされる。

### 人間承認

全ての昇格はユーザーの明示的な承認が必要。特に Hook 昇格は `settings.json` を変更するため、必ず確認される。

## ファイル構成

```
cc-retrospective-learner/
├── cc-retrospective-learner-setup.sh   # セットアップ兼ロールバックスクリプト
├── templates/                          # コピー元ファイル一式
│   ├── cc-retrospective-learner.md         # プロトコル指示
│   ├── cc-retrospective-learner-design.md  # 設計書
│   ├── agents/
│   │   ├── session-reviewer.md     # セッション振り返りサブエージェント
│   │   └── weekly-promoter.md      # 週次昇格サブエージェント
│   ├── hooks/
│   │   └── guard-memory-write.sh   # 書き込み先ガードスクリプト
│   ├── sessions.md                 # セッション一覧テンプレート
│   ├── last_weekly_review.txt      # 週次レビュー日付の初期値
│   ├── rollback.md                 # 手動ロールバック手順書
│   └── claude-md-section.md        # CLAUDE.md 追記内容
├── blog-material.md                # ブログ素材（設計プロセスの記録）
└── README.md
```

## 設計判断のポイント

| 判断 | 理由 |
|------|------|
| Slack連携なし、transcript活用 | transcript.jsonl にセッション全会話が入っており、Slackより精度が高い |
| サブエージェントで振り返り | 親コンテキストを消費しない。結果サマリーだけ返る |
| pain_count だけでなく success_count も | 「やめるべきこと」だけでなく「続けるべきこと」も学ぶ |
| コードブロックではなく自然言語で指示 | LLM はコードブロックを「参考情報」扱いしてパラメータを勝手に変える |
| フックで書き込み先を機械的にガード | LLM の指示ベースの制限には限界がある |
| 全昇格に人間承認必須 | 特に Hook 昇格は settings.json を変更するため |
| 定期実行の仕組み不要 | launchd/cron の代わりに日付チェックで代替 |

## 効果測定（2週間後）

### 成功（継続）
- pain_count が実際にインクリメントされたファイルが1つ以上
- short-term/ に振り返り記録が3件以上
- CLAUDE.md への昇格提案が1回以上

### 失敗（ロールバック）
- pain_count が一度も更新されていない
- short-term/ が空のまま
- セッション開始が明らかに遅くなり作業に支障

## ライセンス

MIT
