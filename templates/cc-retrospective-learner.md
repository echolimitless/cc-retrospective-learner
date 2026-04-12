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
