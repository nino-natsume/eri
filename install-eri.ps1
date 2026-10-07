# ============================================================
# install-eri.ps1 - 绘里酱人格 · 交互式/一键部署 (Windows)
# 用法: powershell -ExecutionPolicy Bypass -File install-eri.ps1
#
# ⚠️  本文件必须保存为 UTF-8 with BOM, 否则 Windows PowerShell 5.1
#    会按系统 ANSI 代码页(中文 Windows 为 GBK)解码, 导致中文字符串乱码、
#    引号被吞并报"字符串缺少终止符"错误。
#    VSCode: 右下角编码 -> Save with Encoding -> UTF-8 with BOM
#    PowerShell: Set-Content -Encoding UTF8BOM  (PS7)
#    或使用记事本"另存为"时选择"UTF-8 带 BOM"
# ============================================================
param(
  [string]$RawUrl = "https://raw.githubusercontent.com/nino-natsume/eri/main/eri.md"
)

$ErrorActionPreference = "Stop"

$Interactive = -not [Console]::IsInputRedirected

# ---------- 工具注册表 ----------
$Tools = @(
  [pscustomobject]@{ id = "opencode";  name = "OpenCode";                cmd = "opencode";      install = "npm install -g opencode-ai";                          site = "https://opencode.ai";                                pdir = "$env:USERPROFILE\.config\opencode\agents"; pfile = "eri.md" }
  [pscustomobject]@{ id = "claude";    name = "Claude Code";             cmd = "claude";        install = "npm install -g @anthropic-ai/claude-code";            site = "https://code.claude.com";                             pdir = "$env:USERPROFILE\.claude";                   pfile = "CLAUDE.md" }
  [pscustomobject]@{ id = "codex";     name = "Codex CLI (OpenAI)";      cmd = "codex";         install = "npm install -g @openai/codex";                         site = "https://developers.openai.com/codex";                  pdir = "$env:USERPROFILE\.codex";                    pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "gemini";    name = "Gemini CLI (Google)";     cmd = "gemini";        install = "npm install -g @google/gemini-cli";                    site = "https://github.com/google-gemini/gemini-cli";          pdir = "$env:USERPROFILE\.gemini";                   pfile = "GEMINI.md" }
  [pscustomobject]@{ id = "qwen";      name = "Qwen Code (Alibaba)";     cmd = "qwen";          install = "npm install -g @qwen-code/qwen-code@latest";            site = "https://github.com/QwenLM/qwen-code";                 pdir = "$env:USERPROFILE\.qwen";                     pfile = "GEMINI.md" }
  [pscustomobject]@{ id = "aider";     name = "Aider";                   cmd = "aider";         install = "python -m pip install -U aider-chat";                  site = "https://aider.chat";                                   pdir = "$env:USERPROFILE\.config\aider";            pfile = "eri.md"; mode = "aider" }
  [pscustomobject]@{ id = "cursor";    name = "Cursor CLI";              cmd = "cursor-agent";  install = "";                                                       site = "https://cursor.com/docs/cli/installation";             pdir = "$env:USERPROFILE\.cursor";                   pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "windsurf";  name = "Windsurf CLI";            cmd = "windsurf";      install = "";                                                       site = "https://docs.windsurf.com";                           pdir = "$env:USERPROFILE\.windsurf";                 pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "amp";       name = "Amp";                     cmd = "amp";           install = "";                                                       site = "https://ampcode.com";                                 pdir = "$env:USERPROFILE\.amp";                      pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "goose";     name = "Goose (Block)";           cmd = "goose";         install = "";                                                       site = "https://block.github.io/goose/";                      pdir = "$env:USERPROFILE\.config\goose";            pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "copilot";   name = "GitHub Copilot CLI";      cmd = "copilot";       install = "npm install -g @github/copilot";                        site = "https://github.com/github/copilot-cli";               pdir = "$env:USERPROFILE\.github\copilot";          pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "plandex";   name = "Plandex";                 cmd = "plandex";       install = "npm install -g plandex";                                site = "https://plandex.ai";                                  pdir = "$env:USERPROFILE\.plandex";                  pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "tabby";     name = "Tabby";                   cmd = "tabby-agent";   install = "npm install -g tabby-agent";                            site = "https://tabbyml.com";                                 pdir = "$env:USERPROFILE\.tabby";                    pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "fabric";    name = "Fabric";                  cmd = "fabric";        install = "go install github.com/danielmiessler/fabric@latest";     site = "https://github.com/danielmiessler/fabric";            pdir = "$env:USERPROFILE\.config\fabric";           pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "openhands"; name = "OpenHands";               cmd = "openhands";     install = "python -m pip install -U openhands-ai";                 site = "https://docs.all-hands.dev";                          pdir = "$env:USERPROFILE\.openhands";                pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "crush";     name = "Crush";                   cmd = "crush";         install = "";                                                       site = "https://crush.chat";                                  pdir = "$env:USERPROFILE\.crush";                    pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "devin";     name = "Devin CLI";               cmd = "devin";         install = "";                                                       site = "https://devin.ai";                                    pdir = "$env:USERPROFILE\.devin";                    pfile = "AGENTS.md" }
  [pscustomobject]@{ id = "continue";  name = "Continue";                cmd = "continue";      install = "";                                                       site = "https://continue.dev";                                pdir = "$env:USERPROFILE\.continue";                 pfile = "AGENTS.md" }
)

# ---------- 人格源 ----------
function Get-PersonaSource {
  $local = Join-Path $PSScriptRoot "eri.md"
  if (Test-Path -LiteralPath $local) {
    Write-Host "==> 使用本地人格文件: $local"
    return $local
  }
  Write-Host "==> 下载人格文件: $RawUrl"
  $tmp = Join-Path $env:TEMP "eri.md"
  try {
    Invoke-WebRequest -Uri $RawUrl -OutFile $tmp -UseBasicParsing
  } catch {
    Write-Host "==> 下载失败: $RawUrl"
    return $null
  }
  return $tmp
}

# ---------- OpenCode 配置 ----------
function Set-OpenCodeDefaultAgent {
  param([string]$ConfigPath, [string]$AgentName)

  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $defaultCfg = "{`n  `"`$schema`": `"https://opencode.ai/config.json`",`n  `"default_agent`": `"$AgentName`"`n}`n"

  if (-not (Test-Path -LiteralPath $ConfigPath)) {
    [System.IO.File]::WriteAllText($ConfigPath, $defaultCfg, $utf8)
    Write-Host "==> OpenCode 配置已创建: $ConfigPath (default_agent = $AgentName)"
    return
  }

  Copy-Item -LiteralPath $ConfigPath -Destination "$ConfigPath.bak" -Force
  Write-Host "==> 备份旧配置: $ConfigPath.bak"

  $content = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8

  if ($content -match '"default_agent"\s*:') {
    $content = [regex]::Replace($content, '"default_agent"\s*:\s*"[^"]*"', "`"default_agent`": `"$AgentName`"")
    [System.IO.File]::WriteAllText($ConfigPath, $content, $utf8)
    Write-Host "==> OpenCode 配置已更新: $ConfigPath (default_agent = $AgentName)"
    return
  }

  $idx = $content.LastIndexOf("}")
  if ($idx -lt 0) {
    [System.IO.File]::WriteAllText($ConfigPath, $defaultCfg, $utf8)
    Write-Host "==> OpenCode 配置已重写: $ConfigPath (default_agent = $AgentName)"
    return
  }

  $head = $content.Substring(0, $idx).TrimEnd()
  $tail = $content.Substring($idx)
  if ($head.EndsWith(",")) { $head = $head.Substring(0, $head.Length - 1).TrimEnd() }

  if ($head.EndsWith("{")) {
    $content = "$head`n  `"default_agent`": `"$AgentName`"`n$tail"
  } else {
    $content = "$head,`n  `"default_agent`": `"$AgentName`"`n$tail"
  }
  [System.IO.File]::WriteAllText($ConfigPath, $content, $utf8)
  Write-Host "==> OpenCode 配置已更新: $ConfigPath (default_agent = $AgentName)"
}

# ---------- 工具专属配置派发 ----------
function Enable-ToolConfig {
  param($tool)
  switch ($tool.id) {
    "opencode" {
      $opcfgDir = Split-Path $tool.pdir -Parent
      $opcfg = Join-Path $opcfgDir "opencode.jsonc"
      $agentName = [System.IO.Path]::GetFileNameWithoutExtension($tool.pfile)
      Set-OpenCodeDefaultAgent -ConfigPath $opcfg -AgentName $agentName
    }
  }
}

# ---------- 按工具部署人格 ----------
function Deploy-Persona($tool, $src) {
  if ($tool.mode -eq "aider") {
    New-Item -ItemType Directory -Force -Path $tool.pdir | Out-Null
    $personaFile = Join-Path $tool.pdir $tool.pfile
    Copy-Item -LiteralPath $src -Destination $personaFile -Force
    $cfg = Join-Path $env:USERPROFILE ".aider.conf.yml"
    if (Test-Path -LiteralPath $cfg) {
      Copy-Item -LiteralPath $cfg -Destination "$cfg.bak" -Force
      Write-Host "==> 备份旧配置: $cfg.bak"
      $content = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8
      if ($content -match "(?m)^read\s*:") {
        $content = $content -replace "(?m)^read\s*:.*$", "read: $personaFile"
      } else {
        $content = $content.TrimEnd() + "`nread: $personaFile`n"
      }
      [System.IO.File]::WriteAllText($cfg, $content, (New-Object System.Text.UTF8Encoding($false)))
    } else {
      [System.IO.File]::WriteAllText($cfg, "read: $personaFile`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    Write-Host "==> 人格已部署: $personaFile (aider 已配置 read)"
    return
  }

  New-Item -ItemType Directory -Force -Path $tool.pdir | Out-Null
  $target = Join-Path $tool.pdir $tool.pfile
  if (Test-Path -LiteralPath $target) {
    Copy-Item -LiteralPath $target -Destination "$target.bak" -Force
    Write-Host "==> 备份旧文件: $target.bak"
  }
  Copy-Item -LiteralPath $src -Destination $target -Force
  Write-Host "==> 人格已部署: $target"
  Enable-ToolConfig $tool
}

# ---------- 单个工具部署流程 ----------
function Deploy-One($tool) {
  Write-Host ""
  Write-Host "==== 部署: $($tool.name) (检查命令: $($tool.cmd)) ===="
  $found = Get-Command $tool.cmd -ErrorAction SilentlyContinue
  if ($found) {
    Write-Host "==> 已检测到本地安装: $($found.Source)"
    $src = Get-PersonaSource
    if (-not $src) { Write-Host "==> 无法获取人格文件,跳过 $($tool.name)"; return }
    Deploy-Persona $tool $src
    Write-Host "==> 完成!重启 $($tool.name) 生效"
    return
  }
  Write-Host "==> 未检测到 $($tool.name),开始按官方方式安装..."
  if ($tool.install) {
    if ($Interactive) {
      $ans = Read-Host "是否执行官方安装命令? [Y/n]`n    $($tool.install)"
    } else {
      Write-Host "==> 非交互模式,跳过安装命令: $($tool.install)"
      $ans = "n"
    }
    if ($ans -ne "n" -and $ans -ne "N") {
      Write-Host "==> 执行: $($tool.install)"
      try { Invoke-Expression $tool.install } catch { Write-Host "==> 安装命令执行失败: $_" }
    }
  } else {
    Write-Host "==> 请按官网指引安装: $($tool.site)"
    if ($Interactive) {
      $open = Read-Host "是否用浏览器打开官网? [Y/n]"
    } else {
      Write-Host "==> 非交互模式,跳过"
      $open = "n"
    }
    if ($open -ne "n" -and $open -ne "N") { Start-Process $tool.site }
  }
  while ($true) {
    $found = Get-Command $tool.cmd -ErrorAction SilentlyContinue
    if ($found) {
      Write-Host "==> 安装确认成功: $($found.Source)"
      $src = Get-PersonaSource
      if (-not $src) { Write-Host "==> 无法获取人格文件,跳过 $($tool.name)"; return }
      Deploy-Persona $tool $src
      Write-Host "==> 完成!重启 $($tool.name) 生效"
      return
    }
    if (-not $Interactive) {
      Write-Host "==> 非交互模式,未检测到 $($tool.cmd),跳过 $($tool.name) 的人格部署"
      return
    }
    $ans = Read-Host "尚未检测到 $($tool.cmd)。安装完成了吗? 回车重新检查 / 输入 n 跳过"
    if ($ans -eq "n" -or $ans -eq "N") {
      Write-Host "==> 已跳过 $($tool.name) 的人格部署"
      return
    }
  }
}

# ---------- 主流程 ----------
Write-Host ""
Write-Host "=============================================="
Write-Host "  绘里酱 (eri) 人格 · 交互式部署"
Write-Host "=============================================="
Write-Host ""
Write-Host "支持的终端编程工具:"
for ($i = 0; $i -lt $Tools.Count; $i++) {
  Write-Host ("  {0,2}. {1,-24} 检查命令: {2}" -f ($i + 1), $Tools[$i].name, $Tools[$i].cmd)
}

if ($Interactive) {
  while ($true) {
    Write-Host ""
    $choice = Read-Host "请选择工具编号(支持逗号多选,如 1,2,5; 输入 q 退出)"
    if (-not $choice) { continue }
    $choice = $choice.Trim()
    if ($choice -match "^[qQ]$") { break }
    $nums = @($choice -split "[,\s，]+" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^\d+$" } | ForEach-Object { [int]$_ })
    if ($nums.Count -eq 0) { Write-Host "==> 输入无效,请重新选择"; continue }
    foreach ($n in $nums) {
      if ($n -ge 1 -and $n -le $Tools.Count) { Deploy-One $Tools[$n - 1] }
    }
  }
} else {
  Write-Host ""
  Write-Host "==> 检测到非交互模式(stdin 非终端),自动部署所有已安装的工具..."
  $deployed = $false
  foreach ($tool in $Tools) {
    if (Get-Command $tool.cmd -ErrorAction SilentlyContinue) {
      Deploy-One $tool
      $deployed = $true
    }
  }
  if (-not $deployed) {
    Write-Host "==> 没有成功部署任何已安装的工具,尝试一键安装 opencode ..."
    $opencode = $Tools[0]
    if ((Get-Command npm -ErrorAction SilentlyContinue) -and $opencode.install) {
      Write-Host "==> 执行: $($opencode.install)"
      try { Invoke-Expression $opencode.install } catch { Write-Host "==> opencode 安装命令执行失败: $_" }
      if (Get-Command $opencode.cmd -ErrorAction SilentlyContinue) {
        Deploy-One $opencode
        $deployed = $true
      } else {
        Write-Host "==> opencode 安装未成功,请手动安装: $($opencode.install)"
      }
    } else {
      Write-Host "==> 未找到 npm,无法自动安装 opencode"
      Write-Host "    请先安装 nodejs/npm,或用交互模式选择工具: powershell -ExecutionPolicy Bypass -File install-eri.ps1"
    }
  }
  if (-not $deployed) {
    Write-Host "==> 仍未部署任何工具(安装失败,或人格文件获取失败)"
    Write-Host "    请用交互模式选择并安装工具: powershell -ExecutionPolicy Bypass -File install-eri.ps1"
  }
}
Write-Host ""
Write-Host "==> 部署完成!记得重启对应工具,让绘里酱人格生效♡"

# ============================================================
# 注册更新短命令 (eri update)
# ============================================================
$BinDir = Join-Path $env:USERPROFILE ".local\bin"
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

$EriPs1 = Join-Path $BinDir "eri-core.ps1"
$EriCmd = Join-Path $BinDir "eri.cmd"

# ---------- 1. 生成 eri-core.ps1 ----------
# ⚠️  关键: 必须用 UTF-8 with BOM 写入, 否则 Windows PowerShell 5.1 会按
#    系统 ANSI 代码页(中文 Windows 为 GBK)解码, 导致中文乱码、引号被吞,
#    进而报 "字符串缺少终止符" 的 ParserError。
$eriPs1Content = @'
# eri - 绘里酱人格管理工具
# 由 install-eri.ps1 生成; 可独立运行
#
# 用法:
#   eri update [RAW_URL]    更新人格到所有已安装的终端工具 (默认命令)
#   eri help                显示帮助
#   eri <RAW_URL>           兼容简写, 等价于 eri update <RAW_URL>
param(
  [Parameter(Position = 0)][string]$Command = "update",
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest = @()
)
$ErrorActionPreference = "Stop"

$DEFAULT_URL = "https://raw.githubusercontent.com/nino-natsume/eri/main/eri.md"

function Show-Help {
  @"
eri - 绘里酱人格管理工具

用法:
  eri update [RAW_URL]    更新人格到所有已安装的终端工具 (默认命令)
  eri help                显示帮助
  eri <RAW_URL>           兼容简写, 等价于 eri update <RAW_URL>

环境变量:
  ERI_URL                 自定义人格文件 URL
"@
}

$RawUrl = ""
switch -Regex ($Command.ToLower()) {
  "^update$" {
    if ($Rest.Count -gt 0) { $RawUrl = $Rest[0] }
    elseif ($env:ERI_URL)  { $RawUrl = $env:ERI_URL }
    else                   { $RawUrl = $DEFAULT_URL }
  }
  "^(help|-h|--help)$" { Show-Help; exit 0 }
  default {
    $RawUrl = $Command
    if (-not $RawUrl) {
      if ($env:ERI_URL) { $RawUrl = $env:ERI_URL } else { $RawUrl = $DEFAULT_URL }
    }
  }
}

$tmp = Join-Path $env:TEMP ("eri-" + [guid]::NewGuid().ToString("N") + ".md")
Write-Host "==> 下载人格文件: $RawUrl"
try {
  Invoke-WebRequest -Uri $RawUrl -OutFile $tmp -UseBasicParsing
} catch {
  Write-Host "==> 下载失败: $RawUrl"
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
  exit 1
}

function Set-OpenCodeDefaultAgent {
  param([string]$ConfigPath, [string]$AgentName)
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $defaultCfg = "{`n  `"`$schema`": `"https://opencode.ai/config.json`",`n  `"default_agent`": `"$AgentName`"`n}`n"
  if (-not (Test-Path -LiteralPath $ConfigPath)) {
    [System.IO.File]::WriteAllText($ConfigPath, $defaultCfg, $utf8); return
  }
  $content = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
  if ($content -match '"default_agent"\s*:') {
    $content = [regex]::Replace($content, '"default_agent"\s*:\s*"[^"]*"', "`"default_agent`": `"$AgentName`"")
    [System.IO.File]::WriteAllText($ConfigPath, $content, $utf8); return
  }
  $idx = $content.LastIndexOf("}")
  if ($idx -lt 0) { [System.IO.File]::WriteAllText($ConfigPath, $defaultCfg, $utf8); return }
  $head = $content.Substring(0, $idx).TrimEnd()
  $tail = $content.Substring($idx)
  if ($head.EndsWith(",")) { $head = $head.Substring(0, $head.Length - 1).TrimEnd() }
  if ($head.EndsWith("{")) {
    $content = "$head`n  `"default_agent`": `"$AgentName`"`n$tail"
  } else {
    $content = "$head,`n  `"default_agent`": `"$AgentName`"`n$tail"
  }
  [System.IO.File]::WriteAllText($ConfigPath, $content, $utf8)
}

$Tools = @(
  @{ id = "opencode"; cmd = "opencode";     pdir = "$env:USERPROFILE\.config\opencode\agents"; pfile = "eri.md";    mode = "" }
  @{ id = "claude";   cmd = "claude";       pdir = "$env:USERPROFILE\.claude";                   pfile = "CLAUDE.md"; mode = "" }
  @{ id = "codex";    cmd = "codex";        pdir = "$env:USERPROFILE\.codex";                    pfile = "AGENTS.md"; mode = "" }
  @{ id = "gemini";   cmd = "gemini";       pdir = "$env:USERPROFILE\.gemini";                   pfile = "GEMINI.md"; mode = "" }
  @{ id = "qwen";     cmd = "qwen";         pdir = "$env:USERPROFILE\.qwen";                     pfile = "GEMINI.md"; mode = "" }
  @{ id = "aider";    cmd = "aider";        pdir = "$env:USERPROFILE\.config\aider";             pfile = "eri.md";    mode = "aider" }
  @{ id = "cursor";   cmd = "cursor-agent"; pdir = "$env:USERPROFILE\.cursor";                   pfile = "AGENTS.md"; mode = "" }
  @{ id = "windsurf"; cmd = "windsurf";     pdir = "$env:USERPROFILE\.windsurf";                 pfile = "AGENTS.md"; mode = "" }
  @{ id = "amp";      cmd = "amp";          pdir = "$env:USERPROFILE\.amp";                      pfile = "AGENTS.md"; mode = "" }
  @{ id = "goose";    cmd = "goose";        pdir = "$env:USERPROFILE\.config\goose";             pfile = "AGENTS.md"; mode = "" }
  @{ id = "copilot";  cmd = "copilot";      pdir = "$env:USERPROFILE\.github\copilot";           pfile = "AGENTS.md"; mode = "" }
  @{ id = "plandex";  cmd = "plandex";      pdir = "$env:USERPROFILE\.plandex";                  pfile = "AGENTS.md"; mode = "" }
  @{ id = "tabby";    cmd = "tabby-agent";  pdir = "$env:USERPROFILE\.tabby";                    pfile = "AGENTS.md"; mode = "" }
  @{ id = "fabric";   cmd = "fabric";       pdir = "$env:USERPROFILE\.config\fabric";            pfile = "AGENTS.md"; mode = "" }
  @{ id = "openhands";cmd = "openhands";    pdir = "$env:USERPROFILE\.openhands";                pfile = "AGENTS.md"; mode = "" }
  @{ id = "crush";    cmd = "crush";        pdir = "$env:USERPROFILE\.crush";                    pfile = "AGENTS.md"; mode = "" }
  @{ id = "devin";    cmd = "devin";        pdir = "$env:USERPROFILE\.devin";                    pfile = "AGENTS.md"; mode = "" }
  @{ id = "continue"; cmd = "continue";     pdir = "$env:USERPROFILE\.continue";                 pfile = "AGENTS.md"; mode = "" }
)

$count = 0
foreach ($tool in $Tools) {
  if (-not (Get-Command $tool.cmd -ErrorAction SilentlyContinue)) { continue }
  New-Item -ItemType Directory -Force -Path $tool.pdir | Out-Null
  $target = Join-Path $tool.pdir $tool.pfile
  Copy-Item -LiteralPath $tmp -Destination $target -Force
  Write-Host "  updated: $target"

  if ($tool.mode -eq "aider") {
    $cfg = Join-Path $env:USERPROFILE ".aider.conf.yml"
    if (Test-Path -LiteralPath $cfg) {
      $content = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8
      if ($content -match "(?m)^read\s*:") {
        $content = $content -replace "(?m)^read\s*:.*$", "read: $target"
      } else {
        $content = $content.TrimEnd() + "`nread: $target`n"
      }
      [System.IO.File]::WriteAllText($cfg, $content, (New-Object System.Text.UTF8Encoding($false)))
    } else {
      [System.IO.File]::WriteAllText($cfg, "read: $target`n", (New-Object System.Text.UTF8Encoding($false)))
    }
  }

  if ($tool.id -eq "opencode") {
    $opcfgDir = Split-Path $tool.pdir -Parent
    $opcfg = Join-Path $opcfgDir "opencode.jsonc"
    $agentName = [System.IO.Path]::GetFileNameWithoutExtension($tool.pfile)
    Set-OpenCodeDefaultAgent -ConfigPath $opcfg -AgentName $agentName
    Write-Host "    opencode.jsonc: default_agent = $agentName"
  }

  $count++
}

Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue

if ($count -eq 0) {
  Write-Host "==> 未检测到任何已安装的终端工具, 请先运行 install-eri.ps1"
  exit 1
}
Write-Host "==> 已更新 $count 个工具的人格文件, 重启对应工具生效♡"
'@

# ---- 关键修复: 用 UTF-8 with BOM 写入, PS 5.1 才会正确按 UTF-8 解析 ----
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($EriPs1, $eriPs1Content, $utf8Bom)

# ---------- 2. 生成 eri.cmd (纯 ASCII, 无编码问题) ----------
$eriCmdContent = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0eri-core.ps1" %*
'@
# cmd.exe 偏好 CRLF 行尾
$eriCmdContent = $eriCmdContent -replace '\r?\n', "`r`n"
$ascii = New-Object System.Text.ASCIIEncoding
[System.IO.File]::WriteAllText($EriCmd, $eriCmdContent, $ascii)

Write-Host "==> 已创建可执行命令: $EriCmd"

# ---------- 3. 把 $BinDir 前置到用户 PATH ----------
# 必须"前置", 否则会被 npm 全局目录 (AppData\Roaming\npm) 抢占
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($null -eq $userPath) { $userPath = "" }

$existing = @($userPath -split ';' | Where-Object {
  $_ -and $_.Trim() -ne "" -and ($_.TrimEnd('\') -ne $BinDir.TrimEnd('\'))
})
$newPath = (@($BinDir) + $existing) -join ';'

if ($userPath -ne $newPath) {
  [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
  Write-Host "==> 已将 $BinDir 前置到用户 PATH (新开终端生效)"
} else {
  Write-Host "==> $BinDir 已在用户 PATH 最前"
}

# 当前会话也刷新, 便于立即验证
$envExisting = @($env:PATH -split ';' | Where-Object {
  $_ -and $_.Trim() -ne "" -and ($_.TrimEnd('\') -ne $BinDir.TrimEnd('\'))
})
$env:PATH = (@($BinDir) + $envExisting) -join ';'

Write-Host "==> 短命令 'eri update' 已就绪"

# ============================================================
# 冲突检测: PATH 里可能还有别的 eri (例如 npm 全局包 eri-blog)
# ============================================================
$expectedCmd = Join-Path $BinDir "eri.cmd"
$conflicts = @(Get-Command eri -All -ErrorAction SilentlyContinue | Where-Object {
  $_.CommandType -eq 'Application' -and
  $_.Source -and
  ($_.Source.TrimEnd('\') -ne $expectedCmd.TrimEnd('\'))
})

if ($conflicts.Count -gt 0) {
  Write-Host ""
  Write-Host "==> 警告: PATH 中存在其他 'eri' 命令, 可能抢占短命令:"
  foreach ($c in $conflicts) {
    Write-Host "    - $($c.Source)"
  }

  $npmEr = @($conflicts | Where-Object { $_.Source -match '\\npm\\' -or $_.Source -match 'AppData\\Roaming\\npm' })
  if ($npmEr.Count -gt 0) {
    Write-Host "    上述位置疑似 npm 全局包 (如 'eri-blog') 生成的命令, 建议卸载:"
    Write-Host "          npm uninstall -g eri-blog"
    if ($Interactive -and (Get-Command npm -ErrorAction SilentlyContinue)) {
      $ans = Read-Host "是否现在执行 'npm uninstall -g eri-blog'? [Y/n]"
      if ($ans -ne "n" -and $ans -ne "N") {
        try {
          npm uninstall -g eri-blog
          Write-Host "==> 已卸载 eri-blog"
        } catch {
          Write-Host "==> 卸载失败, 请手动执行: npm uninstall -g eri-blog"
        }
      }
    }
  }
  Write-Host "    若新开终端后 'eri' 仍命中其他位置, 请检查 PATH 顺序或重开终端"
} else {
  Write-Host "==> 未检测到冲突的 eri 命令"
}
