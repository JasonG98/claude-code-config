# ~/.claude/statusline.ps1
# Style: Neon Minimal — Nerd Font icons, vertical bar separators
# Order: model | dir | git | ctx
param()

# 强制 UTF-8 输入输出
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# ── ANSI 颜色工具 ─────────────────────────────────────────────
$ESC = [char]27
function fg($r, $g, $b) { return "$ESC[38;2;${r};${g};${b}m" }
$RESET = "$ESC[0m"
$BOLD  = "$ESC[1m"

# ── Nerd Font 图标 ────────────────────────────────────────────
$I_MODEL = [char]::ConvertFromUtf32(0xF4BE)     # nf-oct-dependabot
$I_DIR   = [char]::ConvertFromUtf32(0xF4D3)     # nf-oct-file_directory
$I_GIT   = [char]::ConvertFromUtf32(0xF418)     # nf-oct-git_branch
$I_DIRTY = [char]::ConvertFromUtf32(0xF459)     # nf-oct-diff_modified
$I_CTX   = [char]::ConvertFromUtf32(0xF51E)     # nf-oct-stack

$DOT         = [char]::ConvertFromUtf32(0x00B7)   # ·
# $DARK_SHADE  = [char]::ConvertFromUtf32(0x2593)   # ▓
# $LIGHT_SHADE = [char]::ConvertFromUtf32(0x2591)   # ░

# ── 读取 JSON ─────────────────────────────────────────────────
$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json

$DIR   = if ($json.workspace.current_dir)              { $json.workspace.current_dir }                   else { "" }
$PCT   = if ($json.context_window.used_percentage)     { [int]$json.context_window.used_percentage }     else { 0 }
$MAX   = if ($json.context_window.context_window_size) { [int]$json.context_window.context_window_size } else { 0 }
$MODEL = if ($json.model.display_name)                 { $json.model.display_name }                      else { "" }

# 计算已用 tokens
$USED = [int]($MAX * $PCT / 100)

# ── 模型名缩短："Claude Sonnet 4.5" → "Sonnet 4.5" ───────────
$MODEL_SHORT = $MODEL -replace '^Claude ', ''

# ── 目录：只取文件夹名 ────────────────────────────────────────
$DIR_NAME = if ($DIR) { Split-Path $DIR -Leaf } else { "/" }
if (-not $DIR_NAME) { $DIR_NAME = "/" }

# ── Git 分支 ──────────────────────────────────────────────────
$GIT_PART = ""
if ($DIR -and (Test-Path $DIR)) {
    $BRANCH = ""
    try {
        $BRANCH = & git -C $DIR branch --show-current 2>$null
        if (-not $BRANCH) {
            $BRANCH = & git -C $DIR rev-parse --short HEAD 2>$null
        }
        if ($BRANCH) {
            $DIRTY = ""
            & git -C $DIR diff --quiet 2>$null
            if ($LASTEXITCODE -ne 0) { $DIRTY = " $I_DIRTY" }
            $GIT_PART = "$BRANCH$DIRTY"
        }
    } catch {}
}


# ── Token 格式化 ──────────────────────────────────────────────
function fmt_k($n) {
    if ($n -ge 1000) { return "$([int]($n/1000))k" } else { return "$n" }
}
$USED_K = fmt_k $USED
$MAX_K  = fmt_k $MAX

# ── 进度条（#-，10 格）───────────────────────────────────────
$BAR_W  = 10
$FILLED = [Math]::Min([int]($PCT * $BAR_W / 100), $BAR_W)
$EMPTY  = $BAR_W - $FILLED
# 使用循环构建进度条，避免 PowerShell 字符串乘法的问题
$BAR    = ("#" * $FILLED) + ("-" * $EMPTY)

# ── ctx 颜色（随用量变化）────────────────────────────────────
if     ($PCT -lt 50) { $CR=251; $CG=191; $CB=36  }   # 黄
elseif ($PCT -lt 80) { $CR=249; $CG=115; $CB=22  }   # 橙
else                 { $CR=239; $CG=68;  $CB=68  }   # 红

# ── 颜色定义 ──────────────────────────────────────────────────
$cMOD = fg 167 139 250   # 紫  模型
$cDIR = fg 96  165 250   # 蓝  目录
$cGIT = fg 52  211 153   # 绿  git
$cCTX = fg $CR $CG $CB   # ctx 颜色
$cDIM = fg 80  80  80    # 灰  竖线

$SEP = " ${cDIM}|${RESET} "

# ── 单行输出 ──────────────────────────────────────────────────
$OUT = ""

# 模型
if ($MODEL_SHORT) {
    $OUT += "${cMOD}${BOLD}${I_MODEL} ${MODEL_SHORT}${RESET}${SEP}"
}

# 目录
$OUT += "${cDIR}${BOLD}${I_DIR} ${DIR_NAME}${RESET}"

# Git 分支
if ($GIT_PART) {
    $OUT += "${SEP}${cGIT}${BOLD}${I_GIT} ${GIT_PART}${RESET}"
}

# Context
$OUT += "${SEP}${cCTX}${BOLD}${I_CTX} ${BAR} ${USED_K}/${MAX_K} ${DOT} ${PCT}%${RESET}"

Write-Host $OUT
