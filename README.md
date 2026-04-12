# cc-retrospective-learner

ふりかえりをベースにした Claude Code の学習機構。

セッションの transcript を振り返り、フィードバックパターンを検出・蓄積し、一定回数を超えたパターンを CLAUDE.md ルールやスキル/Hook に昇格させるふりかえりベースの学習機構。

## 仕組み

### セッション開始時

1. **session-reviewer** サブエージェントが前回セッションの transcript を4視点で振り返り
2. 既知のフィードバックに該当するパターンがあれば pain_count / success_count を更新
3. 7日以上経過していれば **weekly-promoter** サブエージェントが週次でパターン集約・昇格候補を検出
4. 昇格候補はユーザーに提案（自動昇格はしない）

### 昇格階段

```
Lv.0 振り返り記録（short-term/）
  ↓ 週次でパターン検出
Lv.1 定着パターン（long-term/ → feedback_*.md）
  ↓ pain_count >= 3 or success_count >= 3
Lv.2 CLAUDE.md ルール
  ↓ 違反継続 or reinforce_count >= 3
Lv.3 スキル or Hook
```

### 振り返りの4視点

| 視点 | 内容 |
|------|------|
| フィードバックと改善 | 修正された箇所 + 次回どうすべきか |
| 承認パターン | うまくいったこと・受け入れられた提案 |
| 意思決定と価値観 | 何を選び、なぜそう判断したか |
| 作業内容 | 何をやったか（事実の記録） |

## セットアップ

### 前提条件

- Claude Code がインストール済み
- `~/.claude/` ディレクトリが存在する
- bash が利用可能（Windows の場合は Git Bash 等）

### インストール

```bash
git clone https://github.com/echolimitless/cc-retrospective-learner.git
cd cc-retrospective-learner
bash cc-retrospective-learner-setup.sh install
```

### ロールバック

```bash
bash cc-retrospective-learner-setup.sh rollback
```

スクリプトが動かない場合は `~/.claude/backups/pre-cc-retrospective-learner/rollback.md` を参照。

## ファイル構成

```
cc-retrospective-learner/
├── cc-retrospective-learner-setup.sh          # セットアップ兼ロールバックスクリプト
├── templates/                  # コピー元ファイル一式
│   ├── cc-retrospective-learner.md         # プロトコル指示
│   ├── cc-retrospective-learner-design.md  # 設計書
│   ├── agents/
│   │   ├── session-reviewer.md # セッション振り返りサブエージェント
│   │   └── weekly-promoter.md  # 週次昇格サブエージェント
│   ├── sessions.md             # セッション一覧テンプレート
│   ├── last_weekly_review.txt  # 週次レビュー日付の初期値
│   ├── rollback.md             # 手動ロールバック手順書
│   └── claude-md-section.md    # CLAUDE.md 追記内容
└── README.md
```

## 設計詳細

セットアップ後に `~/.claude/cc-retrospective-learner-design.md` に設計書が配置されます。

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
