#!/usr/bin/env bash
# ============================================================
# install-eri.sh - 绘里酱人格 · 交互式/一键部署 (Linux/macOS/Termux/WSL/Git-Bash)
# 用法: bash install-eri.sh [RAW_URL]
# 交互模式: 选择工具 -> 查找本地路径 -> 已装则部署人格 /
#           未装则按官网方式安装 -> 检查确认安装完成后部署人格
# 非交互模式 (curl | bash 一键): 自动部署已装工具;
#           零工具时自动安装旗舰工具 opencode 并部署人格
# 附: 部署完成后会注册独立可执行命令 `eri`,
#     用 `eri update` 刷新人格, `eri uninstall` 整体卸载
#     (见文件末尾)
# ============================================================
set -uo pipefail

INTERACTIVE=1
[ -t 0 ] || INTERACTIVE=0

DEFAULT_URL="https://raw.githubusercontent.com/nino-natsume/eri/main/eri.md"
RAW_URL="${1:-$DEFAULT_URL}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-}"
DL_CACHE="${TMPDIR:-/tmp}/eri.$$.md"

cleanup() { rm -f "$DL_CACHE"; }
trap cleanup EXIT INT TERM

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

get_persona_source() {
  if [ -f "$SCRIPT_DIR/eri.md" ]; then
    echo "==> 使用本地人格文件: $SCRIPT_DIR/eri.md" >&2
    echo "$SCRIPT_DIR/eri.md"
    return 0
  fi
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

jsonc_set_key() {
  local file="$1" key="$2" val="$3" tmp="${file}.tmp.$$"
  if grep -q "\"$key\"[[:space:]]*:" "$file"; then
    sed -i "s/\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"$key\": \"$val\"/" "$file"
    return
  fi
  awk -v k="$key" -v v="$val" '
    { buf[NR] = $0 }
    END {
      ci = 0
      for (i = NR; i >= 1; i--) if (buf[i] ~ /^[[:space:]]*}/) { ci = i; break }
      if (ci == 0) {
        print "{"
        print "  \"" k "\": \"" v "\""
        print "}"
        exit
      }
      last = ci - 1
      while (last >= 1 && buf[last] ~ /^[[:space:]]*$/) last--
      for (i = 1; i < ci; i++) {
        if (i == last) {
          s = buf[i]
          sub(/[[:space:]]+$/, "", s)
          if (s !~ /,$/ && s !~ /\{$/) s = s ","
          print s
        } else {
          print buf[i]
        }
      }
      print "  \"" k "\": \"" v "\""
      for (i = ci; i <= NR; i++) print buf[i]
    }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

enable_tool_config() {
  local id="$1" pdir="$2" pfile="$3"
  case "$id" in
    opencode)
      local opcfg_dir opcfg agent_name
      opcfg_dir="$(dirname "$pdir")"
      opcfg="$opcfg_dir/opencode.jsonc"
      agent_name="${pfile%.md}"
      if [ -f "$opcfg" ]; then
        cp "$opcfg" "$opcfg.bak"
        echo "==> 备份旧配置: $opcfg.bak"
        jsonc_set_key "$opcfg" "default_agent" "$agent_name"
      else
        printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "default_agent": "%s"\n}\n' "$agent_name" > "$opcfg"
      fi
      echo "==> OpenCode 配置已更新: $opcfg (default_agent = $agent_name)"
      ;;
  esac
}

deploy_persona() {
  local id="$1" pdir="$2" pfile="$3" mode="$4" src="$5"

  if [ "$mode" = "aider" ]; then
    mkdir -p "$pdir"
    local persona_file="$pdir/$pfile"
    cp "$src" "$persona_file"
    local cfg="$HOME_DIR/.aider.conf.yml"
    if [ -f "$cfg" ]; then
      cp "$cfg" "$cfg.bak"
      echo "==> 备份旧配置: $cfg.bak"
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
  enable_tool_config "$id" "$pdir" "$pfile"
}

deploy_one() {
  local line="$1"
  IFS='|' read -ra F <<< "$line"
  while [ "${#F[@]}" -lt 8 ]; do F+=(""); done
  local id="${F[0]}" name="${F[1]}" cmd="${F[2]}" install="${F[3]}" site="${F[4]}" pdir="${F[5]}" pfile="${F[6]}" mode="${F[7]}"
  local ans
  echo ""
  echo "==== 部署: $name (检查命令: $cmd) ===="
  if type -P "$cmd" >/dev/null 2>&1; then
    echo "==> 已检测到本地安装: $(type -P "$cmd")"
    local src; src="$(get_persona_source)" || { echo "==> 无法获取人格文件,跳过 $name" >&2; return 1; }
    deploy_persona "$id" "$pdir" "$pfile" "$mode" "$src"
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
  while true; do
    if type -P "$cmd" >/dev/null 2>&1; then
      echo "==> 安装确认成功: $(type -P "$cmd")"
      local src2; src2="$(get_persona_source)" || { echo "==> 无法获取人格文件,跳过 $name" >&2; return 1; }
      deploy_persona "$id" "$pdir" "$pfile" "$mode" "$src2"
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
  echo ""
  echo "==> 检测到非交互模式(stdin 非终端),自动部署所有已安装的工具..."
  deployed=0
  for i in "${!TOOLS[@]}"; do
    IFS='|' read -ra F <<< "${TOOLS[$i]}"
    while [ "${#F[@]}" -lt 8 ]; do F+=(""); done
    if type -P "${F[2]}" >/dev/null 2>&1; then
      if deploy_one "${TOOLS[$i]}"; then
        deployed=1
      fi
    fi
  done
  if [ "$deployed" -eq 0 ]; then
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

# ============================================================
# 注册更新短命令 (eri update / eri uninstall)
# ============================================================
BIN_DIR="$HOME_DIR/.local/bin"
ERI_BIN="$BIN_DIR/eri"
mkdir -p "$BIN_DIR"

if [ -f "$ERI_BIN" ]; then
  cp "$ERI_BIN" "$ERI_BIN.bak" 2>/dev/null || true
fi

cat > "$ERI_BIN" <<'ERI_EOF'
#!/usr/bin/env bash
# eri - 绘里酱人格管理工具
# 由 install-eri.sh 生成; 可独立运行
#
# 用法:
#   eri update [RAW_URL]    更新人格到所有已安装的终端工具 (默认命令)
#   eri uninstall [--yes]   卸载所有已部署的人格和 eri 命令
#   eri help                显示帮助
#   eri <RAW_URL>           兼容简写, 等价于 eri update <RAW_URL>
#
# 环境变量:
#   ERI_URL                 自定义人格文件 URL
set -uo pipefail

DEFAULT_URL="https://raw.githubusercontent.com/nino-natsume/eri/main/eri.md"
HOME_DIR="${HOME:-}"
BIN_DIR="$HOME_DIR/.local/bin"
ERI_BIN="$BIN_DIR/eri"

show_help() {
  cat <<'HELP'
eri - 绘里酱人格管理工具

用法:
  eri update [RAW_URL]    更新人格到所有已安装的终端工具 (默认命令)
  eri uninstall [--yes]   卸载所有已部署的人格文件和 eri 命令
                          (不带 --yes 时会在交互式终端里二次确认)
  eri help                显示帮助
  eri <RAW_URL>           兼容简写, 等价于 eri update <RAW_URL>

环境变量:
  ERI_URL                 自定义人格文件 URL

常见问题:
  若提示 'eri: command not found', 请执行:
    export PATH="$HOME/.local/bin:$PATH"
  或打开一个新终端窗口。
HELP
}

do_uninstall() {
  local yes_flag="${1:-}"
  echo "==> 绘里酱人格卸载"
  echo ""
  echo "将执行以下操作:"
  echo "  • 删除/恢复各工具的人格文件 (如 .bak 存在则恢复备份)"
  echo "  • 清理 OpenCode default_agent 与 aider read 配置"
  echo "  • 删除命令: $ERI_BIN"
  echo "  • 从 shell 配置中移除本脚本添加的 PATH 行"
  echo ""

  if [ "$yes_flag" != "--yes" ] && [ "$yes_flag" != "-y" ]; then
    if [ -t 0 ]; then
      local ans
      if ! read -rp "确认卸载? [y/N] " ans; then ans="n"; fi
      if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
        echo "==> 已取消"
        return 0
      fi
    else
      echo "==> 非交互模式, 如需静默卸载请加 --yes (eri uninstall --yes)" >&2
      return 1
    fi
  fi

  local TOOLS=(
    "opencode|opencode|$HOME_DIR/.config/opencode/agents|eri.md|"
    "claude|claude|$HOME_DIR/.claude|CLAUDE.md|"
    "codex|codex|$HOME_DIR/.codex|AGENTS.md|"
    "gemini|gemini|$HOME_DIR/.gemini|GEMINI.md|"
    "qwen|qwen|$HOME_DIR/.qwen|GEMINI.md|"
    "aider|aider|$HOME_DIR/.config/aider|eri.md|aider"
    "cursor|cursor-agent|$HOME_DIR/.cursor|AGENTS.md|"
    "windsurf|windsurf|$HOME_DIR/.windsurf|AGENTS.md|"
    "amp|amp|$HOME_DIR/.amp|AGENTS.md|"
    "goose|goose|$HOME_DIR/.config/goose|AGENTS.md|"
    "copilot|copilot|$HOME_DIR/.github/copilot|AGENTS.md|"
    "plandex|plandex|$HOME_DIR/.plandex|AGENTS.md|"
    "tabby|tabby-agent|$HOME_DIR/.tabby|AGENTS.md|"
    "fabric|fabric|$HOME_DIR/.config/fabric|AGENTS.md|"
    "openhands|openhands|$HOME_DIR/.openhands|AGENTS.md|"
    "crush|crush|$HOME_DIR/.crush|AGENTS.md|"
    "devin|devin|$HOME_DIR/.devin|AGENTS.md|"
    "continue|continue|$HOME_DIR/.continue|AGENTS.md|"
  )

  local entry id cmd pdir pfile mode target
  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r id cmd pdir pfile mode <<< "$entry"
    target="$pdir/$pfile"
    [ -e "$target" ] || continue
    if [ -e "$target.bak" ]; then
      mv -f "$target.bak" "$target"
      echo "  已恢复: $target (来自备份)"
    else
      rm -f "$target"
      echo "  已删除: $target"
    fi
  done

  local aider_cfg="$HOME_DIR/.aider.conf.yml"
  if [ -f "$aider_cfg" ]; then
    if [ -f "$aider_cfg.bak" ]; then
      mv -f "$aider_cfg.bak" "$aider_cfg"
      echo "  已恢复: $aider_cfg (来自备份)"
    elif grep -q '^read:.*eri\.md' "$aider_cfg"; then
      local tmp1="${aider_cfg}.eri_uninst.$$"
      grep -v '^read:.*eri\.md' "$aider_cfg" > "$tmp1" && mv "$tmp1" "$aider_cfg"
      echo "  已清理: $aider_cfg (移除 read:)"
    fi
  fi

  local opcfg="$HOME_DIR/.config/opencode/opencode.jsonc"
  if [ -f "$opcfg.bak" ]; then
    mv -f "$opcfg.bak" "$opcfg"
    echo "  已恢复: $opcfg (来自备份)"
  elif [ -f "$opcfg" ] && grep -q '"default_agent"[[:space:]]*:[[:space:]]*"eri"' "$opcfg"; then
    local tmp2="${opcfg}.eri_uninst.$$"
    grep -v '"default_agent"[[:space:]]*:[[:space:]]*"eri"' "$opcfg" > "$tmp2" && mv "$tmp2" "$opcfg"
    echo "  已清理: $opcfg (移除 default_agent)"
  fi

  local rc
  for rc in \
    "$HOME_DIR/.bashrc" "$HOME_DIR/.bash_profile" "$HOME_DIR/.zshrc" \
    "$HOME_DIR/.profile" "$HOME_DIR/.zprofile" "$HOME_DIR/.kshrc" \
    "$HOME_DIR/.config/fish/config.fish" \
    "$HOME_DIR/.tcshrc" "$HOME_DIR/.cshrc"
  do
    [ -f "$rc" ] || continue
    if grep -qF '# eri: ensure ~/.local/bin in PATH' "$rc" 2>/dev/null; then
      local tmp3="${rc}.eri_uninst.$$"
      awk '
        /^# eri: ensure ~\/\.local\/bin in PATH$/ { getline; next }
        { print }
      ' "$rc" > "$tmp3" && mv "$tmp3" "$rc"
      echo "  已清理 PATH: $rc"
    fi
  done

  if [ -f "$ERI_BIN" ]; then
    rm -f "$ERI_BIN" "$ERI_BIN.bak"
    echo "  已删除命令: $ERI_BIN"
  fi

  echo ""
  echo "==> 卸载完成! 新开终端生效♡"
}

sub="${1:-update}"
case "$sub" in
  update) shift ;;
  uninstall|remove|rm)
    shift
    do_uninstall "${1:-}"
    exit $?
    ;;
  help|-h|--help) show_help; exit 0 ;;
  *) ;;
esac

RAW_URL="${1:-${ERI_URL:-$DEFAULT_URL}}"

if command -v mktemp >/dev/null 2>&1; then
  DL="$(mktemp "${TMPDIR:-/tmp}/eri.XXXXXX.md" 2>/dev/null)" || DL="${TMPDIR:-/tmp}/eri.$$.md"
else
  DL="${TMPDIR:-/tmp}/eri.$$.md"
fi
cleanup() { rm -f "$DL"; }
trap cleanup EXIT INT TERM

echo "==> 下载人格文件: $RAW_URL"
if ! curl -fsSL "$RAW_URL" -o "$DL"; then
  echo "==> 下载失败: $RAW_URL" >&2
  exit 1
fi

jsonc_set_key() {
  local file="$1" key="$2" val="$3" tmp="${file}.tmp.$$"
  if grep -q "\"$key\"[[:space:]]*:" "$file"; then
    sed -i "s/\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"$key\": \"$val\"/" "$file"
    return
  fi
  awk -v k="$key" -v v="$val" '
    { buf[NR] = $0 }
    END {
      ci = 0
      for (i = NR; i >= 1; i--) if (buf[i] ~ /^[[:space:]]*}/) { ci = i; break }
      if (ci == 0) { print "{"; print "  \"" k "\": \"" v "\""; print "}"; exit }
      last = ci - 1
      while (last >= 1 && buf[last] ~ /^[[:space:]]*$/) last--
      for (i = 1; i < ci; i++) {
        if (i == last) {
          s = buf[i]
          sub(/[[:space:]]+$/, "", s)
          if (s !~ /,$/ && s !~ /\{$/) s = s ","
          print s
        } else { print buf[i] }
      }
      print "  \"" k "\": \"" v "\""
      for (i = ci; i <= NR; i++) print buf[i]
    }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

enable_tool_config() {
  local id="$1" pdir="$2" pfile="$3"
  case "$id" in
    opencode)
      local opcfg_dir opcfg agent_name
      opcfg_dir="$(dirname "$pdir")"
      opcfg="$opcfg_dir/opencode.jsonc"
      agent_name="${pfile%.md}"
      if [ -f "$opcfg" ]; then
        jsonc_set_key "$opcfg" "default_agent" "$agent_name"
      else
        printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "default_agent": "%s"\n}\n' "$agent_name" > "$opcfg"
      fi
      echo "    opencode.jsonc: default_agent = $agent_name"
      ;;
  esac
}

TOOLS=(
  "opencode|opencode|$HOME_DIR/.config/opencode/agents|eri.md|"
  "claude|claude|$HOME_DIR/.claude|CLAUDE.md|"
  "codex|codex|$HOME_DIR/.codex|AGENTS.md|"
  "gemini|gemini|$HOME_DIR/.gemini|GEMINI.md|"
  "qwen|qwen|$HOME_DIR/.qwen|GEMINI.md|"
  "aider|aider|$HOME_DIR/.config/aider|eri.md|aider"
  "cursor|cursor-agent|$HOME_DIR/.cursor|AGENTS.md|"
  "windsurf|windsurf|$HOME_DIR/.windsurf|AGENTS.md|"
  "amp|amp|$HOME_DIR/.amp|AGENTS.md|"
  "goose|goose|$HOME_DIR/.config/goose|AGENTS.md|"
  "copilot|copilot|$HOME_DIR/.github/copilot|AGENTS.md|"
  "plandex|plandex|$HOME_DIR/.plandex|AGENTS.md|"
  "tabby|tabby-agent|$HOME_DIR/.tabby|AGENTS.md|"
  "fabric|fabric|$HOME_DIR/.config/fabric|AGENTS.md|"
  "openhands|openhands|$HOME_DIR/.openhands|AGENTS.md|"
  "crush|crush|$HOME_DIR/.crush|AGENTS.md|"
  "devin|devin|$HOME_DIR/.devin|AGENTS.md|"
  "continue|continue|$HOME_DIR/.continue|AGENTS.md|"
)

count=0
for entry in "${TOOLS[@]}"; do
  IFS='|' read -r id cmd pdir pfile mode <<< "$entry"
  if ! type -P "$cmd" >/dev/null 2>&1; then continue; fi
  mkdir -p "$pdir"
  cp "$DL" "$pdir/$pfile"
  echo "  updated: $pdir/$pfile"

  if [ "$mode" = "aider" ]; then
    cfg="$HOME_DIR/.aider.conf.yml"
    persona_file="$pdir/$pfile"
    if [ -f "$cfg" ]; then
      if grep -q '^read:' "$cfg"; then
        esc="$(printf '%s' "$persona_file" | sed 's/[&\\|]/\\&/g')"
        sed -i "s|^read:.*|read: $esc|" "$cfg"
      else
        echo "read: $persona_file" >> "$cfg"
      fi
    else
      echo "read: $persona_file" > "$cfg"
    fi
  fi

  enable_tool_config "$id" "$pdir" "$pfile"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "==> 未检测到任何已安装的终端工具, 请先运行 install-eri.sh" >&2
  exit 1
fi
echo "==> 已更新 $count 个工具的人格文件, 重启对应工具生效♡"
ERI_EOF

chmod +x "$ERI_BIN"
echo "==> 已创建可执行命令: $ERI_BIN"

remove_old_eri_func() {
  local rc="$1"
  [ -f "$rc" ] || return 0
  grep -q '^eri()' "$rc" 2>/dev/null || return 0
  local tmp="${rc}.eri_tmp.$$"
  awk '
    /^# eri persona updater/ { skip=1; next }
    skip && /^\}/ { skip=0; next }
    !skip
  ' "$rc" > "$tmp" && mv "$tmp" "$rc"
  echo "==> 已移除旧的 eri() shell 函数: $rc"
}

for rc in \
  "$HOME_DIR/.bashrc" "$HOME_DIR/.bash_profile" "$HOME_DIR/.zshrc" \
  "$HOME_DIR/.profile" "$HOME_DIR/.zprofile" "$HOME_DIR/.kshrc" \
  "$HOME_DIR/.config/fish/config.fish" \
  "$HOME_DIR/.tcshrc" "$HOME_DIR/.cshrc"
do
  remove_old_eri_func "$rc"
done

ensure_path_posix() {
  local rc="$1" line="$2"
  [ -f "$rc" ] || return 0
  if grep -qF '# eri: ensure ~/.local/bin in PATH' "$rc" 2>/dev/null; then
    return 0
  fi
  printf '\n# eri: ensure ~/.local/bin in PATH\n%s\n' "$line" >> "$rc"
  echo "==> 已添加 PATH 到: $rc"
}

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
FISH_LINE='fish_add_path $HOME/.local/bin'
TCSH_LINE='setenv PATH "$HOME/.local/bin:$PATH"'

any_rc=0
for rc in \
  "$HOME_DIR/.bashrc" "$HOME_DIR/.bash_profile" "$HOME_DIR/.zshrc" \
  "$HOME_DIR/.profile" "$HOME_DIR/.zprofile" "$HOME_DIR/.kshrc" \
  "$HOME_DIR/.config/fish/config.fish" \
  "$HOME_DIR/.tcshrc" "$HOME_DIR/.cshrc"
do
  [ -f "$rc" ] && any_rc=1
done
[ "$any_rc" -eq 0 ] && : > "$HOME_DIR/.profile"

for rc in \
  "$HOME_DIR/.profile" "$HOME_DIR/.bashrc" "$HOME_DIR/.bash_profile" \
  "$HOME_DIR/.zshrc" "$HOME_DIR/.zprofile" "$HOME_DIR/.kshrc"
do
  ensure_path_posix "$rc" "$PATH_LINE"
done
[ -d "$HOME_DIR/.config/fish" ] && ensure_path_posix "$HOME_DIR/.config/fish/config.fish" "$FISH_LINE"
[ -f "$HOME_DIR/.tcshrc" ] && ensure_path_posix "$HOME_DIR/.tcshrc" "$TCSH_LINE"
[ -f "$HOME_DIR/.cshrc" ]  && ensure_path_posix "$HOME_DIR/.cshrc"  "$TCSH_LINE"

echo "==> 短命令 'eri update' / 'eri uninstall' 已就绪"

conflicts=""
hijack_files=""
ERI_BIN_DIR="$(dirname "$ERI_BIN")"
seen_our_dir=0
IFS=':' read -ra _dirs <<< "$PATH"
for d in "${_dirs[@]}"; do
  [ -z "$d" ] && continue
  if [ "$d" = "$ERI_BIN_DIR" ]; then
    seen_our_dir=1
    continue
  fi
  for f in "$d/eri" "$d/eri.exe" "$d/eri.cmd" "$d/eri.ps1" "$d/eri.bat"; do
    [ -e "$f" ] || continue
    [ "$f" = "$ERI_BIN" ] && continue
    conflicts="${conflicts}${f}"$'\n'
    [ "$seen_our_dir" -eq 0 ] && hijack_files="${hijack_files}${f}"$'\n'
  done
done

if [ -n "$conflicts" ]; then
  echo ""
  echo "==> 警告: PATH 中存在其他 'eri' 命令, 可能抢占短命令:"
  printf '%s' "$conflicts" | sed 's/^/    - /'

  if [ -n "$hijack_files" ]; then
    echo ""
    echo "    以下冲突位于 $ERI_BIN_DIR 之前, 会抢占 'eri' 短命令:"
    printf '%s' "$hijack_files" | sed 's/^/    ⚠ /'

    if [ "$INTERACTIVE" -eq 1 ]; then
      if read -rp "是否自动遮蔽这些冲突 (重命名为 <name>.eri-disabled)? [Y/n] " ans; then
        if [ "$ans" != "n" ] && [ "$ans" != "N" ]; then
          while IFS= read -r c; do
            [ -z "$c" ] && continue
            [ -e "$c" ] || continue
            [ "$c" = "$ERI_BIN" ] && continue
            if mv "$c" "$c.eri-disabled" 2>/dev/null; then
              echo "    已遮蔽: $c -> $c.eri-disabled"
            else
              echo "    无法重命名 (权限不足): $c"
              echo "      请手动处理: sudo mv '$c' '$c.eri-disabled'"
            fi
          done <<< "$hijack_files"
        fi
      fi
    else
      echo "    (非交互模式, 跳过自动遮蔽; 可手动: mv '<file>' '<file>.eri-disabled')"
    fi
  fi

  if printf '%s' "$conflicts" | grep -qE '(npm|node_modules)'; then
    echo "    上述位置疑似 npm 全局包 (如 'eri-blog') 生成的命令, 建议卸载:"
    echo "          npm uninstall -g eri-blog"
    if [ "$INTERACTIVE" -eq 1 ] && command -v npm >/dev/null 2>&1; then
      if read -rp "是否现在执行 'npm uninstall -g eri-blog'? [Y/n] " ans; then
        if [ "$ans" != "n" ] && [ "$ans" != "N" ]; then
          npm uninstall -g eri-blog || echo "==> 卸载失败, 请手动处理"
        fi
      fi
    fi
  fi
  echo "    如果新开终端后 'eri' 仍命中其他位置, 请检查 PATH 顺序, 或重开终端"
else
  echo "==> 未检测到冲突的 eri 命令"
fi

echo ""
echo "==> 验证 'eri' 命令..."
if command -v eri >/dev/null 2>&1; then
  RESOLVED="$(command -v eri)"
  if [ "$RESOLVED" = "$ERI_BIN" ]; then
    echo "    ✓ 'eri' 已正确解析到: $RESOLVED"
    echo "      可以立即执行: eri help / eri update / eri uninstall"
  else
    echo "    ⚠ 'eri' 当前解析到: $RESOLVED (期望 $ERI_BIN)"
    echo "      请执行: hash -r; exec \$SHELL"
  fi
else
  echo "    ⚠ 当前 shell 尚未识别 'eri' 命令"
  echo "      任选其一立即生效:"
  echo "        - 打开新终端窗口"
  echo "        - 执行: export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo "        - 执行: hash -r; exec \$SHELL"
fi