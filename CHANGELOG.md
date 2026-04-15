# 変更履歴

## [2026-04-15] オンデマンド方式のふりかえりを /retrospective コマンド化

### Pain

- オンデマンド方式のふりかえり起動が「ふりかえり」「振り返り」等の自然言語トリガーに依存していた
- 曖昧な表現で別の解釈をされる可能性がある（確実性に欠ける）

### 意思決定

- `~/.claude/commands/retrospective.md` にスラッシュコマンドを配置し、`/retrospective` で確実に起動できるようにした
- コマンドファイルの中身はプロトコル本体（`cc-retrospective-learner.md`）への読み込み指示のみ。二重管理を避けるため
- CLAUDE.md のオンデマンドセクションも自然言語トリガーの記述を削除し、`/retrospective` コマンドの案内に変更

### 変更内容

#### 新規作成
- `templates/commands/retrospective.md` — `/retrospective` スラッシュコマンド

#### 変更
- `cc-retrospective-learner-setup.sh` — commands/ ディレクトリの作成・コピー・ロールバック削除を追加
- `templates/claude-md-section-ondemand.md` — 自然言語トリガーを `/retrospective` コマンドの案内に変更
- `templates/rollback.md` — 削除対象に `commands/retrospective.md` を追加

---

## [2026-04-14] sessions.md 廃止・オンデマンド方式の追加

### Pain

- セッション開始時に毎回「ふりかえりを実施しますか？」と聞かれるのが負担だった
- 短い質問をしたいだけでも毎回確認プロンプトが出る
- ふりかえり自体もサブエージェント起動・transcript 読み込みで時間がかかる
- sessions.md への毎回のセッション登録も地味にコスト（拒否しても登録処理が走る）

### 調査・検証で分かったこと

- **`/schedule`（Remote Triggers）の限界**: リモートエージェントは Anthropic のクラウド上で実行されるため、ローカルの `~/.claude/` にアクセスできない。transcript の読み取りも sessions.md への書き込みもできないため、ふりかえりの完全自動化には使えない
- **ファイルの mtime は信頼できない**: 過去のセッションを `claude --resume` で再開すると、transcript の `.jsonl` ファイルに追記されて mtime が更新される。`last_reviewed_timestamp` と mtime を比較する方式だと、同じセッションが何度もふりかえり対象になる問題がある。実際に `ls -lt` で確認して問題を実証した
- **sessions.md の多くの列は導出可能**: transcript パスは `~/.claude/projects/<key>/<session_id>.jsonl` で一意に構築できる。プロジェクト名はパスに含まれる。セッション開始日時は transcript 内の最初のエントリから取得可能。ふりかえり状態は「ファイルにあるか否か」で表現できる

### 検討した選択肢

| 案 | 内容 | 判断 |
|----|------|------|
| 自動バックグラウンド実行 | 確認なしでふりかえりを毎回自動実行 | 質問はなくなるが時間はかかる |
| `/schedule` で定期実行 | cron でリモートエージェントが自動ふりかえり | ローカルファイルにアクセスできないため不可 |
| 条件付き自動（N件溜まったら） | 未ふりかえりが一定数以上で自動実行 | 中途半端。閾値の設定も難しい |
| **オンデマンド方式** | セッション開始時は何もしない。手動で実行 | **採用**。開始コストゼロ |
| 両方式の共存 | セッション開始時に「はい/いいえ/あとで」 | 分岐ロジック・二重管理で複雑化 |
| **セットアップ時の選択式** | install 時に方式を選ぶ | **採用**。配布時にユーザーの好みで選べる |

### 意思決定

- **sessions.md を廃止 → reviewed_sessions.md に**: 「登録してからふりかえりを管理する」モデルから「ふりかえり済みを記録する」モデルに転換。セッション開始時の登録処理が不要になった
- **reviewed_sessions の形式は .md（マークダウンテーブル）**: .txt（TSV）も検討したが、VSCode/GitHub でのテーブル表示、Claude の扱いやすさの観点から .md を選択
- **導出可能な項目を削除しつつプロジェクト列は残す**: transcript パス・ふりかえり状態列・セッション開始日時は削除（導出可能）。プロジェクト列は人間が「あの作業どのセッションだっけ？」と探す時に必要なので残した
- **未ふりかえり判定は session_id の有無で行う**: mtime ベースは過去セッション再開で破綻するため却下
- **毎回方式でふりかえり拒否時は何も記録しない**: 拒否されたセッションは次回のふりかえり対象になる。「今は忙しいけど後でやりたい」に対応
- **毎回方式も reviewed_sessions.md に統一**: session-reviewer を1つで済ませるため。両方式で同じサブエージェントを共有

### 設計原則・思想

- **「仕組み」は消えるが「学習成果」は残る**: ロールバック時、プロトコル・サブエージェント定義・hooks・short-term/long-term は削除されるが、feedback_*.md・user_*.md・CLAUDE.md の昇格済みルール・昇格済みスキル/Hook は残る。ふりかえり機構が不要になっても、学習した知識は失われない
- **残存する feedback_*.md に悪影響はない**: ふりかえり機構固有のフィールド（pain_count, success_count 等）は Claude Code の標準メモリ機能に無視される。メモリの内容自体は有効なので、ロールバック後も普通のメモリとして参照され続ける
- **セッション開始のコストを最小化する**: オンデマンド方式ではセッション開始時に一切の処理を行わない。CLAUDE.md のセクションも「何もしない」と明記し、不要なプロンプト消費を防ぐ

### 変更内容

#### 新規作成
- `templates/reviewed_sessions.md` — ふりかえり済みセッションのマークダウンテーブル
- `templates/claude-md-section-ondemand.md` — オンデマンド方式用の CLAUDE.md セクション
- `templates/cc-retrospective-learner-ondemand.md` — オンデマンド方式のプロトコル

#### 変更
- `cc-retrospective-learner-setup.sh` — 方式選択（対話 or `--mode=`）、ファイルコピー分岐、方式記録
- `templates/cc-retrospective-learner.md` — sessions.md 廃止、reviewed_sessions.md + jsonl スキャン方式に変更、セクション4（セッション登録）削除
- `templates/agents/session-reviewer.md` — sessions.md 依存を除去、reviewed_sessions.md に登録する方式に変更
- `templates/hooks/guard-memory-write.sh` — 許可パスを sessions.md → reviewed_sessions.md に変更
- `templates/rollback.md` — 削除対象ファイルリストに reviewed_sessions.md, cc-retrospective-learner-mode.txt を追加
- `templates/cc-retrospective-learner-design.md` — 2方式の設計・フロー図・ファイル構成を全面改訂

#### 削除
- `templates/sessions.md` — reviewed_sessions.md に置き換え
