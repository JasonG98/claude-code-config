#!/usr/bin/env zsh
# ~/.claude/statusline.sh
# Style: Neon Minimal — Nerd Font icons, no background blocks
# Order: model · dir · git · ctx
# 依赖: jq + Nerd Font (brew install jq / apt install jq)

fg()  { printf '\033[38;2;%s;%s;%sm' "$1" "$2" "$3"; }
RESET='\033[0m'
BOLD='\033[1m'

# ── Nerd Font 图标 (Octicons 风格) ────────────────────────────────
I_MODEL=$'\U000F4B8'  # nf-oct-copilot     AI 模型
I_DIR=$'\U000F4D3'    # nf-oct-repo        目录
I_GIT=$'\U000F418'    # nf-oct-git_branch  分支
I_CTX=$'\U000F51E'    # nf-oct-stack       context 层级感
I_DIRTY=$'\U000F440'  # nf-oct-diff        未提交改动

# ── 读取 JSON ─────────────────────────────────────────────────
input=$(cat)

DIR=$(echo   "$input" | jq -r '.workspace.current_dir // ""')
MODEL=$(echo "$input" | jq -r '.model.display_name // ""')

# ── Context 计算（正确方式）────────────────────────────────────
# 使用 current_usage.input_tokens（当前上下文实际占用），而非 total_input_tokens（累计值）
USED=$(echo  "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
MAX=$(echo   "$input" | jq -r '.context_window.context_window_size // 0')

# 手动计算百分比（更可靠）
if [ "$MAX" -gt 0 ] 2>/dev/null; then
    PCT=$(( USED * 100 / MAX ))
else
    PCT=0
fi

# ── 模型名缩短："Claude Sonnet 4.5" → "Sonnet 4.5" ───────────
MODEL_SHORT="${MODEL#Claude }"

# ── 目录：只取文件夹名 ────────────────────────────────────────
DIR_NAME="${DIR##*/}"
[ -z "$DIR_NAME" ] && DIR_NAME="/"

# ── Git 分支 ──────────────────────────────────────────────────
GIT_PART=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
    [ -z "$BRANCH" ] && BRANCH=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
    DIRTY=""
    if ! git -C "$DIR" diff --quiet 2>/dev/null || \
       ! git -C "$DIR" diff --cached --quiet 2>/dev/null; then
        DIRTY=" ${I_DIRTY}"
    fi
    GIT_PART="${BRANCH}${DIRTY}"
fi

# ── Token 格式化 ──────────────────────────────────────────────
fmt_k() {
    [ "$1" -ge 1000 ] && printf '%dk' $(( $1 / 1000 )) || printf '%d' "$1"
}
USED_K=$(fmt_k "$USED")
MAX_K=$(fmt_k  "$MAX")

# ── 进度条颜色（随用量变化）────────────────────────────────────
# 填充部分颜色
if   [ "$PCT" -lt 50 ]; then
    CR=251; CG=191; CB=36    # 黄
elif [ "$PCT" -lt 80 ]; then
    CR=249; CG=115; CB=22    # 橙
else
    CR=239; CG=68;  CB=68    # 红
fi

# 未填充部分颜色（暗灰）
BAR_DIM_R=80; BAR_DIM_G=80; BAR_DIM_B=80

# ── 进度条（─╌，10 格）───────────────────────────────────────
BAR_W=10
FILLED=$(( PCT * BAR_W / 100 ))
[ "$FILLED" -gt "$BAR_W" ] && FILLED=$BAR_W
EMPTY=$(( BAR_W - FILLED ))

# 分别构建填充和未填充部分（不同颜色）
FILL_CHAR='─'
EMPTY_CHAR='╌'
BAR=""
[ "$FILLED" -gt 0 ] && BAR="$(fg $CR $CG $CB)$(printf "%${FILLED}s" | tr ' ' "$FILL_CHAR")"
[ "$EMPTY"  -gt 0 ] && BAR="${BAR}$(fg $BAR_DIM_R $BAR_DIM_G $BAR_DIM_B)$(printf "%${EMPTY}s" | tr ' ' "$EMPTY_CHAR")"
BAR="${BAR}${RESET}"

# ── 颜色定义 ──────────────────────────────────────────────────
MOD_R=167; MOD_G=139; MOD_B=250   # 紫  模型
DIR_R=96;  DIR_G=165; DIR_B=250   # 蓝  目录
GIT_R=52;  GIT_G=211; GIT_B=153   # 绿  git
DIM_R=100; DIM_G=100; DIM_B=100   # 灰  分隔符

DOT="$(fg $DIM_R $DIM_G $DIM_B) | ${RESET}"

# ── 单行输出 ──────────────────────────────────────────────────
OUT=""

# 模型（最前）
[ -n "$MODEL_SHORT" ] && \
    OUT+="$(fg $MOD_R $MOD_G $MOD_B)${BOLD}${I_MODEL} ${MODEL_SHORT}${RESET}${DOT}"

# 目录
OUT+="$(fg $DIR_R $DIR_G $DIR_B)${BOLD}${I_DIR} ${DIR_NAME}${RESET}"

# Git 分支
[ -n "$GIT_PART" ] && \
    OUT+="${DOT}$(fg $GIT_R $GIT_G $GIT_B)${BOLD}${I_GIT} ${GIT_PART}${RESET}"

# Context
OUT+="${DOT}$(fg $CR $CG $CB)${BOLD}${I_CTX} ${BAR} ${USED_K}/${MAX_K} · ${PCT}%${RESET}"

printf '%b\n' "$OUT"
