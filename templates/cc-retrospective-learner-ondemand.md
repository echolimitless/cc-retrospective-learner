# cc-retrospective-learner プロトコル（オンデマンド方式）

ユーザーが明示的にふりかえりを指示した時に実行する。

## 1. 未ふりかえりセッションの収集

1. `~/.claude/reviewed_sessions.md` を読み込み、ふりかえり済みの session_id 集合を得る
2. `~/.claude/projects/` 配下の各プロジェクトディレクトリ内の `*.jsonl` ファイルを Glob で列挙する
   - パターン: `~/.claude/projects/*/*.jsonl`
   - ファイル名（拡張子除く）が session_id
3. reviewed_sessions.md に含まれない session_id が「未ふりかえり」

未ふりかえりセッションがない場合 → `ふりかえり完了: 対象セッションなし` と表示して終了。

## 2. セッションふりかえり

`session-reviewer` サブエージェントをフォアグラウンドで起動する。

**必須パラメータ:**
- subagent_type: "session-reviewer"（general-purposeにしないこと）
- prompt に以下を含める:
  - 未ふりかえり session_id のリスト
  - 各 session_id の transcript パス（`~/.claude/projects/<project-key>/<session_id>.jsonl`）
  - project_memory_path（`~/.claude/projects/{project-key}/memory`）
- **バックグラウンド実行禁止。run_in_background を指定しないこと。**

## 3. 週次昇格チェック

`~/.claude/last_weekly_review.txt` の日付を確認し、7日以上経過していれば `weekly-promoter` サブエージェントをフォアグラウンドで起動する。

**必須パラメータ:**
- subagent_type: "weekly-promoter"（general-purposeにしないこと）
- prompt に project_memory_path を含める
- **バックグラウンド実行禁止。run_in_background を指定しないこと。**

## 4. ふりかえりサマリーの表示

session-reviewer と weekly-promoter（実行した場合）の結果をまとめてユーザーに表示する。

### ふりかえり対象がある場合

以下をすべて表示する:

- ふりかえったセッション数
- 各セッションの概要（1行ずつ）
- feedback カウント更新（更新があった場合）
- 昇格候補（あれば）
- 週次昇格チェックの実行有無と結果
- 警告事項（あれば）

### 昇格提案

昇格候補がある場合、サマリー表示後にユーザーに提案する。
**ユーザーの明示的な承認なしに昇格を実行しない。**
**特に Hook 昇格は settings.json を変更するため必ず承認を得る。**

## 注意事項

- ふりかえり・週次昇格はサブエージェントで実行し、親コンテキストを消費しない
- サブエージェントからは結果サマリーだけを受け取る
- セッション中のカウント更新はしない（session-reviewer が実施）
- transcript パスは `~/.claude/projects/<project-key>/<session_id>.jsonl` で構築する（sessions/ サブディレクトリはない）
