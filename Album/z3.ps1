# =================================================
# LOCALBUM - Offline Photo Album - Organizer
# =================================================

param(
    [string]$lang = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# --- Garantir modo STA (necessário em Windows 11 para System.Drawing e Forms) ---
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "[INFO] Reiniciando o script em modo STA (necessario para W11)..."
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

# -------------------------------
# Determinar idioma
# -------------------------------
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

# -------------------------------
# Mensagens multilíngua
# -------------------------------
if ($lang -eq "en") {
    $msg_select_source = "Select the folder containing your photos to organize"
    $msg_select_dest   = "Select the destination folder for your photos (default: Album\Fotos)"
    $msg_cancel        = "No folder selected. Exiting..."
    $msg_done          = "[OK] Organization complete! Photos were grouped by year and month folders."
    $msg_reminder      = ">>> Remember to go back to the LOCALBUM Manager and run OPTION 2 to create or update your album."
    $msg_no_exif       = "No EXIF or valid date - moved to manual folder"
    $msg_start         = "[INFO] Starting photo organization..."
    $noDateFolderName  = "__FILES_WITHOUT_DATE - CHECK_MANUALLY"
    $ci = [System.Globalization.CultureInfo]::GetCultureInfo("en-GB")
}
else {
    $msg_select_source = "Escolhe a pasta com as fotos a organizar"
    $msg_select_dest   = "Escolhe a pasta de destino (por defeito: Album\Fotos)"
    $msg_cancel        = "Nenhuma pasta selecionada. A sair..."
    $msg_done          = "[OK] Organizacao concluida! As fotos foram agrupadas por pastas de ano e mes."
    $msg_reminder      = ">>> Nao te esquecas de voltar ao Gestor LOCALBUM e correr a OPCAO [2] para criar ou atualizar o album."
    $msg_no_exif       = "Sem data (nome/EXIF) - movido para pasta manual"
    $msg_start         = "[INFO] A iniciar a organizacao das fotos..."
    $noDateFolderName  = "__FICHEIROS_SEM_DATA - VERIFICAR_MANUALMENTE"
    $ci = [System.Globalization.CultureInfo]::GetCultureInfo("pt-PT")
}

Write-Host ""
Write-Host $msg_start
Write-Host "-------------------------------------------"

# Verificar exiftool — primeiro na pasta local, depois no PATH
# NOTA: exiftool.exe sozinho é apenas um "lançador" — sem a pasta
# "exiftool_files" ao lado, ele existe mas falha sempre a correr.
# Por isso testamos se realmente funciona (-ver), não só se o ficheiro existe.
$exiftoolFilesDir = Join-Path $root "exiftool_files"
$exiftoolZip      = Join-Path $root "exiftool_files.zip"
if ((Test-Path $exiftoolZip) -and (-not (Test-Path $exiftoolFilesDir))) {
    # A pasta exiftool_files pode vir compactada num único .zip (o GitHub Web UI
    # não permite enviar de uma vez uma pasta com muitos ficheiros pequenos)
    try {
        Expand-Archive -Path $exiftoolZip -DestinationPath $root -Force
        # Esconde-a já, sem esperar pelo próximo arranque do .bat (que só
        # esconde ficheiros que já existiam no início da sessão)
        attrib +h "$exiftoolFilesDir" > $null 2>&1
    } catch { }
}

$exiftoolLocal = Join-Path $root "exiftool.exe"
if (Test-Path $exiftoolLocal) {
    $env:PATH = "$root;$env:PATH"  # garante que o script o encontra
}

$exiftoolOK = $false
if (Get-Command exiftool -ErrorAction SilentlyContinue) {
    try {
        $verOutput = & exiftool -ver 2>$null
        if ($verOutput -match '^\d') { $exiftoolOK = $true }
    } catch { }
}

if (-not $exiftoolOK) {
    if ($lang -eq "en") {
        Write-Host "[WARNING] exiftool is missing or not working - dates for some videos/HEIC may be inaccurate"
        Write-Host "          Download the FULL package from https://exiftool.org (the .zip contains"
        Write-Host "          'exiftool(-k).exe' AND a folder called 'exiftool_files' - you need BOTH,"
        Write-Host "          the .exe alone will not run). Rename the exe to 'exiftool.exe' and place"
        Write-Host "          it together with the 'exiftool_files' folder in the Album folder."
        $open = Read-Host "Open download page now? (Y/N)"
        if ($open -eq "Y") { Start-Process "https://exiftool.org" }
    } else {
        Write-Host "[AVISO] exiftool esta em falta ou nao funciona - datas de alguns videos/HEIC podem ser imprecisas"
        Write-Host "        Descarrega o pacote COMPLETO em https://exiftool.org (o .zip contem o"
        Write-Host "        'exiftool(-k).exe' E uma pasta chamada 'exiftool_files' - precisas dos DOIS,"
        Write-Host "        o .exe sozinho nao funciona). Renomeia o exe para 'exiftool.exe' e coloca-o"
        Write-Host "        junto com a pasta 'exiftool_files' dentro da pasta Album."
        $open = Read-Host "Abrir pagina de download agora? (S/N)"
        if ($open -eq "S") { Start-Process "https://exiftool.org" }
    }
}

# -------------------------------
# Função: Escolher pasta (sempre no topo)
# -------------------------------
function Select-FolderDialog([string]$description,[string]$initialPath=$null){
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = $description
    $d.ShowNewFolderButton = $true
    if($initialPath -and (Test-Path $initialPath)){
        try { $d.SelectedPath = (Resolve-Path $initialPath) } catch {}
    }

    $top = New-Object System.Windows.Forms.Form
    $top.TopMost = $true
    $top.ShowInTaskbar = $false
    $top.StartPosition = "CenterScreen"

    $res = $d.ShowDialog($top)
    $top.Dispose()

    if($res -eq [System.Windows.Forms.DialogResult]::OK){
        return $d.SelectedPath
    } else {
        return $null
    }
}

# -------------------------------
# Seleção de pastas
# -------------------------------
$src = Select-FolderDialog $msg_select_source
if(-not $src){ Write-Host $msg_cancel; pause; exit }

$defaultDest = Join-Path $root "Fotos"
$dst = Select-FolderDialog $msg_select_dest $defaultDest
if(-not $dst){ Write-Host $msg_cancel; pause; exit }


# ✅ Inicializar Explorer Shell
$global:ShellApp = New-Object -ComObject Shell.Application

# -------------------------------
# Função: Obter data inteligente
# -------------------------------
function Get-DateSmart($f){
    $n   = $f.Name
    $ext = [System.IO.Path]::GetExtension($n).ToLowerInvariant()
    $d   = $null

    # 1️⃣ Detecção por nome do ficheiro
    $pats = @(
        '(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})',
        '(\d{4})(\d{2})(\d{2})[_-]',
        '(\d{8})[_-]',
        '(\d{4})[-_](\d{2})[-_](\d{2})',
        'PXL_(\d{4})(\d{2})(\d{2})_',
        'IMG_(\d{4})(\d{2})(\d{2})',
        'MVIMG_(\d{4})(\d{2})(\d{2})',
        'Screenshot_(\d{4})(\d{2})(\d{2})',
        'VID_(\d{4})(\d{2})(\d{2})_WA',
        '202\d(\d{2})(\d{2})_(\d{6})',
        'IMG_(\d{4})(\d{2})(\d{2})_(\d{6})',
        'IMG-(\d{4})(\d{2})(\d{2})-WA',
        'GOPR(\d{4})(\d{2})(\d{2})',
        'GH(\d{4})(\d{2})(\d{2})',
        'DSC_(\d{4})(\d{2})(\d{2})',
        'DSC(\d{4})(\d{2})(\d{2})',
        'DSC\d+_(\d{4})(\d{2})(\d{2})',
        'IMG_(\d{4})(\d{2})(\d{2})_(?:\d{6})',
        '(\d{4})(\d{2})(\d{2})'
    )

    foreach($p in $pats){
        if($n -match $p){
            try {
                $y=[int]$matches[1]; $m=[int]$matches[2]; $day=[int]$matches[3]
                return (Get-Date -Year $y -Month $m -Day $day)
            } catch {}
        }
    }

# 2️⃣ Data via exiftool
try {
    $exifDate = & exiftool `
        -DateTimeOriginal `
        -CreateDate `
        -MediaCreateDate `
        -TrackCreateDate `
        -s -s -s `
        -d "%Y-%m-%d %H:%M:%S" `
        $f.FullName | Select-Object -First 1

    if ($exifDate) {
        Write-Host "[EXIF SMART]" $exifDate
        return [datetime]::Parse($exifDate)
    }
}
catch {}

# 3️⃣ Windows Date Taken
try {
    $folder = $global:ShellApp.Namespace($f.DirectoryName)
    $item   = $folder.ParseName($f.Name)

    # índices comuns para datas media
    $indexes = @(12,208,206,204)

    foreach ($idx in $indexes) {

        $raw = $folder.GetDetailsOf($item, $idx)

        if ($raw) {

            Write-Host "[WINDOWS RAW idx=$idx]" $raw

            $clean = $raw -replace '[^\d/: ]',''

            try {
                $culture = [System.Globalization.CultureInfo]::CurrentCulture
                $dt = [datetime]::Parse($clean, $culture)

                Write-Host "[WINDOWS DATE OK]" $dt
                return $dt
            }
            catch {}
        }
    }
}
catch {}



    # 4 Sem data válida
    return $null
}

# -------------------------------
# Processar ficheiros
# -------------------------------
$files = Get-ChildItem -Path $src -Include *.jpg,*.jpeg,*.png,*.gif,*.webp,*.tif,*.tiff,*.heic,*.heif,
        *.mp4,*.mov,*.webm,*.mkv,*.avi,*.mts,*.m2ts,*.3gp,*.hevc -Recurse

$z3Total = $files.Count
$z3Done  = 0

$heicCount = ($files | Where-Object { $_.Extension -match '\.(heic|heif)$' }).Count
if ($heicCount -gt 0 -and -not (Get-Command exiftool -ErrorAction SilentlyContinue)) {
    if ($lang -eq "en") {
        Write-Host "[WARNING] $heicCount HEIC file(s) found. Without exiftool, dates may not be detected."
        Write-Host "          Also note: HEIC may not display in Chrome/Firefox on Windows."
    } else {
        Write-Host "[AVISO] $heicCount ficheiro(s) HEIC encontrado(s). Sem exiftool, datas podem nao ser detetadas."
        Write-Host "        Nota: HEIC pode nao exibir no Chrome/Firefox no Windows."
    }
    Write-Host ""
}

$msg_progress = if ($lang -eq "en") { "Organizing photos" } else { "A organizar fotos" }

foreach($f in $files){
    # Progresso: conta TODOS os ficheiros (copiados, saltados e sem data),
    # para a percentagem chegar sempre aos 100%
    $z3Done++
    $z3Pct = if ($z3Total -gt 0) { [int][Math]::Floor(100 * $z3Done / $z3Total) } else { 100 }
    Write-Progress -Activity "$msg_progress ($z3Pct%)" `
                   -Status "$z3Done / $z3Total ($z3Pct%)" `
                   -CurrentOperation $f.Name `
                   -PercentComplete $z3Pct
    $tag = "[{0}/{1} {2}%]" -f $z3Done, $z3Total, $z3Pct

    $dt = Get-DateSmart $f

    if (-not $dt) {
        $no = Join-Path $dst $noDateFolderName
        if (!(Test-Path -LiteralPath $no)) { New-Item -ItemType Directory -Path $no -Force | Out-Null }
        $target = Join-Path $no $f.Name
        if (-not (Test-Path -LiteralPath $target)) {
            Copy-Item -LiteralPath $f.FullName -Destination $target
            Write-Host "$tag [WARN] $msg_no_exif : $($f.Name)"
        }
        continue
    }

    $now = Get-Date
    if ($dt -gt $now.AddYears(1) -or $dt.Year -lt 1970) {
        $no = Join-Path $dst $noDateFolderName
        if (!(Test-Path -LiteralPath $no)) { New-Item -ItemType Directory -Path $no -Force | Out-Null }
        $target = Join-Path $no $f.Name
        if (-not (Test-Path -LiteralPath $target)) {
            Copy-Item -LiteralPath $f.FullName -Destination $target
            Write-Host "$tag [WARN] Data invalida ($($dt)) -> movido para: $noDateFolderName ($($f.Name))"
        }
        continue
    }

    $year  = $dt.Year
    $month = $dt.ToString("MMMM", $ci)
    $tgt   = Join-Path $dst "$year\$month"
    if (!(Test-Path -LiteralPath $tgt)) { New-Item -ItemType Directory -Path $tgt -Force | Out-Null }

    $target = Join-Path $tgt $f.Name

    if (-not (Test-Path -LiteralPath $target)) {
        Copy-Item -LiteralPath $f.FullName -Destination $target
        Write-Host "$tag [OK] $($f.Name) -> $year\$month" -ForegroundColor Green
        # Descongelar pasta de destino
        $frozenFlag = Join-Path $tgt "_frozen.flag"
        if (Test-Path -LiteralPath $frozenFlag) { Remove-Item -LiteralPath $frozenFlag -Force }
    }
    else {
        try {
            $hashSrc  = (Get-FileHash -Algorithm SHA1 -LiteralPath $f.FullName).Hash
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            $ext      = [System.IO.Path]::GetExtension($f.Name)

            # Comparar com o ficheiro original E com todas as copias _DUP que ja
            # existam. Antes so comparava com o original, por isso cada nova
            # execucao sobre a mesma origem criava mais um _DUP1, _DUP2, _DUP3...
            $candidates = @($target)
            $candidates += @(Get-ChildItem -LiteralPath $tgt -File -Force -Filter "${baseName}_DUP*$ext" -ErrorAction SilentlyContinue |
                             ForEach-Object { $_.FullName })

            $dupOf = $null
            foreach ($c in $candidates) {
                if ((Get-FileHash -Algorithm SHA1 -LiteralPath $c).Hash -eq $hashSrc) {
                    $dupOf = [System.IO.Path]::GetFileName($c)
                    break
                }
            }

            if ($dupOf) {
                Write-Host "$tag [SKIP] $($f.Name) (duplicado exato de $dupOf)"
            }
            else {
                $dupIndex = 1
                do {
                    $newName   = "${baseName}_DUP$dupIndex$ext"
                    $newTarget = Join-Path $tgt $newName
                    $dupIndex++
                } while (Test-Path -LiteralPath $newTarget)

                Copy-Item -LiteralPath $f.FullName -Destination $newTarget
                Write-Host "$tag [COPIADO] $($f.Name) (conteudo diferente, guardado como $newName)"
                # Descongelar pasta de destino
                $frozenFlag = Join-Path $tgt "_frozen.flag"
                if (Test-Path -LiteralPath $frozenFlag) { Remove-Item -LiteralPath $frozenFlag -Force }
            }
        }
        catch {
            Write-Host "$tag [ERRO] Falha ao comparar hash de $($f.Name): $_" -ForegroundColor Red
        }
    }
}
Write-Progress -Activity $msg_progress -Completed

Write-Host ""
Write-Host "-------------------------------------------"
Write-Host $msg_done -ForegroundColor Green
Write-Host $msg_reminder
Write-Host ""
Write-Host "Press any key to exit..."
[System.Console]::ReadKey() | Out-Null
