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

# --- Selecionar pastas ---
$defaultSource = Join-Path $root "Fotos"
$src = Select-FolderDialog $msg_select_source $defaultSource
if (-not $src) { Write-Host $msg_cancel; pause; exit }

$dst = Select-FolderDialog $msg_select_dest
if (-not $dst) { Write-Host $msg_cancel; pause; exit }

# Criar/usar sempre uma pasta raiz dedicada dentro do destino escolhido,
# para nao largar pastas de anos directamente na raiz do disco/pen/pasta.
# Se o utilizador ja escolheu a pasta LOCAlbum-Backup directamente, nao duplicar.
if ([System.IO.Path]::GetFileName($dst) -ne 'LOCAlbum-Backup') {
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

# Garantir que destino existe
if (-not (Test-Path $dst)) {
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
}

Write-Host "Origem:  $src"
Write-Host "Destino: $dst  (subpasta LOCAlbum-Backup criada/usada automaticamente)"
Write-Host ""
Write-Host $msg_scanning
Write-Host ""

# --- Carregar ou criar manifest do backup ---
$manifestPath = Join-Path $dst "_backup_manifest.json"
$manifest = @{}

if (Test-Path $manifestPath) {
    try {
        $json = Get-Content $manifestPath -Raw -Encoding UTF8
        if ($json) {
            $manifest = $json | ConvertFrom-Json -AsHashtable
        }
    } catch {
        Write-Host "[AVISO] Manifest corrompido. Sera reconstruido." -ForegroundColor Yellow
        $manifest = @{}
    }
}

# --- Contadores ---
$foldersToProcess = 0
$foldersSkipped = 0
$filesTotalCopied = 0
$sizeTotalCopied = 0
$startTime = Get-Date

# --- Pre-contar pastas a processar ---
$years = Get-ChildItem -Path $src -Directory | Sort-Object Name
$allFoldersToCheck = @()

foreach ($yearFolder in $years) {
    $yearName = $yearFolder.Name
    $months = Get-ChildItem -Path $yearFolder.FullName -Directory | Sort-Object Name

    foreach ($monthFolder in $months) {
        $monthName = $monthFolder.Name
        $folderKey = "$yearName/$monthName"
        
        $srcLastWrite = $monthFolder.LastWriteTimeUtc
        $needsCopy = $false

        if ($manifest.ContainsKey($folderKey)) {
            $lastBackupTime = [datetime]$manifest[$folderKey]
            if ($srcLastWrite -gt $lastBackupTime) {
                $needsCopy = $true
            }
        } else {
            $needsCopy = $true
        }

        if ($needsCopy) {
            $allFoldersToCheck += @{
                key = $folderKey
                year = $yearName
                month = $monthName
                path = $monthFolder.FullName
                lastWrite = $srcLastWrite
            }
        }
    }
}

$totalFoldersToProcess = $allFoldersToCheck.Count
$currentFolderIndex = 0

# --- Verificar espaco livre no destino ANTES de copiar ---
# Um backup que fica a meio por falta de espaco e pior do que nenhum:
# parece ter corrido bem mas deixa fotos por copiar.
if ($totalFoldersToProcess -gt 0) {
    $bytesNeeded = 0
    foreach ($folderInfo in $allFoldersToCheck) {
        try {
            $bytesNeeded += (Get-ChildItem -Path $folderInfo.path -File |
                             Measure-Object -Property Length -Sum).Sum
        } catch { }
    }

    $freeBytes = $null
    try {
        $dstRoot = [System.IO.Path]::GetPathRoot((Resolve-Path $dst).Path)
        $driveInfo = New-Object System.IO.DriveInfo($dstRoot)
        $freeBytes = $driveInfo.AvailableFreeSpace
    } catch { }

    $neededMB = [math]::Round($bytesNeeded / 1MB, 1)
    Write-Host ("{0}: {1} MB" -f $msg_space_needed, $neededMB)

    if ($freeBytes -ne $null) {
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

# --- Loop: processar apenas pastas alteradas ---
foreach ($folderInfo in $allFoldersToCheck) {
    $currentFolderIndex++
    $folderKey = $folderInfo.key
    $yearName = $folderInfo.year
    $monthName = $folderInfo.month
    $monthFolderPath = $folderInfo.path
    $srcLastWrite = $folderInfo.lastWrite

    Write-Host "  [COPIAR] $folderKey" -ForegroundColor Yellow

    # Criar estrutura de pastas no destino
    $dstYear = Join-Path $dst $yearName
    $dstMonth = Join-Path $dstYear $monthName
    
    if (-not (Test-Path $dstMonth)) {
        New-Item -ItemType Directory -Path $dstMonth -Force | Out-Null
    }

    # Contar e copiar ficheiros
    $files = Get-ChildItem -Path $monthFolderPath -File
    $totalFiles = $files.Count
    $currentFileIndex = 0

    foreach ($file in $files) {
        $currentFileIndex++
        
        # Barra de progresso dupla
        $folderPercent = [int](100 * $currentFolderIndex / $totalFoldersToProcess)
        $filePercent = [int](100 * $currentFileIndex / $totalFiles)
        
        $progressMsg = if ($lang -eq "en") { "Copying ($currentFolderIndex/$totalFoldersToProcess pastas)" } 
                       else { "A copiar ($currentFolderIndex/$totalFoldersToProcess pastas)" }
        
        $statusMsg = "$folderKey | $currentFileIndex/$totalFiles ficheiros"
        
        Write-Progress -Activity $progressMsg `
                       -Status $statusMsg `
                       -PercentComplete $folderPercent `
                       -Id 1
        
        Write-Progress -Activity "Ficheiros" `
                       -Status "$currentFileIndex/$totalFiles" `
                       -PercentComplete $filePercent `
                       -ParentId 1 `
                       -Id 2

        try {
            $destFile = Join-Path $dstMonth $file.Name
            Copy-Item -Path $file.FullName -Destination $destFile -Force
            $filesTotalCopied++
            $sizeTotalCopied += $file.Length
        } catch {
            Write-Host "    [ERRO] Falha ao copiar: $($file.Name)" -ForegroundColor Red
        }
    }

    # Atualizar timestamp no manifest
    $manifest[$folderKey] = $srcLastWrite.ToString("o")
    
    [System.Console]::Out.Flush()
}

Write-Progress -Activity "A copiar" -Completed -Id 1
Write-Progress -Activity "Ficheiros" -Completed -Id 2

# Se nao houve nada a copiar
if ($totalFoldersToProcess -eq 0) {
    Write-Host "  $msg_skipping" -ForegroundColor Green
    $foldersSkipped = ($years | ForEach-Object { Get-ChildItem -Path $_.FullName -Directory }).Count
}

# --- Guardar manifest actualizado ---
$manifest | ConvertTo-Json | Set-Content -Path $manifestPath -Encoding UTF8
attrib +h "$manifestPath" > $null 2>&1

$endTime = Get-Date
$elapsed = $endTime - $startTime

Write-Host ""
Write-Host "════════════════════════════════════════"
Write-Host $msg_summary
Write-Host "════════════════════════════════════════"
Write-Host "  $msg_folders_copied`:          $totalFoldersToProcess"

# Contar total de pastas para mostrar quantas nao mudaram
$allMonthFolders = 0
foreach ($yearFolder in $years) {
    $allMonthFolders += (Get-ChildItem -Path $yearFolder.FullName -Directory).Count
}
$foldersSkipped = $allMonthFolders - $totalFoldersToProcess

Write-Host "  Pastas sem alteracoes`:        $foldersSkipped"
Write-Host "  $msg_files_copied`:        $filesTotalCopied"
Write-Host "  $msg_size_copied`:         $('{0:N0}' -f ($sizeTotalCopied / 1MB)) MB"
Write-Host "  $msg_time_elapsed`:        $($elapsed.Minutes)m $($elapsed.Seconds)s"
Write-Host ""
Write-Host $msg_done -ForegroundColor Green
Write-Host "════════════════════════════════════════"
Write-Host ""
Write-Host "Pressiona Enter para fechar..."
pause > $null
