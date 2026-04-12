#!/usr/bin/env bash
# サブエージェントの書き込み先をメモリ関連ファイルに限定するガードスクリプト
# PreToolUse フックとして使用。許可範囲外の Write/Edit をブロックする。
#
# stdin: JSON形式のツール入力 {"tool_name":"Write","tool_input":{"file_path":"..."}}

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

# パスが空なら通す（ツール入力が想定外の形式）
if [ -z "$file_path" ]; then
  exit 0
fi

# 許可するパスパターン
# - sessions.md
# - memory/short-term/
# - memory/long-term/
# - memory/feedback_*.md
# - memory/user_*.md
# - memory/MEMORY.md
# - last_weekly_review.txt
if echo "$file_path" | grep -qE '(sessions\.md|memory/(short-term|long-term)/|memory/feedback_|memory/user_|memory/MEMORY\.md|last_weekly_review\.txt)'; then
  exit 0
fi

# 許可範囲外 → ブロック
printf '{"continue":false,"stopReason":"書き込み先が許可範囲外です: %s\\nメモリ関連ファイル（sessions.md, memory/short-term/, memory/long-term/, memory/feedback_*.md, memory/user_*.md, memory/MEMORY.md, last_weekly_review.txt）のみ書き込み可能です。"}' "$file_path"
