# 手動ロールバック手順書

cc-retrospective-learner-setup.sh rollback が動かない場合の手動復元手順です。

## 前提

- バックアップは `~/.claude/backups/pre-cc-retrospective-learner/` に保存されています
- セットアップ後に CLAUDE.md に追加した他の変更は、マーカー間の部分のみ削除すれば保持されます

## 手順

### 1. CLAUDE.md からセクションを削除

`~/.claude/CLAUDE.md` を開き、以下のマーカー間の内容（マーカー行自体も含む）を削除してください:

```
<!-- CC-RETROSPECTIVE-LEARNER-START -->
...
<!-- CC-RETROSPECTIVE-LEARNER-END -->
```

**注意**: マーカーの外にある内容は触らないでください。セットアップ後に追加した他の変更が含まれている可能性があります。

### 2. 追加ファイルを削除

以下のファイルを削除してください:

```bash
rm -f ~/.claude/cc-retrospective-learner.md
rm -f ~/.claude/cc-retrospective-learner-design.md
rm -f ~/.claude/cc-retrospective-learner-setup.sh
rm -f ~/.claude/cc-retrospective-learner-mode.txt
rm -f ~/.claude/reviewed_sessions.md
rm -f ~/.claude/sessions.md
rm -f ~/.claude/last_weekly_review.txt
rm -rf ~/.claude/agents/session-reviewer.md
rm -rf ~/.claude/agents/weekly-promoter.md
```

**注意**: `~/.claude/agents/` ディレクトリ自体は、他のエージェント定義が含まれている可能性があるため削除しないでください。

### 3. プロジェクト別メモリディレクトリを削除

各プロジェクトの memory ディレクトリから short-term/ と long-term/ を削除してください:

```bash
# 全プロジェクトから一括削除
for pdir in ~/.claude/projects/*/; do
  rm -rf "${pdir}memory/short-term/"
  rm -rf "${pdir}memory/long-term/"
done
```

**注意**: `memory/` ディレクトリ自体や、その中の既存ファイル（feedback_*.md, user_*.md, MEMORY.md 等）は削除しないでください。

### 4. バックアップからの復元（必要な場合のみ）

上記の削除だけで十分な場合がほとんどですが、バックアップファイルが必要な場合:

```bash
# MEMORY.md のバックアップがある場合
cp ~/.claude/backups/pre-cc-retrospective-learner/MEMORY.md ~/.claude/memory/MEMORY.md

# feedback_*.md のバックアップがある場合
cp ~/.claude/backups/pre-cc-retrospective-learner/feedback_*.md ~/.claude/memory/
```

### 5. 確認

- `~/.claude/CLAUDE.md` にマーカーが残っていないこと
- `~/.claude/cc-retrospective-learner.md` が存在しないこと
- `~/.claude/cc-retrospective-learner-setup.sh` が存在しないこと
- `~/.claude/reviewed_sessions.md` が存在しないこと
- `~/.claude/cc-retrospective-learner-mode.txt` が存在しないこと
- 各プロジェクトの `memory/short-term/` が存在しないこと
- 各プロジェクトの `memory/long-term/` が存在しないこと

## バックアップの削除

ロールバックが完了し、問題がないことを確認した後にバックアップを削除してください:

```bash
rm -rf ~/.claude/backups/pre-cc-retrospective-learner/
```
