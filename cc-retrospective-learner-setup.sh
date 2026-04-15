#!/usr/bin/env bash
set -euo pipefail

# cc-retrospective-learner セットアップ兼ロールバックスクリプト
# Usage:
#   bash cc-retrospective-learner-setup.sh install                # 対話的に方式選択
#   bash cc-retrospective-learner-setup.sh install --mode=everytime   # 毎回方式
#   bash cc-retrospective-learner-setup.sh install --mode=ondemand    # オンデマンド方式
#   bash cc-retrospective-learner-setup.sh rollback               # ロールバック

CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/pre-cc-retrospective-learner"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
MARKER_START="<!-- CC-RETROSPECTIVE-LEARNER-START -->"
MARKER_END="<!-- CC-RETROSPECTIVE-LEARNER-END -->"

# 色付き出力
info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }

# -------------------------------------------------------------------
# install
# -------------------------------------------------------------------
do_install() {
  local mode="${1:-}"

  info "ふりかえりベースの学習機構をセットアップします"

  # 前提チェック
  if [[ ! -d "$CLAUDE_DIR" ]]; then
    error "~/.claude/ が見つかりません。Claude Code をインストールしてください。"
    exit 1
  fi

  if [[ ! -d "$TEMPLATES_DIR" ]]; then
    error "templates/ ディレクトリが見つかりません。リポジトリのルートから実行してください。"
    exit 1
  fi

  # 既にインストール済みかチェック
  if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]] && grep -q "$MARKER_START" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
    warn "既にセットアップ済みです。再インストールする場合は先に rollback を実行してください。"
    exit 1
  fi

  # --- 方式選択 ---
  if [[ -z "$mode" ]]; then
    echo ""
    info "ふりかえり方式を選択してください:"
    echo ""
    echo "  1) 毎回方式"
    echo "     セッション開始時にふりかえりを確認し、承認されたら実行"
    echo ""
    echo "  2) オンデマンド方式"
    echo "     セッション開始時は何もしない。手動でふりかえりを指示した時に実行"
    echo ""
    read -rp "選択 [1/2]: " mode_choice
    case "$mode_choice" in
      1) mode="everytime" ;;
      2) mode="ondemand" ;;
      *)
        error "無効な選択です。1 または 2 を入力してください。"
        exit 1
        ;;
    esac
  fi

  info "方式: $mode"

  # --- 1. バックアップ ---
  info "バックアップを作成しています..."
  mkdir -p "$BACKUP_DIR"

  # CLAUDE.md
  if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    cp "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_DIR/CLAUDE.md"
    ok "CLAUDE.md をバックアップしました"
  fi

  # プロジェクト別 memory ディレクトリから既存ファイルをバックアップ
  local project_dirs
  project_dirs=$(find "$CLAUDE_DIR/projects" -maxdepth 1 -mindepth 1 -type d 2>/dev/null || true)
  for pdir in $project_dirs; do
    local mem_dir="$pdir/memory"
    if [[ -d "$mem_dir" ]]; then
      local project_name
      project_name=$(basename "$pdir")

      # MEMORY.md
      if [[ -f "$mem_dir/MEMORY.md" ]]; then
        mkdir -p "$BACKUP_DIR/projects/$project_name"
        cp "$mem_dir/MEMORY.md" "$BACKUP_DIR/projects/$project_name/MEMORY.md"
      fi

      # feedback_*.md
      for fb in "$mem_dir"/feedback_*.md; do
        if [[ -f "$fb" ]]; then
          mkdir -p "$BACKUP_DIR/projects/$project_name"
          cp "$fb" "$BACKUP_DIR/projects/$project_name/"
        fi
      done
    fi
  done

  # rollback.md をバックアップディレクトリにもコピー
  cp "$TEMPLATES_DIR/rollback.md" "$BACKUP_DIR/rollback.md"
  ok "バックアップ完了: $BACKUP_DIR"

  # --- 2. 共通テンプレートファイルをコピー ---
  info "テンプレートファイルをコピーしています..."

  cp "$TEMPLATES_DIR/cc-retrospective-learner-design.md" "$CLAUDE_DIR/cc-retrospective-learner-design.md"
  ok "cc-retrospective-learner-design.md"

  cp "$TEMPLATES_DIR/reviewed_sessions.md" "$CLAUDE_DIR/reviewed_sessions.md"
  ok "reviewed_sessions.md"

  cp "$TEMPLATES_DIR/last_weekly_review.txt" "$CLAUDE_DIR/last_weekly_review.txt"
  ok "last_weekly_review.txt"

  # agents ディレクトリ
  mkdir -p "$CLAUDE_DIR/agents"
  cp "$TEMPLATES_DIR/agents/session-reviewer.md" "$CLAUDE_DIR/agents/session-reviewer.md"
  ok "agents/session-reviewer.md"

  cp "$TEMPLATES_DIR/agents/weekly-promoter.md" "$CLAUDE_DIR/agents/weekly-promoter.md"
  ok "agents/weekly-promoter.md"

  # hooks ディレクトリ
  mkdir -p "$CLAUDE_DIR/hooks"
  cp "$TEMPLATES_DIR/hooks/guard-memory-write.sh" "$CLAUDE_DIR/hooks/guard-memory-write.sh"
  ok "hooks/guard-memory-write.sh"

  # commands ディレクトリ
  mkdir -p "$CLAUDE_DIR/commands"
  cp "$TEMPLATES_DIR/commands/retrospective.md" "$CLAUDE_DIR/commands/retrospective.md"
  ok "commands/retrospective.md"

  # --- 3. 方式別ファイルをコピー ---
  info "方式別ファイルをコピーしています（$mode）..."

  if [[ "$mode" == "everytime" ]]; then
    cp "$TEMPLATES_DIR/cc-retrospective-learner.md" "$CLAUDE_DIR/cc-retrospective-learner.md"
    ok "cc-retrospective-learner.md（毎回方式）"
  else
    cp "$TEMPLATES_DIR/cc-retrospective-learner-ondemand.md" "$CLAUDE_DIR/cc-retrospective-learner.md"
    ok "cc-retrospective-learner.md（オンデマンド方式）"
  fi

  # --- 4. プロジェクト別 memory ディレクトリ作成 ---
  info "プロジェクト別メモリディレクトリを作成しています..."
  local created=0
  for pdir in "$CLAUDE_DIR"/projects/*/; do
    if [[ -d "$pdir" ]]; then
      mkdir -p "${pdir}memory/short-term"
      mkdir -p "${pdir}memory/long-term"
      created=$((created + 1))
    fi
  done
  ok "short-term/, long-term/ を ${created} プロジェクトに作成"

  # --- 5. スクリプト自身を ~/.claude/ にコピー ---
  info "セットアップスクリプトをコピーしています..."
  cp "$SCRIPT_DIR/cc-retrospective-learner-setup.sh" "$CLAUDE_DIR/cc-retrospective-learner-setup.sh"
  ok "cc-retrospective-learner-setup.sh → ~/.claude/"

  # --- 6. 方式を記録 ---
  echo "$mode" > "$CLAUDE_DIR/cc-retrospective-learner-mode.txt"
  ok "方式を記録: $mode"

  # --- 7. CLAUDE.md にセクション追記 ---
  info "CLAUDE.md にセクションを追記しています..."

  local section_file
  if [[ "$mode" == "everytime" ]]; then
    section_file="$TEMPLATES_DIR/claude-md-section.md"
  else
    section_file="$TEMPLATES_DIR/claude-md-section-ondemand.md"
  fi

  if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    # 末尾に改行を確保してから追記
    echo "" >> "$CLAUDE_DIR/CLAUDE.md"
    cat "$section_file" >> "$CLAUDE_DIR/CLAUDE.md"
  else
    cp "$section_file" "$CLAUDE_DIR/CLAUDE.md"
  fi
  ok "CLAUDE.md 更新完了"

  echo ""
  info "============================================"
  ok   "セットアップが完了しました！（$mode 方式）"
  info "============================================"
  echo ""
  if [[ "$mode" == "everytime" ]]; then
    info "次回の Claude Code セッション開始時からふりかえりベースの学習機構が有効になります。"
  else
    info "ふりかえりを実行したい時は、セッション中に /retrospective と入力してください。"
  fi
  info "ロールバック: bash cc-retrospective-learner-setup.sh rollback"
  info "手動ロールバック手順: $BACKUP_DIR/rollback.md"
}

# -------------------------------------------------------------------
# rollback
# -------------------------------------------------------------------
do_rollback() {
  info "ふりかえりベースの学習機構をロールバックします"

  # --- 1. CLAUDE.md からマーカー間を削除 ---
  if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    if grep -q "$MARKER_START" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
      # マーカー間（マーカー行含む）を削除し、末尾の余分な空行も整理
      sed -i "/$MARKER_START/,/$MARKER_END/d" "$CLAUDE_DIR/CLAUDE.md"
      # 末尾の空行を整理（最大1行に）
      sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$CLAUDE_DIR/CLAUDE.md"
      ok "CLAUDE.md からセクションを削除しました"
    else
      warn "CLAUDE.md にマーカーが見つかりません（既に削除済みの可能性）"
    fi
  fi

  # --- 2. 追加ファイルの削除 ---
  info "追加ファイルを削除しています..."

  local files_to_remove=(
    "$CLAUDE_DIR/cc-retrospective-learner.md"
    "$CLAUDE_DIR/cc-retrospective-learner-design.md"
    "$CLAUDE_DIR/cc-retrospective-learner-setup.sh"
    "$CLAUDE_DIR/cc-retrospective-learner-mode.txt"
    "$CLAUDE_DIR/reviewed_sessions.md"
    "$CLAUDE_DIR/sessions.md"
    "$CLAUDE_DIR/last_weekly_review.txt"
    "$CLAUDE_DIR/agents/session-reviewer.md"
    "$CLAUDE_DIR/agents/weekly-promoter.md"
    "$CLAUDE_DIR/hooks/guard-memory-write.sh"
    "$CLAUDE_DIR/commands/retrospective.md"
  )

  for f in "${files_to_remove[@]}"; do
    if [[ -f "$f" ]]; then
      rm "$f" && ok "削除: $f" || warn "削除失敗: $f"
    fi
  done

  # 空ディレクトリのクリーンアップ
  for dir in "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/commands"; do
    if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
      rmdir "$dir" && ok "空ディレクトリ削除: $dir" || true
    fi
  done

  # --- 3. プロジェクト別 memory ディレクトリの削除 ---
  info "プロジェクト別メモリディレクトリを削除しています..."
  for pdir in "$CLAUDE_DIR"/projects/*/; do
    if [[ -d "${pdir}memory/short-term" ]]; then
      rm -rf "${pdir}memory/short-term"
      ok "削除: $(basename "$pdir")/memory/short-term/"
    fi
    if [[ -d "${pdir}memory/long-term" ]]; then
      rm -rf "${pdir}memory/long-term"
      ok "削除: $(basename "$pdir")/memory/long-term/"
    fi
  done

  echo ""
  info "============================================"
  ok   "ロールバックが完了しました！"
  info "============================================"
  echo ""
  info "バックアップは $BACKUP_DIR に残っています。"
  info "不要であれば手動で削除してください: rm -rf $BACKUP_DIR"
}

# -------------------------------------------------------------------
# メイン
# -------------------------------------------------------------------
case "${1:-}" in
  install)
    # --mode=xxx オプションの解析
    mode=""
    for arg in "${@:2}"; do
      case "$arg" in
        --mode=everytime) mode="everytime" ;;
        --mode=ondemand)  mode="ondemand" ;;
        --mode=*)
          error "無効な方式です: $arg（--mode=everytime または --mode=ondemand）"
          exit 1
          ;;
      esac
    done
    do_install "$mode"
    ;;
  rollback)
    do_rollback
    ;;
  *)
    echo "Usage: bash $(basename "$0") {install|rollback}"
    echo ""
    echo "  install                  - 対話的に方式を選択してセットアップ"
    echo "  install --mode=everytime - 毎回方式でセットアップ"
    echo "  install --mode=ondemand  - オンデマンド方式でセットアップ"
    echo "  rollback                 - セットアップ前の状態に戻す"
    exit 1
    ;;
esac
