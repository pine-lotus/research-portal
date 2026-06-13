#!/bin/bash
#
# morning_check.sh
# ─────────────────────────────────────────────
# 役割：ログイン時に「本日の新規事業リサーチレポートが
#       まだ作られていなければ、自動で作成する」スクリプト。
#
# 動き：
#   1. 今日の日付（YYMMDD）でレポートファイルを探す
#   2. すでにあれば → 何もせず終了（重複防止）
#   3. なければ → ネット接続を待ってから claude を呼んでタスク実行
# ─────────────────────────────────────────────

# --- 設定 ---
WORK_DIR="/Users/amustat/claude-work"
REPORT_DIR="$WORK_DIR/reports/毎日"
LOG_FILE="$WORK_DIR/morning_check.log"
SKILL_FILE="/Users/amustat/.claude/scheduled-tasks/daily-business-research/SKILL.md"
CLAUDE_BIN="/usr/local/bin/claude"

# ログに時刻つきでメッセージを書く関数
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# --- 1. 今日のレポートが既にあるか確認 ---
# 今日の日付を YYMMDD 形式で取得（例：260614）
TODAY=$(date '+%y%m%d')

# reports/毎日/ の中に「260614_」で始まる .md があるか探す
if ls "$REPORT_DIR/${TODAY}_"*.md >/dev/null 2>&1; then
  log "本日（${TODAY}）のレポートは既に存在 → スキップ"
  exit 0
fi

log "本日（${TODAY}）のレポートが未作成 → 自動実行を開始"

# --- 2. ネット接続を待つ（最大10分） ---
# 30秒ごとに接続を確認し、つながったら次に進む
CONNECTED=0
for i in $(seq 1 20); do
  if ping -c 1 -t 3 8.8.8.8 >/dev/null 2>&1; then
    CONNECTED=1
    break
  fi
  log "ネット未接続… 30秒後に再確認（${i}/20回目）"
  sleep 30
done

if [ "$CONNECTED" -eq 0 ]; then
  log "10分待ってもネット未接続 → 中止。次回ログイン時に再試行されます"
  osascript -e 'display notification "ネット未接続のため後で再試行します" with title "🌅 毎朝偵察部隊" subtitle "待機中"' 2>/dev/null
  exit 1
fi

log "ネット接続を確認 → claude にタスクを依頼します"

# --- 3. claude を非対話モードで実行 ---
# SKILL.md の中身（タスク指示文）をそのまま claude に渡す
# --dangerously-skip-permissions：自動実行のため確認ダイアログを省略
cd "$WORK_DIR" || exit 1

PROMPT=$(cat "$SKILL_FILE")

"$CLAUDE_BIN" --dangerously-skip-permissions -p "$PROMPT" >> "$LOG_FILE" 2>&1
RESULT=$?

if [ "$RESULT" -eq 0 ]; then
  log "✅ 自動実行が完了しました"
else
  log "❌ 自動実行が失敗しました（終了コード: $RESULT）"
  osascript -e 'display notification "起動時の自動補完に失敗しました。ログを確認してください。" with title "🌅 毎朝偵察部隊" subtitle "⚠️ エラー発生"' 2>/dev/null
fi

exit "$RESULT"
