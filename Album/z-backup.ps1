# =================================================
# LOCALBUM - Offline Photo Album - Incremental Backup
# =================================================

param(
    [string]$lang = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# --- Garantir modo STA ---
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "[INFO] Reiniciando o script em modo STA..."
    powershell.exe -STA -ExecutionPolicy Bypass -File "$PSCommandPath" -lang "$lang"
    exit
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Host "[AVISO] Alguns componentes visuais nao puderam ser carregados." -ForegroundColor Yellow
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$iniPath = Join-Path $root "config.ini"

# --- Determinar idioma ---
if (-not $lang) { $lang = "pt" }

if (Test-Path $iniPath) {
    try {
        $cfg = Get-Content $iniPath -Encoding UTF8 | Where-Object {$_ -match "="}
        foreach ($line in $cfg) {
            $kv = $line -split "=", 2
            if ($kv[0].Trim().ToLower() -eq "language" -and -not $lang) {
                $lang = $kv[1].Trim().ToLower()
            }
        }
    } catch { }
}

# --- Mensagens PT/EN ---
if ($lang -eq "en") {
    $msg_start           = "[INFO] Starting incremental backup..."
    $msg_select_source   = "Select source folder (Album\Fotos)"
    $msg_select_dest     = "Select destination folder for backup (tip: select an existing LOCAlbum-Backup folder, or any folder to create one inside)"
    $msg_cancel          = "No folder selected. Exiting..."
    $msg_invalid_source  = "Source folder does not contain Fotos subfolder"
    $msg_scanning        = "Scanning folders..."
    $msg_comparing       = "Comparing with last backup..."
    $msg_copying         = "Copying new/modified files..."
    $msg_skipping        = "No changes. Skipping..."
    $msg_done            = "[OK] Backup completed successfully!"
    $msg_summary         = "Backup Summary"
    $msg_folders_copied  = "Folders copied"
    $msg_files_copied    = "Files copied"
    $msg_size_copied     = "Size copied"
    $msg_time_elapsed    = "Time elapsed"
    $msg_space_needed    = "Space needed"
    $msg_space_free      = "Free space at destination"
    $msg_space_low       = "[WARNING] Not enough free space at the destination!"
    $msg_space_continue  = "Continue anyway? The backup may end up incomplete. (Y/N)"
    $msg_space_aborted   = "Backup cancelled. Free up space and try again."
    $msg_space_ok        = "[OK] Enough free space at the destination."
} else {
    $msg_start           = "[INFO] A iniciar copia de seguranca incremental..."
    $msg_select_source   = "Escolhe pasta de origem (Album\Fotos)"
    $msg_select_dest     = "Escolhe a pasta de destino (se ja tiveres uma pasta LOCAlbum-Backup, seleciona-a directamente; caso contrario escolhe qualquer pasta e ela sera criada automaticamente)"
    $msg_cancel          = "Nenhuma pasta selecionada. A sair..."
    $msg_invalid_source  = "Pasta de origem nao contem a subpasta Fotos"
    $msg_scanning        = "A analisar pastas..."
    $msg_comparing       = "A comparar com ultimo backup..."
    $msg_copying         = "A copiar ficheiros novos/alterados..."
    $msg_skipping        = "Sem alteracoes. A saltar..."
    $msg_done            = "[OK] Copia de seguranca concluida com sucesso!"
    $msg_summary         = "Resumo da Copia de Seguranca"
    $msg_folders_copied  = "Pastas copiadas"
    $msg_files_copied    = "Ficheiros copiados"
    $msg_size_copied     = "Tamanho copiado"
    $msg_time_elapsed    = "Tempo decorrido"
    $msg_space_needed    = "Espaco necessario"
    $msg_space_free      = "Espaco livre no destino"
    $msg_space_low       = "[AVISO] Nao ha espaco livre suficiente no destino!"
    $msg_space_continue  = "Continuar mesmo assim? A copia pode ficar incompleta. (S/N)"
    $msg_space_aborted   = "Copia cancelada. Liberta espaco e tenta novamente."
    $msg_space_ok        = "[OK] Espaco livre suficiente no destino."
}

Write-Host ""
Write-Host "====================================================="
Write-Host "     LOCALBUM - INCREMENTAL BACKUP (Copia Seguranca)"
Write-Host "====================================================="
Write-Host ""
Write-Host $msg_start
Write-Host "-------------------------------------------"
Write-Host ""

# --- Função: Escolher pasta ---
function Select-FolderDialog([string]$description, [string]$initialPath = $null) {
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = $description
    $d.ShowNewFolderButton = $true
    if ($initialPath -and (Test-Path $initialPath)) {
        try { $d.SelectedPath = (Resolve-Path $initialPath) } catch { }
    }

    $top = New-Object System.Windows.Forms.Form
    $top.TopMost = $true
    $top.ShowInTaskbar = $false
    $top.StartPosition = "CenterScreen"

    $res = $d.ShowDialog($top)
    $top.Dispose()

    if ($res -eq [System.Windows.Forms.DialogResult]::OK) {
        return $d.SelectedPath
    } else {
        return $null
    }
}

# --- Mensagens extra (PT/EN) ---
if ($lang -eq "en") {
    $msg_dst_inside   = "[ERROR] The backup destination cannot be inside the source folder (or vice versa). Choose another location."
    $msg_root_label   = "(main folder)"
    $msg_copy_tag     = "COPY"
    $msg_act_copy     = "Copying"
    $msg_act_files    = "Files"
    $msg_act_scan     = "Comparing files"
    $msg_word_files   = "files"
    $msg_word_folders = "folders"
    $msg_not_found    = "[WARNING] File not found, skipped"
    $msg_copy_error   = "[ERROR] Failed to copy"
    $msg_unchanged    = "Folders without changes"
    $msg_press_enter  = "Press Enter to close..."
} else {
    $msg_dst_inside   = "[ERRO] O destino do backup nao pode estar dentro da pasta de origem (nem o contrario). Escolhe outro local."
    $msg_root_label   = "(pasta principal)"
    $msg_copy_tag     = "COPIAR"
    $msg_act_copy     = "A copiar"
    $msg_act_files    = "Ficheiros"
    $msg_act_scan     = "A comparar ficheiros"
    $msg_word_files   = "ficheiros"
    $msg_word_folders = "pastas"
    $msg_not_found    = "[AVISO] Ficheiro nao encontrado, ignorado"
    $msg_copy_error   = "[ERRO] Falha ao copiar"
    $msg_unchanged    = "Pastas sem alteracoes"
    $msg_press_enter  = "Pressiona Enter para fechar..."
}

# --- Selecionar pastas ---
$defaultSource = Join-Path $root "Fotos"
$src = Select-FolderDialog $msg_select_source $defaultSource
if (-not $src) { Write-Host $msg_cancel; pause; exit }

$dst = Select-FolderDialog $msg_select_dest
if (-not $dst) { Write-Host $msg_cancel; pause; exit }

# Criar/usar sempre uma pasta raiz dedicada dentro do destino escolhido,
# para nao largar pastas de anos directamente na raiz do disco/pen/pasta.
# Se o utilizador ja escolheu a pasta LOCAlbum-Backup directamente, nao duplicar.
if ([System.IO.Path]::GetFileName($dst.TrimEnd('\', '/')) -ne 'LOCAlbum-Backup') {
    $dst = Join-Path $dst "LOCAlbum-Backup"
    if ($lang -eq "en") {
        Write-Host "[INFO] A dedicated backup folder will be used: $dst" -ForegroundColor Cyan
        Write-Host "       Next time you can select this folder directly." -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] Sera usada uma pasta dedicada para o backup: $dst" -ForegroundColor Cyan
        Write-Host "       Da proxima vez podes seleccionar essa pasta directamente." -ForegroundColor Cyan
    }
    Write-Host ""
}

# Caminhos completos normalizados, sem barra final (usados para comparar
# e para calcular o caminho relativo de cada ficheiro)
$sep     = [System.IO.Path]::DirectorySeparatorChar
$srcFull = [System.IO.Path]::GetFullPath($src).TrimEnd('\', '/')
$dstFull = [System.IO.Path]::GetFullPath($dst).TrimEnd('\', '/')

# Proteccao: destino dentro da origem (ou o contrario) faria o backup
# copiar-se a si proprio e encher o album de pastas estranhas
$srcCmp = $srcFull + $sep
$dstCmp = $dstFull + $sep
if ($dstCmp.StartsWith($srcCmp, [System.StringComparison]::OrdinalIgnoreCase) -or
    $srcCmp.StartsWith($dstCmp, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host $msg_dst_inside -ForegroundColor Red
    pause
    exit
}

# Garantir que destino existe
if (-not (Test-Path -LiteralPath $dstFull)) {
    [void][System.IO.Directory]::CreateDirectory($dstFull)
}

Write-Host "Origem:  $srcFull"
Write-Host "Destino: $dstFull"
Write-Host ""
Write-Host $msg_scanning
Write-Host ""

# O manifest antigo ja nao e usado (a comparacao e feita ficheiro a ficheiro).
# Apagamos o que ficou de versoes anteriores para nao gerar avisos.
$oldManifest = Join-Path $dstFull "_backup_manifest.json"
if (Test-Path -LiteralPath $oldManifest) {
    Remove-Item -LiteralPath $oldManifest -Force -ErrorAction SilentlyContinue
}

$startTime = Get-Date

# --- Analisar TODOS os ficheiros da origem (incluindo subpastas) ---
# Inclui fotos sem data, quarentena e qualquer outra subpasta, nao apenas Ano\Mes.
# Ficheiros ocultos (caches internas do LOCAlbum) ficam de fora.
# Um ficheiro e copiado se nao existir no destino, ou se o tamanho ou a data
# de modificacao forem diferentes (tolerancia de 2s; a diferenca de exatamente
# 1h causada pela mudanca de hora em pens FAT32 tambem e ignorada).
$allSrcFiles = @(Get-ChildItem -LiteralPath $src -Recurse -File -ErrorAction SilentlyContinue)
$totalSrc    = $allSrcFiles.Count

$groups  = @{}   # pasta relativa -> lista de ficheiros a copiar
$allDirs = @{}   # todas as pastas relativas com ficheiros (para o resumo)
$scanIdx = 0

foreach ($sf in $allSrcFiles) {
    $scanIdx++
    if ($totalSrc -gt 0 -and ($scanIdx % 200 -eq 0 -or $scanIdx -eq $totalSrc)) {
        $pctScan = [int](100 * $scanIdx / $totalSrc)
        Write-Progress -Id 1 -Activity $msg_act_scan `
                       -Status "$scanIdx/$totalSrc $msg_word_files ($pctScan%)" `
                       -PercentComplete $pctScan
    }

    $rel    = $sf.FullName.Substring($srcFull.Length).TrimStart('\', '/')
    $relDir = [System.IO.Path]::GetDirectoryName($rel)
    if ($null -eq $relDir) { $relDir = "" }
    $allDirs[$relDir] = $true

    $dfPath = Join-Path $dstFull $rel
    $needs  = $false
    if (-not (Test-Path -LiteralPath $dfPath -PathType Leaf)) {
        $needs = $true
    } else {
        $df   = Get-Item -LiteralPath $dfPath -Force
        $diff = [math]::Abs(($sf.LastWriteTimeUtc - $df.LastWriteTimeUtc).TotalSeconds)
        if ($sf.Length -ne $df.Length) {
            $needs = $true
        } elseif ($diff -gt 2 -and [math]::Abs($diff - 3600) -gt 2) {
            $needs = $true
        }
    }

    if ($needs) {
        if (-not $groups.ContainsKey($relDir)) {
            $groups[$relDir] = New-Object System.Collections.ArrayList
        }
        [void]$groups[$relDir].Add($sf)
    }
}
Write-Progress -Id 1 -Activity $msg_act_scan -Completed

$groupKeys        = @($groups.Keys | Sort-Object)
$totalGroups      = $groupKeys.Count
$totalFilesToCopy = 0
$bytesNeeded      = 0
foreach ($k in $groupKeys) {
    $totalFilesToCopy += $groups[$k].Count
    foreach ($f in $groups[$k]) { $bytesNeeded += $f.Length }
}

# --- Verificar espaco livre no destino ANTES de copiar ---
# Um backup que fica a meio por falta de espaco e pior do que nenhum:
# parece ter corrido bem mas deixa fotos por copiar.
if ($totalFilesToCopy -gt 0) {
    $freeBytes = $null
    try {
        $dstRoot   = [System.IO.Path]::GetPathRoot($dstFull)
        $driveInfo = New-Object System.IO.DriveInfo($dstRoot)
        $freeBytes = $driveInfo.AvailableFreeSpace
    } catch { }

    $neededMB = [math]::Round($bytesNeeded / 1MB, 1)
    Write-Host ("{0}: {1} MB" -f $msg_space_needed, $neededMB)

    if ($null -ne $freeBytes) {
        $freeMB = [math]::Round($freeBytes / 1MB, 1)
        Write-Host ("{0}: {1} MB" -f $msg_space_free, $freeMB)
        Write-Host ""

        # Margem de 5% para metadados e variacoes do sistema de ficheiros
        if ($freeBytes -lt ($bytesNeeded * 1.05)) {
            Write-Host $msg_space_low -ForegroundColor Red
            $goOn = Read-Host $msg_space_continue
            if ($goOn -ne "S" -and $goOn -ne "s" -and $goOn -ne "Y" -and $goOn -ne "y") {
                Write-Host $msg_space_aborted -ForegroundColor Yellow
                pause
                exit
            }
        } else {
            Write-Host $msg_space_ok -ForegroundColor Green
        }
        Write-Host ""
    }
}

# --- Copiar apenas ficheiros novos/alterados ---
$filesTotalCopied = 0
$sizeTotalCopied  = 0
$globalIndex      = 0
$groupIndex       = 0

foreach ($relDir in $groupKeys) {
    $groupIndex++
    $items = $groups[$relDir]
    $n     = $items.Count
    $label = if ($relDir) { $relDir -replace '\\', '/' } else { $msg_root_label }

    $pctFolder = [int](100 * $groupIndex / $totalGroups)
    Write-Host "  [$msg_copy_tag $groupIndex/$totalGroups - $pctFolder%] $label" -ForegroundColor Yellow

    $dstDir = if ($relDir) { Join-Path $dstFull $relDir } else { $dstFull }
    if (-not (Test-Path -LiteralPath $dstDir)) {
        [void][System.IO.Directory]::CreateDirectory($dstDir)
    }

    $fi = 0
    foreach ($file in $items) {
        $fi++
        $globalIndex++
        $pctFile  = [int](100 * $fi / $n)
        $pctTotal = [int](100 * $globalIndex / $totalFilesToCopy)

        # Barra 1: progresso TOTAL (todos os ficheiros a copiar)
        Write-Progress -Id 1 `
                       -Activity "$msg_act_copy ($globalIndex/$totalFilesToCopy $msg_word_files - $pctTotal%)" `
                       -Status "$label | $groupIndex/$totalGroups $msg_word_folders" `
                       -PercentComplete $pctTotal
        # Barra 2: progresso dentro da pasta actual
        Write-Progress -Id 2 -ParentId 1 `
                       -Activity $msg_act_files `
                       -Status "$fi/$n $msg_word_files ($pctFile%)" `
                       -PercentComplete $pctFile

        Write-Host ("    [{0}/{1} {2}%] {3}" -f $fi, $n, $pctFile, $file.Name)

        # O ficheiro pode ter desaparecido entre a analise e a copia
        # (ex: disco/pen desligou-se)
        if (-not (Test-Path -LiteralPath $file.FullName)) {
            Write-Host "    $msg_not_found`: $($file.Name)" -ForegroundColor Yellow
            continue
        }
        try {
            $destFile = Join-Path $dstDir $file.Name
            Copy-Item -LiteralPath $file.FullName -Destination $destFile -Force -ErrorAction Stop
            $filesTotalCopied++
            $sizeTotalCopied += $file.Length
        } catch {
            Write-Host "    $msg_copy_error`: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    [System.Console]::Out.Flush()
}

Write-Progress -Id 2 -Activity $msg_act_files -Completed
Write-Progress -Id 1 -Activity $msg_act_copy -Completed

if ($totalFilesToCopy -eq 0) {
    Write-Host "  $msg_skipping" -ForegroundColor Green
}

$elapsed        = (Get-Date) - $startTime
$foldersSkipped = $allDirs.Count - $totalGroups

Write-Host ""
Write-Host "════════════════════════════════════════"
Write-Host $msg_summary
Write-Host "════════════════════════════════════════"
Write-Host "  $msg_folders_copied`:          $totalGroups"
Write-Host "  $msg_unchanged`:        $foldersSkipped"
Write-Host "  $msg_files_copied`:        $filesTotalCopied"
Write-Host "  $msg_size_copied`:         $('{0:N0}' -f ($sizeTotalCopied / 1MB)) MB"
Write-Host ("  {0}:        {1}h {2}m {3}s" -f $msg_time_elapsed, [int][math]::Floor($elapsed.TotalHours), $elapsed.Minutes, $elapsed.Seconds)
Write-Host ""
Write-Host $msg_done -ForegroundColor Green
Write-Host "════════════════════════════════════════"
Write-Host ""
Write-Host $msg_press_enter
pause > $null
