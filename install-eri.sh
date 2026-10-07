#!/usr/bin/env bash
# ============================================================
# install-eri.sh - 绘里酱人格 · 交互式/一键部署 (Linux/macOS/Termux/WSL)
# 用法: bash install-eri.sh [RAW_URL]
# 交互模式: 选择工具 -> 查找本地路径 -> 已装则部署人格 /
#           未装则按官网方式安装 -> 检查确认安装完成后部署人格
# 非交互模式 (curl | bash 一键): 自动部署已装工具;
#           零工具时自动安装旗舰工具 opencode 并部署人格
# ============================================================
set -uo pipefail

# 非交互检测: curl | bash 一键模式下 stdin 非终端
INTERACTIVE=1
[ -t 0 ] || INTERACTIVE=0

DEFAULT_URL="https://raw.githubusercontent.com/nino-natsume/eri/main/eri.md"
RAW_URL="${1:-$DEFAULT_URL}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-}"
# 下载模式的人格缓存路径: 父级固定唯一路径,函数内只检查/写入,
# 避免命令替换子 shell 导致变量回传失败、重复下载与临时文件泄漏
DL_CACHE="${TMPDIR:-/tmp}/eri.$$.md"

# 退出时清理下载的临时人格文件
cleanup() {
  rm -f "$DL_CACHE"
}
trap cleanup EXIT INT TERM

# ---------- 工具注册表 ----------
# 格式: id|名称|检查命令|官网安装命令(空=官网手动)|官网|人格目标目录|人格文件名|特殊模式
TOOLS=(
  "opencode|OpenCode|opencode|npm install -g opencode-ai|https://opencode.ai|$HOME_DIR/.config/opencode/agents|eri.md|"
  "claude|Claude Code|claude|npm install -g @anthropic-ai/claude-code|https://code.claude.com|$HOME_DIR/.claude|CLAUDE.md|"
  "codex|Codex CLI (OpenAI)|codex|npm install -g @openai/codex|https://developers.openai.com/codex|$HOME_DIR/.codex|AGENTS.md|"
  "gemini|Gemini CLI (Google)|gemini|npm install -g @google/gemini-cli|https://github.com/google-gemini/gemini-cli|$HOME_DIR/.gemini|GEMINI.md|"
  "qwen|Qwen Code (Alibaba)|qwen|npm install -g @qwen-code/qwen-code@latest|https://github.com/QwenLM/qwen-code|$HOME_DIR/.qwen|GEMINI.md|"
  "aider|Aider|aider|python -m pip install -U aider-chat|https://aider.chat|$HOME_DIR/.config/aider|eri.md|aider"
  "cursor|Cursor CLI|cursor-agent||https://cursor.com/docs/cli/installation|$HOME_DIR/.cursor|AGENTS.md|"
  "windsurf|Windsurf CLI|windsurf||https://docs.windsurf.com|$HOME_DIR/.windsurf|AGENTS.md|"
  "amp|Amp|amp||https://ampcode.com|$HOME_DIR/.amp|AGENTS.md|"
  "goose|Goose (Block)|goose||https://block.github.io/goose/|$HOME_DIR/.config/goose|AGENTS.md|"
  "copilot|GitHub Copilot CLI|copilot|npm install -g @github/copilot|https://github.com/github/copilot-cli|$HOME_DIR/.github/copilot|AGENTS.md|"
  "plandex|Plandex|plandex|npm install -g plandex|https://plandex.ai|$HOME_DIR/.plandex|AGENTS.md|"
  "tabby|Tabby|tabby-agent|npm install -g tabby-agent|https://tabbyml.com|$HOME_DIR/.tabby|AGENTS.md|"
  "fabric|Fabric|fabric|go install github.com/danielmiessler/fabric@latest|https://github.com/danielmiessler/fabric|$HOME_DIR/.config/fabric|AGENTS.md|"
  "openhands|OpenHands|openhands|python -m pip install -U openhands-ai|https://docs.all-hands.dev|$HOME_DIR/.openhands|AGENTS.md|"
  "crush|Crush|crush||https://crush.chat|$HOME_DIR/.crush|AGENTS.md|"
  "devin|Devin CLI|devin||https://devin.ai|$HOME_DIR/.devin|AGENTS.md|"
  "continue|Continue|continue||https://continue.dev|$HOME_DIR/.continue|AGENTS.md|"
)

# 人格源: 优先用脚本同目录的 eri.md, 否则从 RAW_URL 下载
# 注意: 只有最后一行(文件路径)输出到 stdout, 其余提示信息走 stderr,
#       避免被 $(...) 命令替换捕获后污染文件路径
get_persona_source() {
  if [ -f "$SCRIPT_DIR/eri.md" ]; then
    echo "==> 使用本地人格文件: $SCRIPT_DIR/eri.md" >&2
    echo "$SCRIPT_DIR/eri.md"
    return 0
  fi
  # 复用本脚本运行期间已下载的缓存文件,避免多工具重复下载
  if [ -f "$DL_CACHE" ]; then
    echo "==> 复用已下载人格文件: $DL_CACHE" >&2
    echo "$DL_CACHE"
    return 0
  fi
  echo "==> 下载人格文件: $RAW_URL" >&2
  if ! curl -fsSL "$RAW_URL" -o "$DL_CACHE"; then
    rm -f "$DL_CACHE"
    echo "==> 下载失败: $RAW_URL" >&2
    return 1
  fi
  echo "$DL_CACHE"
}

# 按工具的人格设定模板部署
deploy_persona() {
  local pdir="$1" pfile="$2" mode="$3" src="$4"
  if [ "$mode" = "aider" ]; then
    mkdir -p "$pdir"
    local persona_file="$pdir/$pfile"
    cp "$src" "$persona_file"
    local cfg="$HOME_DIR/.aider.conf.yml"
    if [ -f "$cfg" ]; then
      cp "$cfg" "$cfg.bak"
      echo "==> 备份旧配置: $cfg.bak"
      # sed 使用 | 作为替换分隔符, 需转义路径中的 & \ | 防止被解释
      local esc
      esc="$(printf '%s' "$persona_file" | sed 's/[&\\|]/\\&/g')"
      if grep -q '^read:' "$cfg"; then
        sed -i "s|^read:.*|read: $esc|" "$cfg"
      else
        echo "read: $persona_file" >> "$cfg"
      fi
    else
      echo "read: $persona_file" > "$cfg"
    fi
    echo "==> 人格已部署: $persona_file (aider 已配置 read)"
    return
  fi
  mkdir -p "$pdir"
  local target="$pdir/$pfile"
  if [ -f "$target" ]; then
    cp "$target" "$target.bak"
    echo "==> 备份旧文件: $target.bak"
  fi
  cp "$src" "$target"
  echo "==> 人格已部署: $target"
}

# 单个工具的完整部署流程
deploy_one() {
  local line="$1"
  IFS='|' read -ra F <<< "$line"
  # read -a 会丢弃行尾空字段, 补足 8 个字段防止 set -u 越界
  while [ "${#F[@]}" -lt 8 ]; do F+=(""); done
  local name="${F[1]}" cmd="${F[2]}" install="${F[3]}" site="${F[4]}" pdir="${F[5]}" pfile="${F[6]}" mode="${F[7]}"
  local ans
  echo ""
  echo "==== 部署: $name (检查命令: $cmd) ===="
  # type -P 只匹配 PATH 中的真实可执行文件, 避免 command -v
  # 误命中 shell 保留字/内建命令(如 continue、if)导致假阳性检测
  if type -P "$cmd" >/dev/null 2>&1; then
    echo "==> 已检测到本地安装: $(type -P "$cmd")"
    local src; src="$(get_persona_source)" || { echo "==> 无法获取人格文件,跳过 $name" >&2; return 1; }
    deploy_persona "$pdir" "$pfile" "$mode" "$src"
    echo "==> 完成!重启 $name 生效"
    return
  fi
  echo "==> 未检测到 $name,开始按官方方式安装..."
  if [ -n "$install" ]; then
    if [ "$INTERACTIVE" -eq 1 ]; then
      if ! read -rp "是否执行官方安装命令? [Y/n]  $install " ans; then ans="n"; fi
    else
      ans="n"
    fi
    if [ "$ans" != "n" ] && [ "$ans" != "N" ]; then
      echo "==> 执行: $install"
      eval "$install"
    fi
  else
    echo "==> 请按官网指引安装: $site"
    if [ "$INTERACTIVE" -eq 1 ]; then
      if ! read -rp "是否用浏览器打开官网? [Y/n] " open; then open="n"; fi
    else
      open="n"
    fi
    if [ "$open" != "n" ] && [ "$open" != "N" ]; then
      if command -v xdg-open >/dev/null 2>&1; then xdg-open "$site"
      elif type -P open >/dev/null 2>&1; then open "$site"
      else echo "==> 请手动访问: $site"; fi
    fi
  fi
  # 检查循环: 确认安装完成后再部署人格
  while true; do
    if type -P "$cmd" >/dev/null 2>&1; then
      echo "==> 安装确认成功: $(type -P "$cmd")"
      local src2; src2="$(get_persona_source)" || { echo "==> 无法获取人格文件,跳过 $name" >&2; return 1; }
      deploy_persona "$pdir" "$pfile" "$mode" "$src2"
      echo "==> 完成!重启 $name 生效"
      return
    fi
    if [ "$INTERACTIVE" -eq 0 ]; then
      echo "==> 非交互模式,未检测到 $cmd,跳过 $name 的人格部署"
      return
    fi
    if ! read -rp "尚未检测到 $cmd。安装完成了吗? 回车重新检查 / 输入 n 跳过 " ans; then
      echo "==> 已跳过 $name 的人格部署"
      return
    fi
    if [ "$ans" = "n" ] || [ "$ans" = "N" ]; then
      echo "==> 已跳过 $name 的人格部署"
      return
    fi
  done
}

# ---------- 主流程 ----------
echo ""
echo "=============================================="
echo "  绘里酱 (eri) 人格 · 交互式部署"
echo "=============================================="
echo ""
echo "支持的终端编程工具:"
for i in "${!TOOLS[@]}"; do
  IFS='|' read -ra F <<< "${TOOLS[$i]}"
  printf "  %2d. %-24s 检查命令: %s\n" "$((i + 1))" "${F[1]}" "${F[2]}"
done

if [ "$INTERACTIVE" -eq 1 ]; then
  while true; do
    echo ""
    if ! read -rp "请选择工具编号(支持逗号多选,如 1,2,5; 输入 q 退出): " choice; then
      break
    fi
    # 去除首尾空白(含 Tab)后再判断, 兼容 " q " 这类输入
    case "${choice//[[:space:]]/}" in
      q|Q) break ;;
    esac
    ok=0
    IFS=',， ' read -ra NUMS <<< "$choice"
    for n in "${NUMS[@]}"; do
      if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#TOOLS[@]}" ]; then
        deploy_one "${TOOLS[$((n - 1))]}"
        ok=1
      fi
    done
    [ "$ok" -eq 0 ] && echo "==> 输入无效,请重新选择"
  done
else
  # 非交互模式(curl | bash 一键): 自动部署已装工具;零工具时自动安装 opencode
  echo ""
  echo "==> 检测到非交互模式(stdin 非终端),自动部署所有已安装的工具..."
  deployed=0
  for i in "${!TOOLS[@]}"; do
    IFS='|' read -ra F <<< "${TOOLS[$i]}"
    while [ "${#F[@]}" -lt 8 ]; do F+=(""); done
    if type -P "${F[2]}" >/dev/null 2>&1; then
      # 仅在真正部署成功后计数,避免下载失败等情况误报"已部署"
      if deploy_one "${TOOLS[$i]}"; then
        deployed=1
      fi
    fi
  done
  if [ "$deployed" -eq 0 ]; then
    # 一键安装语义: 零工具时自动安装旗舰工具 opencode(需要 node/npm)
    echo "==> 没有成功部署任何已安装的工具,尝试一键安装 opencode ..."
    IFS='|' read -ra FF <<< "${TOOLS[0]}"
    while [ "${#FF[@]}" -lt 8 ]; do FF+=(""); done
    if command -v npm >/dev/null 2>&1 && [ -n "${FF[3]}" ]; then
      echo "==> 执行: ${FF[3]}"
      eval "${FF[3]}"
      if type -P "${FF[2]}" >/dev/null 2>&1; then
        if deploy_one "${TOOLS[0]}"; then
          deployed=1
        fi
      else
        echo "==> opencode 安装未成功,请手动安装: ${FF[3]}"
      fi
    else
      echo "==> 未找到 npm,无法自动安装 opencode"
      echo "    请先安装 nodejs/npm,或用交互模式选择工具: bash install-eri.sh"
    fi
  fi
  if [ "$deployed" -eq 0 ]; then
    echo "==> 仍未部署任何工具(安装失败,或人格文件获取失败)"
    echo "    请用交互模式选择并安装工具: bash install-eri.sh"
  fi
fi
echo ""
echo "==> 部署完成!记得重启对应工具,让绘里酱人格生效♡"

# ---------- 注册更新短命令 (eri) ----------
RC="$HOME_DIR/.bashrc"
if [ -f "$HOME_DIR/.zshrc" ]; then
  RC="$HOME_DIR/.zshrc"
fi
AGENTS_DIR="$HOME_DIR/.config/opencode/agents"
if ! grep -q '^eri()' "$RC" 2>/dev/null; then
  printf '\n# eri persona updater\neri() {\n  mkdir -p "%s"\n  curl -fsSL "%s" -o "%s/eri.md" && echo "eri updated, restart your tool"\n}\n' "$AGENTS_DIR" "$RAW_URL" "$AGENTS_DIR" >> "$RC"
  echo "==> short command 'eri' added, run: source $RC"
else
  echo "==> short command 'eri' already exists"
fi