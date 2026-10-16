# ============================================================
# install-eri.ps1 - 绘里酱人格 · 交互式/一键部署 (Windows)
# 用法: powershell -ExecutionPolicy Bypass -File install-eri.ps1
# 菜单 0 = OpenCode 深度集成（skill + 5 子智慧体 + personality 插件 + mood）
# 资源查找顺序: /usr/share/eri > 脚本所在目录 (仓库克隆)
#
# 附: 部署完成后会注册独立可执行命令 `eri`,
#     用 `eri update` 刷新人格, `eri uninstall` 整体卸载
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

# Windows PowerShell 5.1 默认仅启用 TLS 1.0, 访问 GitHub (raw.githubusercontent.com)
# 会报 "无法建立 SSL/TLS 安全通道"。显式开启 TLS 1.2 (存在则叠加 1.3)。
try {
  $tls = [Net.SecurityProtocolType]::Tls12
  if ([Enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls13') { $tls = $tls -bor [Net.SecurityProtocolType]::Tls13 }
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $tls
} catch { }

$Interactive = -not [Console]::IsInputRedirected

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

# ---------- 深度部署资源查找: 包内(pacman) > 脚本同目录(仓库克隆) ----------
function Find-DeepSrc {
  foreach ($d in @("/usr/share/eri", $PSScriptRoot)) {
    if ($d -and (Test-Path -LiteralPath (Join-Path $d "personality.json"))) {
      Write-Host "==> 使用深度部署资源: $d"
      return $d
    }
  }
  return $null
}

# 兼容 仓库扁平布局($dir/SKILL.md) 与 打包布局($dir/skill/eri/SKILL.md)
function Get-DeepFile {
  param([string]$Dir, [string]$Rel, [string]$Flat)
  $relPath = Join-Path $Dir ($Rel -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  if (Test-Path -LiteralPath $relPath) { return $relPath }
  $flatPath = Join-Path $Dir $Flat
  if (Test-Path -LiteralPath $flatPath) { return $flatPath }
  return $null
}

# ---------- 菜单 0：OpenCode 深度集成（skill + 5 子智慧体 + personality 插件 + mood） ----------
function Deploy-OpenCodeDeep {
  $src = Find-DeepSrc
  if (-not $src) {
    Write-Host "==> 错误：未找到深度部署资源(personality.json),请在仓库根目录运行本脚本"
    return $false
  }
  # opencode 未安装时不执行深度集成, 否则只会为已卸载的工具留下残留
  if (-not (Get-Command "opencode" -ErrorAction SilentlyContinue)) {
    Write-Host "==> 未检测到 opencode, 跳过深度集成 (深度集成为 opencode 专用, 避免为未安装的工具留下残留)"
    return $false
  }
  $cfg = Join-Path $env:USERPROFILE ".config\opencode"
  New-Item -ItemType Directory -Force -Path (Join-Path $cfg "agent"), (Join-Path $cfg "skill\eri") | Out-Null

  Copy-Item -LiteralPath (Join-Path $src "personality.json") -Destination (Join-Path $cfg "personality.json") -Force
  Write-Host "==> personality.json -> $cfg\personality.json"

  foreach ($a in @("erotic-chan", "code-monkey", "debug-san", "architect-sama", "test-chan")) {
    $f = Get-DeepFile -Dir $src -Rel "agent/$a.md" -Flat "$a.md"
    if ($f) {
      Copy-Item -LiteralPath $f -Destination (Join-Path $cfg "agent\$a.md") -Force
      Write-Host "==> agent/$a.md -> $cfg\agent\$a.md"
    } else {
      Write-Host "==> 警告：缺少子智慧体 $a.md,已跳过"
    }
  }

  $skill = Get-DeepFile -Dir $src -Rel "skill/eri/SKILL.md" -Flat "SKILL.md"
  if ($skill) {
    Copy-Item -LiteralPath $skill -Destination (Join-Path $cfg "skill\eri\SKILL.md") -Force
    Write-Host "==> SKILL.md -> $cfg\skill\eri\SKILL.md"
  } else {
    Write-Host "==> 警告：缺少 SKILL.md,skill 不可用"
  }

  # opencode 配置处理: 无配置 -> 写模板; 含 plugin -> 已深度集成(幂等跳过);
  # 缺深度字段(如轻量部署只写了 default_agent) -> 交互确认后备份覆盖, 并保留原 default_agent
  $oc = Join-Path $cfg "opencode.jsonc"
  if (-not (Test-Path -LiteralPath $oc) -and (Test-Path -LiteralPath (Join-Path $cfg "opencode.json"))) {
    $oc = Join-Path $cfg "opencode.json"
  }
  if (-not (Test-Path -LiteralPath $oc)) {
    Copy-Item -LiteralPath (Join-Path $src "opencode.json") -Destination (Join-Path $cfg "opencode.jsonc") -Force
    Write-Host "==> opencode.json -> $cfg\opencode.jsonc"
  } else {
    $content = Get-Content -LiteralPath $oc -Raw -Encoding UTF8
    if ($content -match '"plugin"') {
      Write-Host "==> 已有 opencode 配置含深度集成字段,跳过模板写入: $oc"
    } else {
      $writeTpl = $true
      if ($Interactive) {
        $ans = Read-Host "已有 opencode 配置缺少 plugin/skills 等深度字段,是否备份后用模板覆盖? [Y/n]"
        if ($ans -eq "n" -or $ans -eq "N") { $writeTpl = $false }
      }
      if ($writeTpl) {
        # 首触备份: 保留覆盖前的原始配置
        if (-not (Test-Path -LiteralPath "$oc.bak")) {
          Copy-Item -LiteralPath $oc -Destination "$oc.bak" -Force
          Write-Host "==> 备份旧配置: $oc.bak"
        }
        $oldDa = $null
        if ($content -match '"default_agent"\s*:\s*"([^"]*)"') { $oldDa = $Matches[1] }
        Copy-Item -LiteralPath (Join-Path $src "opencode.json") -Destination $oc -Force
        Write-Host "==> 深度配置已写入: $oc (旧配置在 .bak,可自行合并其中的自定义字段)"
        if ($oldDa) {
          $t = Get-Content -LiteralPath $oc -Raw -Encoding UTF8
          $idx = $t.LastIndexOf("}")
          if ($idx -ge 0) {
            $head = $t.Substring(0, $idx).TrimEnd()
            $tail = $t.Substring($idx)
            if ($head.EndsWith(",")) { $head = $head.Substring(0, $head.Length - 1).TrimEnd() }
            if ($head.EndsWith("{")) { $t = "$head`n  `"default_agent`": `"$oldDa`"`n$tail" }
            else { $t = "$head,`n  `"default_agent`": `"$oldDa`"`n$tail" }
            [System.IO.File]::WriteAllText($oc, $t, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "==> 已保留原 default_agent = $oldDa"
          }
        }
      } else {
        Write-Host "注意：请手动合并 $src/opencode.json 中的 plugin/agent/skills/command 字段到 $oc"
      }
    }
  }

  $srcManifest = Join-Path $src "opencode-package.json"
  if ((Test-Path -LiteralPath $srcManifest) -and -not (Test-Path -LiteralPath (Join-Path $cfg "package.json"))) {
    Copy-Item -LiteralPath $srcManifest -Destination (Join-Path $cfg "package.json") -Force
    Write-Host "==> package.json (OpenCode 依赖清单) -> $cfg\package.json"
  }

  # 一并带上 lock 文件, 让 npm install 复用清单锁定的依赖版本 (可复现构建)
  $srcLock = Join-Path $src "opencode-package-lock.json"
  if ((Test-Path -LiteralPath $srcLock) -and -not (Test-Path -LiteralPath (Join-Path $cfg "package-lock.json"))) {
    Copy-Item -LiteralPath $srcLock -Destination (Join-Path $cfg "package-lock.json") -Force
    Write-Host "==> package-lock.json -> $cfg\package-lock.json"
  }

  if (Get-Command npm -ErrorAction SilentlyContinue) {
    Push-Location $cfg
    try {
      & npm install --no-audit --no-fund
      if ($LASTEXITCODE -ne 0) {
        Write-Host "==> 错误：npm install 失败,请检查网络后在 $cfg 下重试"
        return $false
      }
    } finally {
      Pop-Location
    }
  } else {
    Write-Host "==> 错误：未找到 npm,请先安装 Node.js/npm 后重试"
    return $false
  }

  Write-Host "==> OpenCode 深度部署完成！重启 opencode 生效。"
  Write-Host "    之后可用 /personality 管理人格, /force-chat 与 /force-work 切换模式, /mood 设置心情。"
  return $true
}

function Set-OpenCodeDefaultAgent {
  param([string]$ConfigPath, [string]$AgentName)

  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $defaultCfg = "{`n  `"`$schema`": `"https://opencode.ai/config.json`",`n  `"default_agent`": `"$AgentName`"`n}`n"

  if (-not (Test-Path -LiteralPath $ConfigPath)) {
    [System.IO.File]::WriteAllText($ConfigPath, $defaultCfg, $utf8)
    Write-Host "==> OpenCode 配置已创建: $ConfigPath (default_agent = $AgentName)"
    return
  }

  # 首触备份: 不让后续重跑覆盖最初的配置
  if (-not (Test-Path -LiteralPath "$ConfigPath.bak")) {
    Copy-Item -LiteralPath $ConfigPath -Destination "$ConfigPath.bak" -Force
    Write-Host "==> 备份旧配置: $ConfigPath.bak"
  }

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

function Deploy-Persona($tool, $src) {
  if ($tool.mode -eq "aider") {
    New-Item -ItemType Directory -Force -Path $tool.pdir | Out-Null
    $personaFile = Join-Path $tool.pdir $tool.pfile
    Copy-Item -LiteralPath $src -Destination $personaFile -Force
    $cfg = Join-Path $env:USERPROFILE ".aider.conf.yml"
    if (Test-Path -LiteralPath $cfg) {
      # 首触备份: 保留用户最初的 aider 配置
      if (-not (Test-Path -LiteralPath "$cfg.bak")) {
        Copy-Item -LiteralPath $cfg -Destination "$cfg.bak" -Force
        Write-Host "==> 备份旧配置: $cfg.bak"
      }
      $content = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8
      if ($content -match [regex]::Escape($personaFile)) {
        Write-Host "==> aider read 已包含本路径,无需修改"
      } else {
        $lines = Get-Content -LiteralPath $cfg
        $done = $false
        $out = @(foreach ($ln in $lines) {
          if (-not $done -and $ln -match '^(?<ind>\s*)read\s*:\s*(?<val>.*)$') {
            $done = $true
            $val = $Matches['val'].Trim()
            $ind = $Matches['ind']
            if ($val -eq '') { $ln; "$ind  - $personaFile" }
            elseif ($val.StartsWith('[') -and $val.EndsWith(']')) {
              $inner = $val.Substring(1, $val.Length - 2).Trim()
              if ($inner -eq '') { "${ind}read: [$personaFile]" } else { "${ind}read: [$inner, $personaFile]" }
            }
            else { "read: $val $personaFile" }
          } else { $ln }
        })
        if (-not $done) { $out = @($out + "read: $personaFile") }
        [System.IO.File]::WriteAllLines($cfg, $out, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "==> 已追加到 aider read: $personaFile"
      }
    } else {
      [System.IO.File]::WriteAllText($cfg, "read: $personaFile`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    Write-Host "==> 人格已部署: $personaFile (aider 已配置 read)"
    return
  }

  New-Item -ItemType Directory -Force -Path $tool.pdir | Out-Null
  $target = Join-Path $tool.pdir $tool.pfile
  # 首触备份: 只在没有 .bak 时留底; 若目标已是我们部署过的内容(重跑), 不把自己的内容当备份
  if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath "$target.bak")) {
    $hSrc = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $hDst = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($hSrc -ne $hDst) {
      Copy-Item -LiteralPath $target -Destination "$target.bak" -Force
      Write-Host "==> 备份旧文件: $target.bak"
    }
  }
  Copy-Item -LiteralPath $src -Destination $target -Force
  Write-Host "==> 人格已部署: $target"
  Enable-ToolConfig $tool
}

function Test-IsOurPersona($Path) {
  # 判断某人格文件是否就是本工具部署的副本(与仓库 eri.md 内容一致), 用于安全识别残留
  $local = Join-Path $PSScriptRoot "eri.md"
  if (-not (Test-Path -LiteralPath $local)) { return $false }
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  try {
    return (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
  } catch { return $false }
}

function Remove-OrphanArtifacts($tool) {
  # 工具已被卸载但残留了我们写入的人格/配置: 回滚它们, 避免后续部署/卸载错乱
  $persona = Join-Path $tool.pdir $tool.pfile
  if (Test-Path -LiteralPath "$persona.bak") {
    Move-Item -LiteralPath "$persona.bak" -Destination $persona -Force
    Write-Host "  已恢复残留备份: $persona (来自 .bak)"
  } elseif (Test-IsOurPersona $persona) {
    Remove-Item -LiteralPath $persona -Force
    Write-Host "  已删除残留人格文件: $persona"
  }

  if ($tool.mode -eq "aider") {
    $cfg = Join-Path $env:USERPROFILE ".aider.conf.yml"
    if (Test-Path -LiteralPath $cfg) {
      $content = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8
      if ($content -match [regex]::Escape($persona)) {
        $lines = Get-Content -LiteralPath $cfg
        $out = @(foreach ($ln in $lines) {
          if ($ln -match [regex]::Escape($persona)) {
            if ($ln -match '^\s*-') { continue }
            $m = [regex]::Match($ln, '^(?<ind>\s*)read\s*:\s*(?<val>.*)$')
            if ($m.Success) {
              $val = $m.Groups['val'].Value.Trim()
              if ($val -eq '') { $ln }
              else {
                $toks = @($val -split '\s+' | Where-Object { $_ -and $_ -ne $persona })
                if ($toks.Count -gt 0) { $m.Groups['ind'].Value + 'read: ' + ($toks -join ' ') }
              }
            } else { $ln }
          } else { $ln }
        })
        [System.IO.File]::WriteAllLines($cfg, $out, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  已清理残留: $cfg (移除 read 路径)"
      }
    }
  }

  if ($tool.id -eq "opencode") {
    $opcfgDir = Split-Path $tool.pdir -Parent
    foreach ($name in @("opencode.jsonc", "opencode.json")) {
      $opcfg = Join-Path $opcfgDir $name
      if (Test-Path -LiteralPath "$opcfg.bak") {
        Move-Item -LiteralPath "$opcfg.bak" -Destination $opcfg -Force
        Write-Host "  已恢复残留备份: $opcfg (来自 .bak)"
      }
      if (-not (Test-Path -LiteralPath $opcfg)) { continue }
      $content = Get-Content -LiteralPath $opcfg -Raw -Encoding UTF8
      if ($content -match '"default_agent"\s*:\s*"eri"') {
        $content = [regex]::Replace($content, '\s*"default_agent"\s*:\s*"eri"\s*,?', '')
        $content = [regex]::Replace($content, ',\s*}', "`n}")
        [System.IO.File]::WriteAllText($opcfg, $content, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  已清理残留: $opcfg (移除 default_agent)"
      }
    }
    if (Test-Path -LiteralPath (Join-Path $opcfgDir "personality.json")) {
      Write-Host "  提示: opencode 深度集成文件仍残留($opcfgDir), 如需彻底清理可运行: eri uninstall"
    }
  }
}

function Clear-ToolResidueIfOrphaned($tool) {
  # 命令不存在但存在我们写入的残留 -> 回滚; 返回 $true 表示检测并处理了残留
  if (Get-Command $tool.cmd -ErrorAction SilentlyContinue) { return $false }
  $persona = Join-Path $tool.pdir $tool.pfile
  $hasResidue = (Test-Path -LiteralPath "$persona.bak") -or (Test-IsOurPersona $persona)
  if ($tool.mode -eq "aider") {
    $cfg = Join-Path $env:USERPROFILE ".aider.conf.yml"
    if ((Test-Path -LiteralPath $cfg) -and ((Get-Content -LiteralPath $cfg -Raw -Encoding UTF8) -match [regex]::Escape($persona))) { $hasResidue = $true }
  }
  if ($tool.id -eq "opencode") {
    $opcfgDir = Split-Path $tool.pdir -Parent
    foreach ($name in @("opencode.jsonc", "opencode.json")) {
      $opcfg = Join-Path $opcfgDir $name
      if (Test-Path -LiteralPath "$opcfg.bak") { $hasResidue = $true }
      if ((Test-Path -LiteralPath $opcfg) -and ((Get-Content -LiteralPath $opcfg -Raw -Encoding UTF8) -match '"default_agent"\s*:\s*"eri"')) { $hasResidue = $true }
    }
  }
  if (-not $hasResidue) { return $false }
  Write-Host "==> 检测到 $($tool.name) 已卸载但存在残留, 自动回滚..."
  Remove-OrphanArtifacts $tool
  return $true
}

function Deploy-One($tool) {
  Write-Host ""
  Write-Host "==== 部署: $($tool.name) (检查命令: $($tool.cmd)) ===="
  $found = Get-Command $tool.cmd -ErrorAction SilentlyContinue
  if ($found) {
    Write-Host "==> 已检测到本地安装: $($found.Source)"
    $src = Get-PersonaSource
    if (-not $src) { Write-Host "==> 无法获取人格文件,跳过 $($tool.name)"; return $false }
    Deploy-Persona $tool $src
    Write-Host "==> 完成!重启 $($tool.name) 生效"
    return $true
  }
  # 已卸载但残留: 先回滚残留, 避免带着旧状态继续按原步骤部署
  [void](Clear-ToolResidueIfOrphaned $tool)
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
      if (-not $src) { Write-Host "==> 无法获取人格文件,跳过 $($tool.name)"; return $false }
      Deploy-Persona $tool $src
      Write-Host "==> 完成!重启 $($tool.name) 生效"
      return $true
    }
    if (-not $Interactive) {
      Write-Host "==> 非交互模式,未检测到 $($tool.cmd),跳过 $($tool.name) 的人格部署"
      return $false
    }
    $ans = Read-Host "尚未检测到 $($tool.cmd)。安装完成了吗? 回车重新检查 / 输入 n 跳过"
    if ($ans -eq "n" -or $ans -eq "N") {
      Write-Host "==> 已跳过 $($tool.name) 的人格部署"
      return $false
    }
  }
}

Write-Host ""
Write-Host "=============================================="
Write-Host "  绘里酱 (eri) 人格 · 交互式部署"
Write-Host "=============================================="
Write-Host ""
Write-Host "  0. OpenCode 深度集成            （skill+子智慧体+personality 插件+mood）"
Write-Host "支持的终端编程工具（轻量人格部署）:"
for ($i = 0; $i -lt $Tools.Count; $i++) {
  Write-Host ("  {0,2}. {1,-24} 检查命令: {2}" -f ($i + 1), $Tools[$i].name, $Tools[$i].cmd)
}

if ($Interactive) {
  while ($true) {
    Write-Host ""
    $choice = Read-Host "请选择工具编号(0=OpenCode深度集成,支持逗号多选,如 0,1,5; 输入 q 退出)"
    if (-not $choice) { continue }
    $choice = $choice.Trim()
    if ($choice -match "^[qQ]$") { break }
    $nums = @($choice -split "[,\s，]+" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^\d+$" } | ForEach-Object { [int]$_ })
    if ($nums.Count -eq 0) { Write-Host "==> 输入无效,请重新选择"; continue }
    foreach ($n in $nums) {
      if ($n -eq 0) { [void](Deploy-OpenCodeDeep) }
      elseif ($n -ge 1 -and $n -le $Tools.Count) { [void](Deploy-One $Tools[$n - 1]) }
    }
  }
} else {
  Write-Host ""
  Write-Host "==> 检测到非交互模式(stdin 非终端),自动部署所有已安装的工具..."
  $deepSrc = Find-DeepSrc
  if ($deepSrc) {
    if (Get-Command "opencode" -ErrorAction SilentlyContinue) {
      Write-Host "==> 检测到本地深度资源($deepSrc),先执行 OpenCode 深度集成..."
      try { [void](Deploy-OpenCodeDeep) } catch { Write-Host "==> 深度集成未完全成功(不影响轻量人格部署): $_" }
    } else {
      Write-Host "==> 检测到本地深度资源, 但未检测到 opencode, 跳过深度集成(避免为未安装的工具留下残留)"
    }
  }
  $deployed = $false
  foreach ($tool in $Tools) {
    if (Get-Command $tool.cmd -ErrorAction SilentlyContinue) {
      if (Deploy-One $tool) { $deployed = $true }
    } else {
      [void](Clear-ToolResidueIfOrphaned $tool)
    }
  }
  if (-not $deployed) {
    Write-Host "==> 没有成功部署任何已安装的工具,尝试一键安装 opencode ..."
    $opencode = $Tools[0]
    if ((Get-Command npm -ErrorAction SilentlyContinue) -and $opencode.install) {
      Write-Host "==> 执行: $($opencode.install)"
      try { Invoke-Expression $opencode.install } catch { Write-Host "==> opencode 安装命令执行失败: $_" }
      if (Get-Command $opencode.cmd -ErrorAction SilentlyContinue) {
        if (Deploy-One $opencode) { $deployed = $true }
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

$BinDir = Join-Path $env:USERPROFILE ".local\bin"
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

$EriPs1 = Join-Path $BinDir "eri-core.ps1"
$EriCmd = Join-Path $BinDir "eri.cmd"

$eriPs1Content = @'
# eri - 绘里酱人格管理工具
# 由 install-eri.ps1 生成; 可独立运行
#
# 用法:
#   eri update [RAW_URL]    更新人格到所有已安装的终端工具 (默认命令)
#   eri uninstall [--yes]   卸载所有已部署的人格和 eri 命令
#   eri version             显示版本
#   eri help                显示帮助
#   eri <RAW_URL>           兼容简写, 等价于 eri update <RAW_URL>
param(
  [Parameter(Position = 0)][string]$Command = "update",
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest = @()
)
$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 默认仅启用 TLS 1.0, 访问 GitHub 会报 SSL/TLS 错误, 显式开启 TLS 1.2
try {
  $tls = [Net.SecurityProtocolType]::Tls12
  if ([Enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls13') { $tls = $tls -bor [Net.SecurityProtocolType]::Tls13 }
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $tls
} catch { }

$DEFAULT_URL = "https://raw.githubusercontent.com/nino-natsume/eri/main/eri.md"
$BinDir      = Join-Path $env:USERPROFILE ".local\bin"
$EriCmd      = Join-Path $BinDir "eri.cmd"
$EriPs1      = Join-Path $BinDir "eri-core.ps1"
$EriVersion  = "__ERI_VERSION__"   # 由 install-eri.ps1 从同目录 package.json 自动注入

function Show-Help {
  @"
eri - 绘里酱人格管理工具

用法:
  eri update [RAW_URL]    更新人格到所有已安装的终端工具 (默认命令)
  eri uninstall [--yes]   卸载所有已部署的人格文件和 eri 命令
                          (不带 --yes 时会在交互式终端里二次确认)
  eri help                显示帮助
  eri version             显示版本
  eri <RAW_URL>           兼容简写, 等价于 eri update <RAW_URL>

环境变量:
  ERI_URL                 自定义人格文件 URL

常见问题:
  若提示 'eri' 不是内部或外部命令, 请:
    - 打开一个新终端
    - 或执行: `$env:PATH = "$env:USERPROFILE\.local\bin;" + `$env:PATH
  完整 CLI (eri deep / eri version) 可用 npm 全局版: npm i -g eri-ai
"@
}

function Invoke-Uninstall {
  param([switch]$Yes)

  Write-Host "==> 绘里酱人格卸载"
  Write-Host ""
  Write-Host "将执行以下操作:"
  Write-Host "  • 删除/恢复各工具的人格文件 (如 .bak 存在则恢复备份)"
  Write-Host "  • 清理 OpenCode default_agent 与 aider read 配置"
  Write-Host "  • 删除命令: $EriCmd 和 $EriPs1"
  Write-Host "  • 从用户 PATH 中移除 $BinDir"
  Write-Host ""

  if (-not $Yes) {
    if ([Console]::IsInputRedirected) {
      Write-Host "==> 非交互模式, 如需静默卸载请加 --yes (eri uninstall --yes)"
      exit 1
    }
    $ans = Read-Host "确认卸载? [y/N]"
    if ($ans -notmatch '^[yY]') {
      Write-Host "==> 已取消"
      exit 0
    }
  }

  $Tools = @(
    @{ id = "opencode"; pdir = "$env:USERPROFILE\.config\opencode\agents"; pfile = "eri.md" }
    @{ id = "claude";   pdir = "$env:USERPROFILE\.claude";                   pfile = "CLAUDE.md" }
    @{ id = "codex";    pdir = "$env:USERPROFILE\.codex";                    pfile = "AGENTS.md" }
    @{ id = "gemini";   pdir = "$env:USERPROFILE\.gemini";                   pfile = "GEMINI.md" }
    @{ id = "qwen";     pdir = "$env:USERPROFILE\.qwen";                     pfile = "GEMINI.md" }
    @{ id = "aider";    pdir = "$env:USERPROFILE\.config\aider";             pfile = "eri.md" }
    @{ id = "cursor";   pdir = "$env:USERPROFILE\.cursor";                   pfile = "AGENTS.md" }
    @{ id = "windsurf"; pdir = "$env:USERPROFILE\.windsurf";                 pfile = "AGENTS.md" }
    @{ id = "amp";      pdir = "$env:USERPROFILE\.amp";                      pfile = "AGENTS.md" }
    @{ id = "goose";    pdir = "$env:USERPROFILE\.config\goose";             pfile = "AGENTS.md" }
    @{ id = "copilot";  pdir = "$env:USERPROFILE\.github\copilot";           pfile = "AGENTS.md" }
    @{ id = "plandex";  pdir = "$env:USERPROFILE\.plandex";                  pfile = "AGENTS.md" }
    @{ id = "tabby";    pdir = "$env:USERPROFILE\.tabby";                    pfile = "AGENTS.md" }
    @{ id = "fabric";   pdir = "$env:USERPROFILE\.config\fabric";            pfile = "AGENTS.md" }
    @{ id = "openhands";pdir = "$env:USERPROFILE\.openhands";                pfile = "AGENTS.md" }
    @{ id = "crush";    pdir = "$env:USERPROFILE\.crush";                    pfile = "AGENTS.md" }
    @{ id = "devin";    pdir = "$env:USERPROFILE\.devin";                    pfile = "AGENTS.md" }
    @{ id = "continue"; pdir = "$env:USERPROFILE\.continue";                 pfile = "AGENTS.md" }
  )

  foreach ($tool in $Tools) {
    $target = Join-Path $tool.pdir $tool.pfile
    if (-not (Test-Path -LiteralPath $target)) { continue }
    $bak = "$target.bak"
    if (Test-Path -LiteralPath $bak) {
      Move-Item -LiteralPath $bak -Destination $target -Force
      Write-Host "  已恢复: $target (来自备份)"
    } else {
      Remove-Item -LiteralPath $target -Force
      Write-Host "  已删除: $target"
    }
  }

  $aiderCfg = Join-Path $env:USERPROFILE ".aider.conf.yml"
  $myAiderPath = Join-Path $env:USERPROFILE ".config\aider\eri.md"
  if (Test-Path -LiteralPath "$aiderCfg.bak") {
    Move-Item -LiteralPath "$aiderCfg.bak" -Destination $aiderCfg -Force
    Write-Host "  已恢复: $aiderCfg (来自备份)"
  }
  # 重复部署会把本路径刷进备份, 恢复后再做 token 级清理 (只摘掉我们自己的路径, 保留用户其它 read 文件)
  if (Test-Path -LiteralPath $aiderCfg) {
    $lines = Get-Content -LiteralPath $aiderCfg
    $changed = $false
    $out = @(foreach ($ln in $lines) {
      if ($ln -match [regex]::Escape($myAiderPath)) {
        $changed = $true
        if ($ln -match '^\s*-') { continue }
        $m = [regex]::Match($ln, '^(?<ind>\s*)read\s*:\s*(?<val>.*)$')
        if ($m.Success) {
          $val = $m.Groups['val'].Value.Trim()
          $ind = $m.Groups['ind'].Value
          if ($val -eq '') { $ln }
          elseif ($val.StartsWith('[') -and $val.EndsWith(']')) {
            $items = @($val.Substring(1, $val.Length - 2) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne $myAiderPath })
            "${ind}read: [" + ($items -join ', ') + "]"
          }
          else {
            $toks = @($val -split '\s+' | Where-Object { $_ -and $_ -ne $myAiderPath })
            if ($toks.Count -gt 0) { $ind + 'read: ' + ($toks -join ' ') }
          }
        } else { $ln }
      } else { $ln }
    })
    if ($changed) {
      [System.IO.File]::WriteAllLines($aiderCfg, $out, (New-Object System.Text.UTF8Encoding($false)))
      Write-Host "  已清理: $aiderCfg (移除本工具的 read 路径)"
    }
  }

  # 恢复备份后再清理一次 default_agent (重复部署会把 eri 配置刷进 .bak)
  foreach ($cfgName in @("opencode.jsonc", "opencode.json")) {
    $opcfg = Join-Path (Join-Path $env:USERPROFILE ".config\opencode") $cfgName
    if (Test-Path -LiteralPath "$opcfg.bak") {
      Move-Item -LiteralPath "$opcfg.bak" -Destination $opcfg -Force
      Write-Host "  已恢复: $opcfg (来自备份)"
    }
    if (-not (Test-Path -LiteralPath $opcfg)) { continue }
    $content = Get-Content -LiteralPath $opcfg -Raw -Encoding UTF8
    if ($content -match '"default_agent"\s*:\s*"eri"') {
      $content = [regex]::Replace($content, '\s*"default_agent"\s*:\s*"eri"\s*,?', '')
      $content = [regex]::Replace($content, ',\s*}', "`n}")
      [System.IO.File]::WriteAllText($opcfg, $content, (New-Object System.Text.UTF8Encoding($false)))
      Write-Host "  已清理: $opcfg (移除 default_agent)"
    }
  }

  $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
  if ($userPath) {
    $parts = @($userPath -split ';' | Where-Object {
      $_ -and $_.Trim() -ne "" -and ($_.TrimEnd('\') -ne $BinDir.TrimEnd('\'))
    })
    $newPath = $parts -join ';'
    if ($newPath -ne $userPath) {
      [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
      Write-Host "  已从用户 PATH 移除: $BinDir"
    }
  }

  if (Test-Path -LiteralPath $EriCmd) { Remove-Item -LiteralPath $EriCmd -Force; Write-Host "  已删除: $EriCmd" }
  if (Test-Path -LiteralPath $EriPs1) { Remove-Item -LiteralPath $EriPs1 -Force; Write-Host "  已删除: $EriPs1" }

  # 还原安装时被遮蔽(重命名为 *.eri-disabled)的冲突命令
  $stateFile = Join-Path $BinDir ".eri-disabled.list"
  if (Test-Path -LiteralPath $stateFile) {
    foreach ($disabled in @(Get-Content -LiteralPath $stateFile -Encoding UTF8 | Where-Object { $_ })) {
      $orig = $disabled -replace '\.eri-disabled$', ''
      if ((Test-Path -LiteralPath $disabled) -and -not (Test-Path -LiteralPath $orig)) {
        try {
          Rename-Item -LiteralPath $disabled -NewName (Split-Path $orig -Leaf) -Force
          Write-Host "  已恢复被遮蔽的命令: $orig"
        } catch {
          Write-Host "  无法恢复(权限不足): $orig"
        }
      }
    }
    Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
  }

  # 清理空的 ~/.local/bin (仅当本工具的所有产物都已移除)
  if ((Test-Path -LiteralPath $BinDir) -and -not (Get-ChildItem -LiteralPath $BinDir -Force -ErrorAction SilentlyContinue)) {
    Remove-Item -LiteralPath $BinDir -Force -ErrorAction SilentlyContinue
  }

  # 彻底清理 OpenCode 深度集成残留(仅移除本工具写入的文件, 不误删用户自建内容)
  $deepCfg = Join-Path $env:USERPROFILE ".config\opencode"
  $deepRemoved = @()

  $deepPersona = Join-Path $deepCfg "personality.json"
  if (Test-Path -LiteralPath $deepPersona) { Remove-Item -LiteralPath $deepPersona -Force; $deepRemoved += $deepPersona }

  $skillFile = Join-Path $deepCfg "skill\eri\SKILL.md"
  if (Test-Path -LiteralPath $skillFile) { Remove-Item -LiteralPath $skillFile -Force; $deepRemoved += $skillFile }
  foreach ($d in @((Join-Path $deepCfg "skill\eri"), (Join-Path $deepCfg "skill"))) {
    if ((Test-Path -LiteralPath $d) -and -not (Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $d -Force }
  }

  $agentDir = Join-Path $deepCfg "agent"
  foreach ($a in @("erotic-chan", "code-monkey", "debug-san", "architect-sama", "test-chan")) {
    $f = Join-Path $agentDir "$a.md"
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force; $deepRemoved += $f }
  }
  if ((Test-Path -LiteralPath $agentDir) -and -not (Get-ChildItem -LiteralPath $agentDir -Force -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $agentDir -Force }

  $pkgJson = Join-Path $deepCfg "package.json"
  $ourPkg = (Test-Path -LiteralPath $pkgJson) -and ((Get-Content -LiteralPath $pkgJson -Raw -Encoding UTF8) -match '"opencode-personality"')
  if ($ourPkg) {
    foreach ($name in @("package.json", "package-lock.json")) {
      $f = Join-Path $deepCfg $name
      if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force; $deepRemoved += $f }
    }
    $nm = Join-Path $deepCfg "node_modules"
    if (Test-Path -LiteralPath $nm) { Remove-Item -LiteralPath $nm -Recurse -Force; $deepRemoved += $nm }
  }

  # 深度配置字段: 上方已按 .bak 恢复; 若该配置由本工具从零创建(无 .bak)且仍含本工具 plugin, 视为残留 -> 删除
  foreach ($name in @("opencode.jsonc", "opencode.json")) {
    $opcfg = Join-Path $deepCfg $name
    if ((Test-Path -LiteralPath $opcfg) -and -not (Test-Path -LiteralPath "$opcfg.bak")) {
      $c = Get-Content -LiteralPath $opcfg -Raw -Encoding UTF8
      if (($c -match '"opencode-personality"') -and ($c -match '"erotic-chan"') -and ($c -match '"force-chat"')) {
        Remove-Item -LiteralPath $opcfg -Force; $deepRemoved += $opcfg
      }
    }
  }

  if ($deepRemoved.Count -gt 0) {
    Write-Host ""
    Write-Host "  已清理 OpenCode 深度集成残留:"
    foreach ($f in $deepRemoved) { Write-Host "    $f" }
  }

  Write-Host ""
  Write-Host "==> 卸载完成! 新开终端生效♡"
}

$RawUrl = ""
switch -Regex ($Command.ToLower()) {
  "^update$" {
    if ($Rest.Count -gt 0) { $RawUrl = $Rest[0] }
    elseif ($env:ERI_URL)  { $RawUrl = $env:ERI_URL }
    else                   { $RawUrl = $DEFAULT_URL }
  }
  "^(uninstall|remove|rm)$" {
    $yes = ($Rest -contains "--yes") -or ($Rest -contains "-y") -or ($Rest -contains "-yes")
    if ($yes) { Invoke-Uninstall -Yes } else { Invoke-Uninstall }
    exit 0
  }
  "^(help|-h|--help)$" { Show-Help; exit 0 }
  "^(version|-v|-V|--version)$" { Write-Host $EriVersion; exit 0 }
  default {
    if ($Command -notmatch '^https?://') {
      Write-Host "==> 未知命令: $Command (可用: update / version / uninstall / help)"
      Show-Help
      exit 1
    }
    $RawUrl = $Command
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

function Remove-OrphanArtifacts($tool) {
  # 工具已卸载但残留了我们写入的人格/配置: 回滚它们, 避免下次更新带着旧状态执行
  $persona = Join-Path $tool.pdir $tool.pfile
  if (Test-Path -LiteralPath "$persona.bak") {
    Move-Item -LiteralPath "$persona.bak" -Destination $persona -Force
    Write-Host "  已恢复残留备份: $persona (来自 .bak)"
  } elseif ((Test-Path -LiteralPath $persona) -and (Test-Path -LiteralPath $tmp)) {
    try {
      if ((Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $persona -Algorithm SHA256).Hash) {
        Remove-Item -LiteralPath $persona -Force
        Write-Host "  已删除残留人格文件: $persona"
      }
    } catch { }
  }
  if ($tool.mode -eq "aider") {
    $cfg = Join-Path $env:USERPROFILE ".aider.conf.yml"
    if ((Test-Path -LiteralPath $cfg) -and ((Get-Content -LiteralPath $cfg -Raw -Encoding UTF8) -match [regex]::Escape($persona))) {
      $lines = Get-Content -LiteralPath $cfg
      $out = @(foreach ($ln in $lines) {
        if ($ln -match [regex]::Escape($persona)) {
          if ($ln -match '^\s*-') { continue }
          $m = [regex]::Match($ln, '^(?<ind>\s*)read\s*:\s*(?<val>.*)$')
          if ($m.Success) {
            $val = $m.Groups['val'].Value.Trim()
            if ($val -eq '') { $ln }
            else { $toks = @($val -split '\s+' | Where-Object { $_ -and $_ -ne $persona }); if ($toks.Count -gt 0) { $m.Groups['ind'].Value + 'read: ' + ($toks -join ' ') } }
          } else { $ln }
        } else { $ln }
      })
      [System.IO.File]::WriteAllLines($cfg, $out, (New-Object System.Text.UTF8Encoding($false)))
      Write-Host "  已清理残留: $cfg (移除 read 路径)"
    }
  }
  if ($tool.id -eq "opencode") {
    $opcfgDir = Split-Path $tool.pdir -Parent
    foreach ($name in @("opencode.jsonc", "opencode.json")) {
      $opcfg = Join-Path $opcfgDir $name
      if (Test-Path -LiteralPath "$opcfg.bak") {
        Move-Item -LiteralPath "$opcfg.bak" -Destination $opcfg -Force
        Write-Host "  已恢复残留备份: $opcfg (来自 .bak)"
      }
      if (-not (Test-Path -LiteralPath $opcfg)) { continue }
      $content = Get-Content -LiteralPath $opcfg -Raw -Encoding UTF8
      if ($content -match '"default_agent"\s*:\s*"eri"') {
        $content = [regex]::Replace($content, '\s*"default_agent"\s*:\s*"eri"\s*,?', '')
        $content = [regex]::Replace($content, ',\s*}', "`n}")
        [System.IO.File]::WriteAllText($opcfg, $content, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  已清理残留: $opcfg (移除 default_agent)"
      }
    }
    if (Test-Path -LiteralPath (Join-Path $opcfgDir "personality.json")) {
      Write-Host "  提示: opencode 深度集成文件仍残留($opcfgDir), 如需彻底清理可运行: eri uninstall"
    }
  }
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
  if (-not (Get-Command $tool.cmd -ErrorAction SilentlyContinue)) {
    $persona = Join-Path $tool.pdir $tool.pfile
    $hasResidue = (Test-Path -LiteralPath "$persona.bak")
    if (-not $hasResidue -and (Test-Path -LiteralPath $persona) -and (Test-Path -LiteralPath $tmp)) {
      try { if ((Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $persona -Algorithm SHA256).Hash) { $hasResidue = $true } } catch { }
    }
    if ($tool.mode -eq "aider") {
      $cfg = Join-Path $env:USERPROFILE ".aider.conf.yml"
      if ((Test-Path -LiteralPath $cfg) -and ((Get-Content -LiteralPath $cfg -Raw -Encoding UTF8) -match [regex]::Escape($persona))) { $hasResidue = $true }
    }
    if ($tool.id -eq "opencode") {
      $opcfgDir = Split-Path $tool.pdir -Parent
      foreach ($name in @("opencode.jsonc", "opencode.json")) {
        $opcfg = Join-Path $opcfgDir $name
        if (Test-Path -LiteralPath "$opcfg.bak") { $hasResidue = $true }
        if ((Test-Path -LiteralPath $opcfg) -and ((Get-Content -LiteralPath $opcfg -Raw -Encoding UTF8) -match '"default_agent"\s*:\s*"eri"')) { $hasResidue = $true }
      }
    }
    if ($hasResidue) {
      Write-Host "==> 检测到 $($tool.id) 已卸载但存在残留, 自动回滚..."
      Remove-OrphanArtifacts $tool
    }
    continue
  }
  New-Item -ItemType Directory -Force -Path $tool.pdir | Out-Null
  $target = Join-Path $tool.pdir $tool.pfile
  Copy-Item -LiteralPath $tmp -Destination $target -Force
  Write-Host "  updated: $target"

  if ($tool.mode -eq "aider") {
    $cfg = Join-Path $env:USERPROFILE ".aider.conf.yml"
    $content = if (Test-Path -LiteralPath $cfg) { Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 } else { $null }
    if ($null -ne $content -and $content -match [regex]::Escape($target)) {
      # 已包含, 不重复追加
    } elseif ($null -ne $content) {
      $lines = Get-Content -LiteralPath $cfg
      $done = $false
      $out = @(foreach ($ln in $lines) {
        if (-not $done -and $ln -match '^(?<ind>\s*)read\s*:\s*(?<val>.*)$') {
          $done = $true
          $val = $Matches['val'].Trim()
          $ind = $Matches['ind']
          if ($val -eq '') { $ln; "$ind  - $target" } else { "read: $val $target" }
        } else { $ln }
      })
      if (-not $done) { $out = @($out + "read: $target") }
      [System.IO.File]::WriteAllLines($cfg, $out, (New-Object System.Text.UTF8Encoding($false)))
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

# 版本单一真源: 从 package.json 读取, 注入到生成的 eri-core.ps1
$eriVer = '0.0.0'
$pkgFile = Join-Path $PSScriptRoot 'package.json'
if (Test-Path -LiteralPath $pkgFile) {
  try { $eriVer = (Get-Content -LiteralPath $pkgFile -Raw -Encoding UTF8 | ConvertFrom-Json).version } catch { }
}
$eriPs1Content = $eriPs1Content.Replace('__ERI_VERSION__', $eriVer)

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($EriPs1, $eriPs1Content, $utf8Bom)

$eriCmdContent = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0eri-core.ps1" %*
'@
$eriCmdContent = $eriCmdContent -replace '\r?\n', "`r`n"
$ascii = New-Object System.Text.ASCIIEncoding
[System.IO.File]::WriteAllText($EriCmd, $eriCmdContent, $ascii)

Write-Host "==> 已创建可执行命令: $EriCmd"

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

$envExisting = @($env:PATH -split ';' | Where-Object {
  $_ -and $_.Trim() -ne "" -and ($_.TrimEnd('\') -ne $BinDir.TrimEnd('\'))
})
$env:PATH = (@($BinDir) + $envExisting) -join ';'

Write-Host "==> 短命令 'eri update' / 'eri uninstall' 已就绪"

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
  # 与 install-eri.sh 对齐: 交互式下可将抢占型冲突重命名为 <文件名>.eri-disabled
  if ($Interactive) {
    $ans = Read-Host "是否将这些冲突重命名为 <文件名>.eri-disabled 以让出 'eri' 短命令? [Y/n]"
    if ($ans -ne "n" -and $ans -ne "N") {
      $renamed = @()
      $stateFile = Join-Path $BinDir ".eri-disabled.list"
      if (Test-Path -LiteralPath $stateFile) { $renamed = @(Get-Content -LiteralPath $stateFile -Encoding UTF8 | Where-Object { $_ }) }
      foreach ($c in $conflicts) {
        try {
          $disabled = $c.Source + ".eri-disabled"
          Rename-Item -LiteralPath $c.Source -NewName ((Split-Path $c.Source -Leaf) + ".eri-disabled") -Force
          if ($renamed -notcontains $disabled) { $renamed += $disabled }
          Write-Host "    已遮蔽: $($c.Source) -> .eri-disabled"
        } catch {
          Write-Host "    无法遮蔽(权限不足): $($c.Source)"
        }
      }
      if ($renamed.Count -gt 0) {
        [System.IO.File]::WriteAllLines($stateFile, $renamed, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "    (记录到 $stateFile, 卸载时会自动恢复)"
      }
    }
  }
  Write-Host "    若新开终端后 'eri' 仍命中其他位置, 请检查 PATH 顺序或重开终端"
} else {
  Write-Host "==> 未检测到冲突的 eri 命令"
}

# 与 install-eri.sh 末尾一致: 校验当前会话里 'eri' 是否解析到我们刚生成的命令
Write-Host ""
Write-Host "==> 验证 'eri' 命令..."
$resolved = Get-Command eri -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
if ($resolved -and ($resolved.Source.TrimEnd('\') -eq $EriCmd.TrimEnd('\'))) {
  Write-Host "    √ 'eri' 已正确解析到: $($resolved.Source)"
  Write-Host "      可以立即执行: eri help / eri update / eri uninstall"
} elseif ($resolved) {
  Write-Host "    ⚠ 'eri' 当前解析到: $($resolved.Source) (期望 $EriCmd)"
  Write-Host "      请检查 PATH 顺序, 或新开终端"
} else {
  Write-Host "    ⚠ 当前会话尚未识别 'eri' 命令, 请新开终端生效"
}