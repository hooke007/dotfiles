<#
.SYNOPSIS
    下载 GitHub Release 资源
.DESCRIPTION
    自动下载指定 GitHub 仓库中特定标签的所有 Release 文件
.PARAMETER Owner
    仓库所有者（用户名或组织名）
.PARAMETER Repo
    仓库名称
.PARAMETER Tag
    Release 标签名
.PARAMETER DownloadDir
    下载目录路径（可选，默认使用标签名作为目录名）
.PARAMETER Token
    GitHub Personal Access Token（可选，用于提高 API 速率限制）
.EXAMPLE
    ./dl_gh_assets.ps1 -Owner "hooke007" -Repo "dotfiles" -Tag "onnx_models"
.NOTES
    如果遇到执行策略限制，请使用以下命令运行：
    PowerShell -ExecutionPolicy Bypass -File ./dl_gh_assets.ps1 -Owner "owner" -Repo "repo" -Tag "tag"
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="仓库所有者（用户名或组织名）")]
    [string]$Owner,
    
    [Parameter(Mandatory=$true, HelpMessage="仓库名称")]
    [string]$Repo,
    
    [Parameter(Mandatory=$true, HelpMessage="Release 标签名")]
    [string]$Tag,
    
    [Parameter(Mandatory=$false, HelpMessage="下载目录路径（默认使用标签名）")]
    [string]$DownloadDir = "",
    
    [Parameter(Mandatory=$false, HelpMessage="GitHub Personal Access Token（可选）")]
    [string]$Token = ""
)

# 如果未指定下载目录，使用标签名（移除可能的非法字符）
if ([string]::IsNullOrWhiteSpace($DownloadDir)) {
    $safeName = $Tag -replace '[\\/:*?"<>|]', '_'
    $DownloadDir = "./$safeName"
}

$metadataFile = Join-Path $DownloadDir ".download_metadata.json"

Write-Host "==================== GitHub Release 下载工具 ====================" -ForegroundColor Cyan
Write-Host "仓库: $Owner/$Repo" -ForegroundColor White
Write-Host "标签: $Tag" -ForegroundColor White
Write-Host "目标目录: $DownloadDir" -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# 创建下载目录
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir | Out-Null
    Write-Host "✓ 创建下载目录: $DownloadDir" -ForegroundColor Green
}

# 读取现有的元数据
$existingMetadata = @{}
if (Test-Path $metadataFile) {
    try {
        $existingMetadata = Get-Content $metadataFile -Raw | ConvertFrom-Json -AsHashtable
        Write-Host "✓ 加载已有下载记录 ($($existingMetadata.Count) 个文件)" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ 警告: 无法读取元数据文件，将重新创建" -ForegroundColor Yellow
        $existingMetadata = @{}
    }
}
else {
    Write-Host "ℹ 首次运行，将下载所有文件" -ForegroundColor Cyan
}

Write-Host ""

# GitHub API URL
$apiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/tags/$Tag"

# 构建请求头
$headers = @{
    "Accept" = "application/vnd.github+json"
    "User-Agent" = "PowerShell-Script"
}

# 如果提供了 Token，添加到请求头
if (-not [string]::IsNullOrWhiteSpace($Token)) {
    $headers["Authorization"] = "Bearer $Token"
    Write-Host "✓ 使用 GitHub Token 进行认证" -ForegroundColor Green
    Write-Host ""
}

Write-Host "正在获取 Release 信息..." -ForegroundColor Cyan

try {
    # 获取 Release 信息
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers

    # 获取所有资源
    $assets = $release.assets

    if ($assets.Count -eq 0) {
        Write-Host "✗ 未找到任何资源文件" -ForegroundColor Yellow
        exit
    }

    Write-Host "✓ 找到 $($assets.Count) 个文件" -ForegroundColor Green
    Write-Host ""
    Write-Host "开始检查和下载..." -ForegroundColor Cyan
    Write-Host ""

    # 统计信息
    $downloadCount = 0
    $skipCount = 0
    $updateCount = 0
    $errorCount = 0

    # 新的元数据
    $newMetadata = @{}

    # 检查并下载每个资源
    $index = 1
    foreach ($asset in $assets) {
        $fileName = $asset.name
        $downloadUrl = $asset.browser_download_url
        $outputPath = Join-Path $DownloadDir $fileName
        $assetId = $asset.id
        $assetSize = $asset.size
        $updatedAt = $asset.updated_at

        Write-Host "[$index/$($assets.Count)] $fileName" -ForegroundColor White
        Write-Host "    大小: $([math]::Round($assetSize / 1MB, 2)) MB | 更新: $updatedAt" -ForegroundColor DarkGray

        # 检查文件是否需要下载
        $needDownload = $false
        $reason = ""

        if (-not (Test-Path $outputPath)) {
            $needDownload = $true
            $reason = "新文件"
            $downloadCount++
        }
        elseif (-not $existingMetadata.ContainsKey($fileName)) {
            $needDownload = $true
            $reason = "无下载记录"
            $downloadCount++
        }
        else {
            $metadata = $existingMetadata[$fileName]
            
            # 比较文件大小
            $localSize = (Get-Item $outputPath).Length
            if ($localSize -ne $assetSize) {
                $needDownload = $true
                $reason = "大小变化 ($([math]::Round($localSize / 1MB, 2)) MB → $([math]::Round($assetSize / 1MB, 2)) MB)"
                $updateCount++
            }
            # 比较更新时间
            elseif ($metadata.updated_at -ne $updatedAt) {
                $needDownload = $true
                $reason = "文件已更新"
                $updateCount++
            }
            # 比较asset ID
            elseif ($metadata.id -ne $assetId) {
                $needDownload = $true
                $reason = "资源ID变化"
                $updateCount++
            }
            else {
                $skipCount++
                Write-Host "    ⊙ 跳过 (文件未变化)" -ForegroundColor DarkGray
            }
        }

        # 下载文件
        if ($needDownload) {
            Write-Host "    → 下载中... [$reason]" -ForegroundColor Yellow
            try {
                # 使用进度条下载大文件
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath -UseBasicParsing
                $ProgressPreference = 'Continue'
                Write-Host "    ✓ 下载完成" -ForegroundColor Green
            }
            catch {
                Write-Host "    ✗ 下载失败: $($_.Exception.Message)" -ForegroundColor Red
                $errorCount++
            }
        }

        # 更新元数据
        $newMetadata[$fileName] = @{
            id = $assetId
            size = $assetSize
            updated_at = $updatedAt
            download_time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }

        Write-Host ""
        $index++
    }

    # 保存元数据
    try {
        $newMetadata | ConvertTo-Json -Depth 10 | Set-Content $metadataFile -Encoding UTF8
        Write-Host "✓ 元数据已保存" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ 警告: 无法保存元数据文件" -ForegroundColor Yellow
    }
    
    Write-Host ""

    # 输出统计信息
    Write-Host "==================== 下载统计 ====================" -ForegroundColor Cyan
    Write-Host "总文件数    : $($assets.Count)" -ForegroundColor White
    Write-Host "新下载      : $downloadCount" -ForegroundColor Green
    Write-Host "更新        : $updateCount" -ForegroundColor Yellow
    Write-Host "跳过        : $skipCount" -ForegroundColor DarkGray
    if ($errorCount -gt 0) {
        Write-Host "失败        : $errorCount" -ForegroundColor Red
    }
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($errorCount -eq 0 -and ($downloadCount -gt 0 -or $updateCount -gt 0)) {
        Write-Host "✓ 所有操作已成功完成！" -ForegroundColor Green
    }
    elseif ($errorCount -gt 0) {
        Write-Host "⚠ 部分文件下载失败，请检查网络连接后重试" -ForegroundColor Yellow
    }
    else {
        Write-Host "✓ 所有文件均为最新，无需下载" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "文件位置: $((Resolve-Path $DownloadDir).Path)" -ForegroundColor Cyan
}
catch {
    Write-Host ""
    Write-Host "✗ 发生错误: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    if ($_.Exception.Message -like "*403*") {
        Write-Host "提示: GitHub API 可能达到速率限制，请稍后再试或使用 -Token 参数" -ForegroundColor Yellow
    }
    elseif ($_.Exception.Message -like "*404*") {
        Write-Host "提示: 未找到指定的 Release，请检查仓库和标签名称" -ForegroundColor Yellow
        Write-Host "验证 URL: https://github.com/$Owner/$Repo/releases/tag/$Tag" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host ""
Write-Host "按任意键退出..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
