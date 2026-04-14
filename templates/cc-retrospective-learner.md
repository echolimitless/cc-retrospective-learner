# cc-retrospective-learner プロトコル

セッション開始時に以下を実行する。

## 1. セッションふりかえり

`session-reviewer` サブエージェントをフォアグラウンドで起動する。

**必須パラメータ:**
- subagent_type: "session-reviewer"（general-purposeにしないこと）
- prompt に以下を含める: 現在のsession_id、プロジェクトパス、project_memory_path（`~/.claude/projects/{project-key}/memory`）
- **バックグラウンド実行禁止。run_in_background を指定しないこと。**

## 2. 週次昇格チェック

`~/.claude/last_weekly_review.txt` の日付を確認し、7日以上経過していれば `weekly-promoter` サブエージェントをフォアグラウンドで起動する。

**必須パラメータ:**
- subagent_type: "weekly-promoter"（general-purposeにしないこと）
- prompt に project_memory_path を含める
- **バックグラウンド実行禁止。run_in_background を指定しないこと。**

## 3. ふりかえりサマリーの表示

session-reviewer と weekly-promoter（実行した場合）の結果をまとめてユーザーに表示する。

### ふりかえり対象がない場合

1行で済ませる: `ふりかえり完了: 対象セッションなし`

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

## 4. 現在のセッションの登録

**ふりかえりの実施・スキップにかかわらず、必ず実行する。**

現在のセッション情報を `~/.claude/sessions.md` に「未」で登録する。

```
| <日時> | <session_id> | <プロジェクト> | | 未 | <transcript_path> |
```

transcript パスの構築:
- `~/.claude/projects/<project-key>/sessions/<session_id>/transcript.jsonl`
- project-key: プロジェクトの絶対パスから構築（パス区切りを `-` に変換し、先頭のドライブレター・区切りを含む）

**注意: 登録するのは現在のセッション情報のみ。過去のセッションを探索・追加してはならない。**

## 注意事項

- ふりかえり・週次昇格はサブエージェントで実行し、親コンテキストを消費しない
- サブエージェントからは結果サマリーだけを受け取る
- セッション中のカウント更新はしない（次のセッション開始時に session-reviewer が実施）
