# ブログ素材: cc-retrospective-learner

## 1. 背景とモチベーション

### きっかけ
Zenn記事「Claude Codeの進化的メモリ」(https://zenn.dev/tokium_dev/articles/claude-code-evolutionary-memory) を読み、この手法を自分の環境に取り入れたいと思った。

### Zenn記事の概要
- 繰り返されるフィードバック（「痛み」）を `pain_count` で追跡し、閾値に達したらCLAUDE.mdルールやHookに自動昇格させる仕組み
- 3層構造: Layer 1（観察: Slack日次振り返り）→ Layer 2（記憶: daily→short-term→long-term）→ Layer 3（進化: pain_count≥3でCLAUDE.md/Hookへ昇格）
- macOS + launchd + Slack + node 前提

### 最初の課題
- 記事をそのまま持ってきても動かない（Windows環境、Slack連携なし、launchd不可）
- Claude Codeとの対話を通じて、記事のアイデアを自分の環境に合わせて再設計する必要があった

---

## 2. 設計プロセスの時系列（判断の理由付き）

### Phase 1: 最初のプラン（段階的導入）
- 記事の全要素を段階的に導入する計画を立てた
- ユーザーからの指摘: 「段階的にする意味がない。セッション跨ぎで文脈が引き継げないし、各段階の進行判断も曖昧」
- **判断**: 一括導入に変更

### Phase 2: Slack連携とLong-term Evolutionの除外
- Slack連携: 外部依存が増えるだけでコア機能に不要
- Long-term Evolution: 定期実行の仕組み（launchd/cron）がないと空回り
- **判断**: 動かない仕組みは最初から除外する
- **学び**: 外部手法を計画に入れる前に「何によって駆動されるか」を確認し、駆動源がない要素は除外する

### Phase 3: transcriptの発見
- SessionEnd Hookに `transcript_path` が渡されることを発見
- transcript.jsonl にはセッション中の全会話が記録されている
- **判断**: Slack連携の代わりにtranscriptからセッション振り返りを行う → Slackより精度が高い

### Phase 4: サブエージェントの導入
- 振り返りでtranscriptを読むと親のコンテキストを大量消費する問題
- **判断**: 振り返りをサブエージェントで実行し、親には結果サマリーだけ返す

### Phase 5: success_countの追加
- 元の記事は「痛み（失敗）」だけを追跡
- **判断**: 「良かったこと」も記録する。pain_countだけだと「何をやるな」は学ぶが「何をやれ」は学ばない

### Phase 6: セッション一覧（sessions.md）
- SessionEnd Hookを廃止し、全てセッション開始時に処理する方針に
- sessions.md でセッション管理。人間も読める台帳形式
- 振り返り完了後に自分のセッションを「未」で登録（自分自身を振り返り対象にしない）

### Phase 7: 経路A/Bの設計
- 経路A: 既知のフィードバック → session-reviewerが即座にpain_count更新（セッション開始時）
- 経路B: 新規パターン → short-term → weekly-promoterが週次でパターン検出 → feedback_*.md新規作成
- Zenn記事の「人間の睡眠中の記憶整理」を模倣（新規パターンは一定期間寝かせてから定着）

### Phase 8: reinforce_countとスキル/Hook昇格
- CLAUDE.md昇格後のさらなる昇格先としてスキル/Hookを追加
- pain: 昇格後も違反継続 → Hook（強制チェック）
- success: reinforce_count ≥ 3 → スキル（自動化）
- 振り分けはZenn記事と同じ「パターンの性質」で判定（「毎回この手順」→スキル、「前後に必ずやる」→Hook）

### Phase 9: セットアップスクリプトとリポジトリ化
- 別PCへの展開を考慮し、セットアップスクリプト（install/rollback）を作成
- rollback.md（手動手順書）も併設（スクリプトが動かない時の最終手段）
- CLAUDE.mdのロールバックはマーカー削除方式（セットアップ後の他の変更を保持）
- リポジトリ名: `cc-retrospective-learner`（「ふりかえりをベースにしたClaude Codeの学習機構」）

### Phase 10: 人間承認の明記
- 全ての昇格でユーザーの明示的な承認を必要とする
- 特にHook昇格はsettings.jsonを変更するため必ず承認を得る

---

## 3. 元のZenn記事との違い

| 項目 | Zenn記事 | cc-retrospective-learner |
|------|---------|--------------------------|
| データ収集 | Slack日常会話 + SessionEnd Hook | transcript.jsonl（セッション全会話） |
| 振り返りタイミング | 毎日19:00（launchd） | セッション開始時（サブエージェント） |
| 振り返りの実行者 | Claude Code本体（cron起動） | session-reviewerサブエージェント（コンテキスト保護） |
| 振り返りの視点 | 判断基準・口癖・価値観・コミュニケーションスタイル | フィードバックと改善・承認パターン・意思決定と価値観・作業内容 |
| pain_count更新 | セッション中にClaude Codeが即座に | 経路A: セッション開始時にsession-reviewerが / 経路B: 週次でweekly-promoterが |
| success_count | なし | あり |
| 新規パターン検出 | 週次cron（金曜20:00） | weekly-promoter（セッション開始時に日付チェック） |
| 定期実行の仕組み | launchd（macOS） | 不要（日付チェックで代替） |
| スキル/Hook昇格条件 | reinforce_count ≥ 3 | reinforce_count ≥ 3（success）+ 違反継続（pain） |
| セッション管理 | なし | sessions.md（人間も読める管理台帳） |
| 設計ドキュメント | なし（記事が設計書） | cc-retrospective-learner-design.md |
| ロールバック | なし | setup.sh + rollback.md（2段構え） |
| OS依存 | macOS（launchd） | なし |
| 書き込み先ガード | なし | PreToolUseフック（guard-memory-write.sh） |
| 別PC展開 | 手動 | セットアップスクリプト + リポジトリ |

---

## 4. 最終的な仕組みの全体像

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
  │   └─ 7日以上前なら weekly-promoter 起動（カスタムサブエージェント、フォアグラウンド）
  │       ├─ short-term/ からパターン検出
  │       ├─ long-term/ に集約
  │       ├─ 新規 feedback_*.md 作成（経路B）
  │       ├─ user_*.md 作成/更新
  │       ├─ reinforce_count 更新
  │       ├─ 昇格候補を検出
  │       └─ 結果サマリーを返却
  │
  └─ 昇格候補があればユーザーに提案（承認必須）
```

### 昇格階段

**経路A（既知のフィードバック — session-reviewer がセッション開始時に処理）:**
```
transcript で既知の feedback_*.md に該当するフィードバックを検出
  → pain_count / success_count を直接更新
  → ≥ 3 で CLAUDE.md 昇格を提案
```

**経路B（新規パターン — weekly-promoter が週次で処理）:**
```
Lv.0 振り返り記録（short-term/）
  ↓ 週次でパターン検出
Lv.1 定着パターン（long-term/ に集約 → feedback_*.md を新規作成）
  ↓ pain_count ≥ 3 or success_count ≥ 3
Lv.2 CLAUDE.md ルール
```

**CLAUDE.md → スキル/Hook 昇格（共通）:**
```
  ↓ pain: 昇格後も違反が継続 / success: reinforce_count ≥ 3
Lv.3 スキル or Hook（パターンの性質で振り分け）
  - 「毎回この手順」系 → スキル（~/.claude/commands/）
  - 「前後に必ずやる」系 → Hook（settings.json hooks）
```

### 振り返りの4視点
| 視点 | 内容 |
|------|------|
| フィードバックと改善 | 修正された箇所 + 次回どうすべきか |
| 承認パターン | うまくいったこと・受け入れられた提案 |
| 意思決定と価値観 | 何を選び、なぜそう判断したか、何を重視しているか |
| 作業内容 | 何をやったか（事実の記録） |

※ 該当なしの視点は省略する。無理に記載しない。

---

## 5. 実際のファイル内容

### ~/.claude/CLAUDE.md に追記する内容（claude-md-section.md）
```markdown
<!-- CC-RETROSPECTIVE-LEARNER-START -->

## cc-retrospective-learner（ふりかえりベースの学習機構）

**必須: ユーザーの最初のメッセージに応答する前に、必ず `~/.claude/cc-retrospective-learner.md` を Read ツールで読み込み、その指示をすべて実行すること。この処理を完了してからユーザーへの応答を開始すること。スキップ不可。**

<!-- CC-RETROSPECTIVE-LEARNER-END -->
```

### ~/.claude/cc-retrospective-learner.md（プロトコル指示）
```markdown
# cc-retrospective-learner プロトコル

セッション開始時に以下を実行する。

## 1. セッション振り返り

`session-reviewer` サブエージェントをフォアグラウンドで起動する。

**必須パラメータ:**
- subagent_type: "session-reviewer"（general-purposeにしないこと）
- prompt に以下を含める: 現在のsession_id、プロジェクトパス、project_memory_path（`~/.claude/projects/{project-key}/memory`）
- **バックグラウンド実行禁止。run_in_background を指定しないこと。**

session-reviewer の結果に昇格候補がある場合、ユーザーに提案する。
**ユーザーの明示的な承認なしに昇格を実行しない。**

## 2. 週次昇格チェック

`~/.claude/last_weekly_review.txt` の日付を確認し、7日以上経過していれば `weekly-promoter` サブエージェントをフォアグラウンドで起動する。

**必須パラメータ:**
- subagent_type: "weekly-promoter"（general-purposeにしないこと）
- prompt に project_memory_path を含める
- **バックグラウンド実行禁止。run_in_background を指定しないこと。**

weekly-promoter の結果に昇格候補がある場合、ユーザーに提案する。
**ユーザーの明示的な承認なしに昇格を実行しない。**
**特に Hook 昇格は settings.json を変更するため必ず承認を得る。**

## 注意事項

- 振り返り・週次昇格はサブエージェントで実行し、親コンテキストを消費しない
- サブエージェントからは結果サマリーだけを受け取る
- セッション中のカウント更新はしない（次のセッション開始時に session-reviewer が実施）
```

### ~/.claude/agents/session-reviewer.md
（ファイルが大きいので「実際のファイルは cc-retrospective-learner リポジトリの templates/agents/session-reviewer.md を参照」と記載。以下はfrontmatterと冒頭部分）
```markdown
---
name: session-reviewer
description: セッション振り返りを実行するサブエージェント。sessions.mdの未振り返りセッションを確認し、transcriptを4視点で分析してshort-termに記録する。
tools: Read, Glob, Grep, Write, Edit, Bash
hooks:
  PreToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "bash ~/.claude/hooks/guard-memory-write.sh"
    - matcher: "Edit"
      hooks:
        - type: command
          command: "bash ~/.claude/hooks/guard-memory-write.sh"
---

# session-reviewer サブエージェント

セッション開始時に呼び出され、前回セッションの振り返りを行うサブエージェント。

（以下略。リポジトリ参照）
```

### ~/.claude/agents/weekly-promoter.md
（同様にfrontmatterと冒頭部分）
```markdown
---
name: weekly-promoter
description: 週次昇格処理を実行するサブエージェント。short-termからパターン検出し、long-termに集約、feedback_*.mdの新規作成、昇格候補の検出を行う。
tools: Read, Glob, Grep, Write, Edit, Bash
hooks:
  PreToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "bash ~/.claude/hooks/guard-memory-write.sh"
    - matcher: "Edit"
      hooks:
        - type: command
          command: "bash ~/.claude/hooks/guard-memory-write.sh"
---

# weekly-promoter サブエージェント

（以下略。リポジトリ参照）
```

### ~/.claude/hooks/guard-memory-write.sh
```bash
#!/usr/bin/env bash
# サブエージェントの書き込み先をメモリ関連ファイルに限定するガードスクリプト
# PreToolUse フックとして使用。許可範囲外の Write/Edit をブロックする。

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

if [ -z "$file_path" ]; then
  exit 0
fi

# 許可するパスパターン
if echo "$file_path" | grep -qE '(sessions\.md|memory/(short-term|long-term)/|memory/feedback_|memory/user_|memory/MEMORY\.md|last_weekly_review\.txt)'; then
  exit 0
fi

# 許可範囲外 → ブロック
printf '{"continue":false,"stopReason":"書き込み先が許可範囲外です: %s"}' "$file_path"
```

### ~/.claude/sessions.md（テンプレート）
```markdown
# セッション一覧

| 日時 | session_id | プロジェクト | 概要 | 振り返り | transcript |
|------|-----------|-------------|------|---------|-----------|
```

### 実際に生成された振り返りファイル例（short-term/）
```markdown
---
session_id: 93e583ab-a55c-42cc-b4aa-96d0a62d3ab7
date: 2026-04-12 14:19
project: d:\Users\<username>\path\to\cc-retrospective-learner
originSessionId: e19d9293-c345-4e14-bf03-5c972047078f
---
## フィードバックと改善
- session-reviewer サブエージェントが sessions.md に存在しない過去セッションを勝手に追加してしまった問題が発覚。ユーザーの指示で sessions.md を修正し、session-reviewer.md に「現在のセッション情報のみ登録。過去のセッションを探索・発見して追加してはならない」を明記した

## 承認パターン
- サブエージェントに `tools: Read, Glob, Grep` の frontmatter を追加するアプローチが承認された
- Write/Edit は tools に含めず、ファイル書き込み時にユーザー承認を求める設計が承認された

## 意思決定と価値観
- サブエージェントが勝手に過去データを探索・追加することを明確に禁止 → 制御可能性・予測可能性を重視
- サブエージェントの権限は最小限にし、書き込み系は都度承認 → 最小権限の原則

## 作業内容
- echo "hello" の実行（動作確認テスト）
- 5つの修正タスクを実行
- サブエージェントの frontmatter に tools 指定を追加
```

---

## 6. テスト実施と問題解決のストーリー

### テスト1: session-reviewer が起動しない
- **問題**: CLAUDE.md に「session-reviewer.md を読め」と書いたが、Claude Code が無視した
- **原因**: 指示が弱すぎた（「セッション開始時に読み込むこと」程度）
- **解決**: 「ユーザーの最初のメッセージに応答する前に必ず実行。スキップ不可」と強い表現に変更
- **学び**: CLAUDE.md の指示は強い表現でないと従わない

### テスト2: バックグラウンド実行で権限エラー
- **問題**: サブエージェントをバックグラウンド（run_in_background: true）で起動すると、Read/Write等のツール使用権限が全て拒否される
- **原因**: バックグラウンドエージェントはユーザーに承認ダイアログを表示できないため、未許可のツールは自動拒否
- **解決**: フォアグラウンド実行に変更
- **学び**: バックグラウンドのサブエージェントには事前許可されたツールしか使えない

### テスト3: Claude Code が run_in_background: false を無視
- **問題**: cc-retrospective-learner.md に `run_in_background: false` と明記しても、Claude Code が `true` に変えてしまう
- **原因**: コードブロック内のパラメータをClaude Codeが「参考情報」として扱い、自分の判断で変更する
- **解決**: コードブロックを削除し、自然言語で「バックグラウンド実行禁止。run_in_background を指定しないこと」と指示
- **学び**: LLMにはコードブロックより自然言語の指示の方が効く場合がある

### テスト4: subagent_type が general-purpose にされる
- **問題**: `subagent_type: "session-reviewer"` と指定しても `general-purpose` で起動される
- **原因**: session-reviewer.md の frontmatter に `name` と `description` がなく、カスタムエージェントとして認識されなかった
- **解決**: frontmatter に `name: session-reviewer` と `description` を追加
- **学び**: カスタムエージェントの frontmatter には name と description が必須

### テスト5: サブエージェントが過去セッションを勝手に追加
- **問題**: session-reviewer が sessions.md にない過去セッションを見つけて勝手に追加した
- **原因**: session-reviewer.md に「自分のセッションだけ登録」の制約が明記されていなかった
- **解決**: 「現在のセッション情報のみ登録。過去のセッションを探索・発見して追加してはならない」を明記
- **学び**: サブエージェントは指示されていないことも「良かれと思って」やるので、やるなということも明記する必要がある

### テスト6: 書き込み先のガード
- **問題**: サブエージェントにWrite/Editを許可すると、メモリ関連以外のファイルにも書き込める
- **解決**: PreToolUseフック（guard-memory-write.sh）で書き込み先をホワイトリスト制限
- **学び**: LLMの指示ベースの制限には限界がある。機械的なガードを併用する

---

## 7. リポジトリ情報

- **リポジトリ名**: `cc-retrospective-learner`
- **名前の由来**: 「ふりかえりをベースにしたClaude Codeの学習機構」 → cc(Claude Code) + retrospective(ふりかえり) + learner(学習)
- **公開**: GitHub公開リポジトリ
- **将来**: 効果確認後に npm パッケージ化して `npx cc-retrospective-learner` で対話メニュー付きセットアップ/ロールバックを検討
- **構成**:
```
cc-retrospective-learner/
├── cc-retrospective-learner-setup.sh  # セットアップ兼ロールバックスクリプト
├── templates/                         # コピー元ファイル一式
│   ├── cc-retrospective-learner.md
│   ├── cc-retrospective-learner-design.md
│   ├── agents/
│   │   ├── session-reviewer.md
│   │   └── weekly-promoter.md
│   ├── hooks/
│   │   └── guard-memory-write.sh
│   ├── sessions.md
│   ├── last_weekly_review.txt
│   ├── rollback.md
│   └── claude-md-section.md
└── README.md
```

---

## 8. 設計判断のキーポイント（ブログで強調すべき点）

### 「動かない仕組みは入れない」
Long-term Evolutionを計画に入れたが、駆動源（定期実行）がなく空回りすることを指摘されて除外。外部手法を取り入れる時は「何によって駆動されるか」を確認する。

### 「Slackの代わりにtranscript」
Slack連携は外部依存が増えるだけ。transcript.jsonlにはセッション全会話が入っているので、Claude Codeとの対話の中にあるデータの方が精度が高い。

### 「サブエージェントでコンテキスト保護」
振り返りでtranscriptを読むと親コンテキストが汚れる。サブエージェントなら独自コンテキストで動くので、親には結果サマリーだけが返る。

### 「pain_countだけでなくsuccess_countも」
失敗から学ぶだけでなく、成功パターンも記録・昇格する。「やめるべきこと」と「続けるべきこと」の両方を学ぶ。

### 「全ての昇格に人間承認が必要」
自動昇格は怖い。特にHook昇格はsettings.jsonを変更するので、必ずユーザーの明示的な承認を得る。

### 「フックで書き込み先をガード」
LLMの指示ベースの制限には限界がある。機械的なPreToolUseフックで書き込み先をホワイトリスト制限する。

### 「コードブロックより自然言語」
LLMにパラメータを指定する時、コードブロックで書くと「参考情報」として扱われ変更される。自然言語で「これをするな」と書いた方が効く。

---

## 9. 参考情報

- 元のZenn記事: https://zenn.dev/tokium_dev/articles/claude-code-evolutionary-memory
- プランファイル: ~/.claude/plans/zippy-whistling-wilkes.md
- リポジトリ: cc-retrospective-learner（GitHub公開）
