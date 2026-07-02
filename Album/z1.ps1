# =================================================
# LOCAlbum - Offline Photo Album - Generator (2025)
# =================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# --- Garantir modo STA (necessário em Windows 11 para System.Drawing) ---
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "[INFO] Reiniciando o script em modo STA..."
    powershell.exe -STA -ExecutionPolicy Bypass -File "$PSCommandPath" @args
    exit
}

# --- Assemblies base ---
Add-Type -AssemblyName System.Drawing

# =================================================
# xxHash64 (para cache rápida)
# =================================================
Add-Type -TypeDefinition @"
using System;
using System.IO;

public static class XxHash64
{
    const ulong Prime1 = 11400714785074694791UL;
    const ulong Prime2 = 14029467366897019727UL;
    const ulong Prime3 = 1609587929392839161UL;
    const ulong Prime4 = 9650029242287828579UL;
    const ulong Prime5 = 2870177450012600261UL;

    static ulong RotateLeft(ulong value, int count)
    {
        return (value << count) | (value >> (64 - count));
    }

    static ulong Round(ulong acc, ulong input)
    {
        unchecked
        {
            acc += input * Prime2;
            acc = RotateLeft(acc, 31);
            acc *= Prime1;
            return acc;
        }
    }

    static ulong MergeRound(ulong acc, ulong val)
    {
        unchecked
        {
            val = Round(0, val);
            acc ^= val;
            acc = acc * Prime1 + Prime4;
            return acc;
        }
    }

    public static ulong ComputeHash(byte[] data)
    {
        unchecked
        {
            int len = data.Length;
            int index = 0;
            ulong hash;

            if (len >= 32)
            {
                int limit = len - 32;
                ulong v1 = Prime1 + Prime2;
                ulong v2 = Prime2;
                ulong v3 = 0;
                ulong v4 = Prime1 * 2;

                while (index <= limit)
                {
                    v1 = Round(v1, BitConverter.ToUInt64(data, index)); index += 8;
                    v2 = Round(v2, BitConverter.ToUInt64(data, index)); index += 8;
                    v3 = Round(v3, BitConverter.ToUInt64(data, index)); index += 8;
                    v4 = Round(v4, BitConverter.ToUInt64(data, index)); index += 8;
                }

                hash = RotateLeft(v1, 1) +
                       RotateLeft(v2, 7) +
                       RotateLeft(v3, 12) +
                       RotateLeft(v4, 18);

                hash = MergeRound(hash, v1);
                hash = MergeRound(hash, v2);
                hash = MergeRound(hash, v3);
                hash = MergeRound(hash, v4);
            }
            else
            {
                hash = Prime5;
            }

            hash += (ulong)len;

            while (len - index >= 8)
            {
                ulong k1 = BitConverter.ToUInt64(data, index);
                k1 *= Prime2;
                k1 = RotateLeft(k1, 31);
                k1 *= Prime1;
                hash ^= k1;
                hash = RotateLeft(hash, 27) * Prime1 + Prime4;
                index += 8;
            }

            if (len - index >= 4)
            {
                hash ^= (ulong)BitConverter.ToUInt32(data, index) * Prime1;
                hash = RotateLeft(hash, 23) * Prime2 + Prime3;
                index += 4;
            }

            while (index < len)
            {
                hash ^= (ulong)data[index] * Prime5;
                hash = RotateLeft(hash, 11) * Prime1;
                index++;
            }

            hash ^= hash >> 33;
            hash *= Prime2;
            hash ^= hash >> 29;
            hash *= Prime3;
            hash ^= hash >> 32;

            return hash;
        }
    }

    public static string ComputeHashString(string path)
    {
        unchecked
        {
            byte[] data = File.ReadAllBytes(path);
            ulong h = ComputeHash(data);
            return h.ToString("X16");
        }
    }
}
"@

function Get-FastFileHash {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try { return [XxHash64]::ComputeHashString($Path) }
    catch { return $null }
}

# =================================================
# Caminhos base
# =================================================
$root         = Split-Path -Parent $MyInvocation.MyCommand.Path
$base         = Join-Path $root "Fotos"
$templatePath = Join-Path $root "template.html"
$iniPath      = Join-Path $root "config.ini"
$cachePath    = Join-Path $root "localbum-cache.json"
$albumRoot    = Split-Path $root -Parent
$thumbRoot    = Join-Path $albumRoot "Album\Thumbnails"

Write-Host ""
Write-Host "====================================================="
Write-Host "           LOCALBUM - OFFLINE PHOTO ALBUM            "
Write-Host "====================================================="
Write-Host ""
Write-Host "Lendo fotos em: $base"
Write-Host ""

# =================================================
# Tiny INI Reader + criação interactiva (versão antiga)
# =================================================
$cfg = @{}
if (Test-Path $iniPath) {
    Get-Content $iniPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^\s*#') { return }
        if ($line -match '^\[')   { return }
        if ($line -match '^\s*$') { return }
        $kv = $line -split '=', 2
        if ($kv.Count -eq 2) {
            $k = $kv[0].Trim().ToLower()
            $v = $kv[1].Trim()
            $cfg[$k] = $v
        }
    }
}
else {
    Write-Host "Nenhum ficheiro config.ini foi encontrado."
    Write-Host "Vamos criar um album novo com as tuas preferencias:"
    Write-Host ""

    $cfg = @{}

    Write-Host ""
    Write-Host "====================================================="
    Write-Host "Escolhe o idioma / Choose language:"
    Write-Host "[1] Portugues"
    Write-Host "[2] English"
    Write-Host "====================================================="
    $choice = Read-Host "Seleciona uma opcao [1-2]"
    switch ($choice) {
        "2" { $lang = "en" }
        default { $lang = "pt" }
    }
    $cfg['language'] = $lang
    Write-Host ""

    if ($cfg['language'] -eq 'en') {
        Write-Host ""
        Write-Host "Please enter two quick details to create your new album:"
        Write-Host ""

        # Show example screenshot (help)
        $screenshot = Join-Path $root "ajuda_album.png"
        if (Test-Path $screenshot) {
            try {
                Add-Type -AssemblyName System.Windows.Forms
                Add-Type -AssemblyName System.Drawing

                $form = New-Object System.Windows.Forms.Form
                $form.Text = "Help - LOCALBUM"
                $form.StartPosition = "Manual"
                $form.Left = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width - 840
                $form.Top  = 100
                $form.Width = 700
                $form.Height = 600
                $form.FormBorderStyle = 'FixedSingle'
                $form.MaximizeBox = $false
                $form.MinimizeBox = $false
                $form.TopMost = $true

                $pic = New-Object System.Windows.Forms.PictureBox
                $pic.Image = [System.Drawing.Image]::FromFile($screenshot)
                $pic.SizeMode = 'Zoom'
                $pic.Dock = 'Fill'

                $form.Controls.Add($pic)
                $form.Add_Shown({$form.Activate()})
                $null = $form.ShowDialog()
            } catch {
                # fallback
                Start-Process $screenshot
            }

            Write-Host ">>> An example image was opened to show where the title and age appear."
            Write-Host "Close the image window and continue here."
            Write-Host ""
        }

        $cfg['display_name'] = Read-Host "1/2 - Album name to show as Album title (ex: Ines Memories)"
        $cfg['birthdate']    = Read-Host "2/2 - Birthdate (OPTIONAL), ideal for albums with photos from birth onwards (YYYY-MM-DD)"
        $cfg['theme']        = "dark"
        $cfg['page_title']   = "LOCALBUM - Offline Photo Album"
        $cfg['donate_url']   = "https://www.paypal.me/rubsil"
        $cfg['author']       = "Ruben Silva"
        $cfg['project_name'] = "LOCALBUM - Offline Photo Album"
        Write-Host ""
        Write-Host "Configuration saved to config.ini"
    }
    else {
        Write-Host ""
        Write-Host "Introduz 2 dados rapidos para criar o teu novo album:"
        Write-Host ""

        # Mostrar screenshot explicativo
        $screenshot = Join-Path $root "ajuda_album.png"
        if (Test-Path $screenshot) {
            try {
                Add-Type -AssemblyName System.Windows.Forms
                Add-Type -AssemblyName System.Drawing

                $form = New-Object System.Windows.Forms.Form
                $form.Text = "Ajuda - LOCALBUM"
                $form.StartPosition = "Manual"
                $form.Left = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width - 840
                $form.Top  = 100
                $form.Width = 700
                $form.Height = 600
                $form.FormBorderStyle = 'FixedSingle'
                $form.MaximizeBox = $false
                $form.MinimizeBox = $false
                $form.TopMost = $true

                $pic = New-Object System.Windows.Forms.PictureBox
                $pic.Image = [System.Drawing.Image]::FromFile($screenshot)
                $pic.SizeMode = 'Zoom'
                $pic.Dock = 'Fill'

                $form.Controls.Add($pic)
                $form.Add_Shown({$form.Activate()})
                $null = $form.ShowDialog()
            } catch {
                Start-Process $screenshot
            }

            Write-Host ">>> Uma imagem de exemplo foi aberta para mostrar onde o titulo e a idade aparecem."
            Write-Host "Fecha a imagem e continua aqui."
            Write-Host ""
        }

        $cfg['display_name'] = Read-Host "1/2 - Nome do album para mostrar como titulo (ex: Memorias da Ines)"
        $cfg['birthdate']    = Read-Host "2/2 - Data de nascimento (OPCIONAL), ideal para albuns com fotos desde a nascenca para mostrar a idade do bebe/crianca nas fotos (AAAA-MM-DD)"
        $cfg['theme']        = "dark"
        $cfg['page_title']   = "LOCALBUM - Offline Photo Album"
        $cfg['donate_url']   = "https://www.paypal.me/rubsil"
        $cfg['author']       = "Ruben Silva"
        $cfg['project_name'] = "LOCALBUM - Offline Photo Album"
        Write-Host ""
        Write-Host "Ficheiro config.ini criado com sucesso!"
    }

    # Gravar config.ini e ocultar
    $lines = @()
    foreach ($k in $cfg.Keys) { $lines += "$k=$($cfg[$k])" }
    Set-Content -Path $iniPath -Value $lines -Encoding UTF8
    attrib +h +s "$iniPath" > $null 2>&1
    Write-Host ""
    Write-Host "Ficheiro config.ini guardado e ocultado em:"
    Write-Host "  $iniPath"
    Write-Host ""
}

# =================================================
# Defaults finais (garantir tudo definido)
# =================================================
function Sanitize($val, $def) {
    if ([string]::IsNullOrWhiteSpace($val)) { return $def }
    return ($val -replace '[:=]+','').Trim()
}

$cfg['language']     = Sanitize $cfg['language']     'pt'
$cfg['display_name'] = Sanitize $cfg['display_name'] 'Memórias'
$cfg['page_title']   = Sanitize $cfg['page_title']   'LOCALBUM - Offline Photo Album'
$cfg['birthdate']    = Sanitize $cfg['birthdate']    ''
$cfg['theme']        = Sanitize $cfg['theme']        'dark'
$cfg['donate_url']   = Sanitize $cfg['donate_url']   'https://www.paypal.me/rubsil'
$cfg['author']       = Sanitize $cfg['author']       'Ruben Silva'
$cfg['project_name'] = Sanitize $cfg['project_name'] 'LOCALBUM - Offline Photo Album'

# =================================================
# Verificar FFmpeg — sempre pelo caminho local, nunca pelo PATH do sistema
# =================================================
$ffmpegCmd = $null
$ffmpegLocal = Join-Path $root "ffmpeg.exe"
if (Test-Path $ffmpegLocal) {
    $ffmpegCmd = $ffmpegLocal
    Write-Host "[OK] ffmpeg.exe encontrado na pasta Album" -ForegroundColor Green
} else {
    if ($cfg['language'] -eq 'en') {
        Write-Host "[INFO] ffmpeg.exe not found - video thumbnails will not be generated"
        Write-Host "       Download static build from https://ffmpeg.org (Windows > gyan.dev > ffmpeg-release-essentials)"
        Write-Host "       Place ffmpeg.exe in the Album folder alongside exiftool.exe"
    } else {
        Write-Host "[INFO] ffmpeg.exe nao encontrado - thumbnails de video nao serao gerados"
        Write-Host "       Descarrega a versao estatica em https://ffmpeg.org (Windows > gyan.dev > ffmpeg-release-essentials)"
        Write-Host "       Coloca o ffmpeg.exe na pasta Album ao lado do exiftool.exe"
    }
}

# Nome da página de saída
if ($cfg['language'] -eq 'en') { $outName = "View album.html" }
else                            { $outName = "Ver album.html" }

$out = Join-Path (Split-Path $root -Parent) $outName
Write-Host "Gerando HTML em: $out"
Write-Host ""

# =================================================
# Traduções PT / EN para mensagens do modo incremental
# =================================================
if ($cfg['language'] -eq 'en') {
    $msg_processing  = "Processing photos..."
    $msg_scanning    = "Scanning folders..."
    $msg_using_cache = "Using cache (previously processed files)..."
    $msg_cache_saved = "Cache updated."
} else {
    $msg_processing  = "Processando fotos..."
    $msg_scanning    = "A analisar pastas..."
    $msg_using_cache = "A usar cache (ficheiros já processados)..."
    $msg_cache_saved = "Cache atualizado."
}

# =================================================
# Carregar cache incremental
# =================================================
$cache = @{}
if (Test-Path $cachePath) {
    try {
        $json = Get-Content $cachePath -Raw -Encoding UTF8
        if ($json) {
            ($json | ConvertFrom-Json) | ForEach-Object {
                if ($_.key) { $cache[$_.key] = $_ }
            }
        }
        Write-Host "$msg_using_cache ($($cache.Count) entradas)"
    } catch {
        Write-Host "Aviso: cache inválida → será reconstruída."
        $cache = @{}
    }
} else {
    Write-Host $msg_scanning
}

# =================================================
# Função: gerar thumbnail (250px, qualidade 70)
# =================================================
function New-Thumbnail {
    param(
        [string]$SourcePath,
        [string]$ThumbPath,
        [long]$SourceTicks
    )

    # Se a thumbnail existe e é mais recente → skip
    if (Test-Path $ThumbPath) {
        if ( (Get-Item $ThumbPath).LastWriteTimeUtc.Ticks -ge $SourceTicks ) {
            return
        }
    }

    try {
        # Criar pasta se não existir
        $dir = Split-Path $ThumbPath -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $img = [System.Drawing.Image]::FromFile($SourcePath)

        $maxW = 250
        $maxH = 250
        $ratio = [Math]::Min($maxW / $img.Width, $maxH / $img.Height)
        if ($ratio -gt 1) { $ratio = 1 }

        $newW = [int]($img.Width  * $ratio)
        $newH = [int]($img.Height * $ratio)

        $bmp = New-Object System.Drawing.Bitmap($newW, $newH)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = 7
        $g.SmoothingMode     = 2
        $g.PixelOffsetMode   = 2
        $g.CompositingQuality= 2
        $g.DrawImage($img, 0, 0, $newW, $newH)

        $g.Dispose()
        $img.Dispose()

        # JPEG encoder 70%
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                 Where-Object { $_.MimeType -eq "image/jpeg" } |
                 Select-Object -First 1

        $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
            [System.Drawing.Imaging.Encoder]::Quality, 70L
        )

        $bmp.Save($ThumbPath, $codec, $params)
        $bmp.Dispose()

    } catch {
        # Evitar letras vermelhas → ignorar erros silenciosamente
    }
}

function New-VideoThumbnail {
    param(
        [string]$SourcePath,
        [string]$ThumbPath,
        [long]$SourceTicks
    )

    if (-not $ffmpegCmd) { return }

    if (Test-Path $ThumbPath) {
        if ((Get-Item $ThumbPath).LastWriteTimeUtc.Ticks -ge $SourceTicks) { return }
    }

    try {
        $dir = Split-Path $ThumbPath -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # Tenta extrair o frame no 1º segundo; se falhar (vídeo muito curto), faz fallback para o frame 0
        & $ffmpegCmd -i "$SourcePath" -ss 00:00:01 -vframes 1 `
            -vf "scale=250:-1" -q:v 3 "$ThumbPath" -y 2>$null

        if (-not (Test-Path $ThumbPath) -or (Get-Item $ThumbPath).Length -lt 512) {
            & $ffmpegCmd -i "$SourcePath" -ss 00:00:00 -vframes 1 `
                -vf "scale=250:-1" -q:v 3 "$ThumbPath" -y 2>$null
        }

        # Se mesmo assim falhar, apaga para não guardar lixo corrompido
        if ((Test-Path $ThumbPath) -and (Get-Item $ThumbPath).Length -lt 512) {
            Remove-Item $ThumbPath -Force
        }
    } catch {
        # Falha silenciosa
    }
}

# =================================================
# Função: normalizar pastas (remover acentos)
# =================================================
function Normalize-Name($name) {
    $name = $name.ToLower()
    $name = $name.Normalize("FormD") -replace '[\p{Mn}]',''
    return $name
}

# =================================================
# Construção do MANIFEST (com cache + thumbnails)
# =================================================
$manifest = @{}

if (-not (Test-Path $base)) {
    New-Item -ItemType Directory -Path $base | Out-Null
}

# Pastas a ignorar (PT e EN)
$foldersToIgnore = @(
    "__FICHEIROS_SEM_DATA - VERIFICAR_MANUALMENTE",
    "__FILES_WITHOUT_DATE - CHECK_MANUALLY"
    "_corrompidos-corrupted"
)

# Contar ficheiros totais para progress bar
$allFiles = Get-ChildItem -Path $base -Recurse -File
$totalFiles = $allFiles.Count
$processed  = 0
$fromCache  = 0
$recomputed = 0
$fromFrozen = 0

# Loop: ano → mês → ficheiros
Get-ChildItem -Path $base -Directory |
    Where-Object { $foldersToIgnore -notcontains $_.Name.Trim() } |
    Sort-Object Name | ForEach-Object {

    $yearFolder = $_.Name
    if (-not $manifest.ContainsKey($yearFolder)) {
        $manifest[$yearFolder] = @{}
    }

Get-ChildItem -Path $_.FullName -Directory | Sort-Object Name | ForEach-Object {

        $monthFolder = $_.Name
        $manifest[$yearFolder][$monthFolder] = [System.Collections.Generic.List[object]]::new()
        $normMonth = Normalize-Name $monthFolder

        $frozenFlag = Join-Path $_.FullName "_frozen.flag"
        $cacheMonth = Join-Path $_.FullName "_cache_mes.json"

        # ── PASTA CONGELADA → carregar cache e saltar scan ──
        if (Test-Path $frozenFlag) {
            try {
                $cached = Get-Content $cacheMonth -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($entry in $cached) {
                    $manifest[$yearFolder][$monthFolder].Add([pscustomobject]$entry)
                }
                $fromFrozen++
                Write-Host "  [✓ FROZEN] $yearFolder\$monthFolder" -ForegroundColor Green
                [System.Console]::Out.Flush()
                return  # continua para o próximo mês
            }
            catch {
                Write-Host "  [AVISO] Cache corrompida, re-escanear: $monthFolder"
                # falha → cai no scan normal
            }
        }

        # ── SCAN NORMAL ──────────────────────────────────────
        Get-ChildItem -Path $_.FullName -File | Sort-Object Name | ForEach-Object {

            $file = $_
            $processed++

            # === SISTEMA DE QUARENTENA PARA FICHEIROS CORROMPIDOS / VAZIOS ===
            $isCorrupted = $false
            $quarantineReason = ""

            if ($file.Length -eq 0) {
                $isCorrupted = $true
                $quarantineReason = "Ficheiro com tamanho de 0 KB (Vazio)"
            } else {
                $ext = $file.Extension.ToLower()
                # Testa se o ficheiro é uma imagem e se consegue ser lido sem dar erro
                if ($ext -in @(".jpg", ".jpeg", ".png", ".bmp", ".gif", ".webp")) {
                    try {
                        $testImg = [System.Drawing.Image]::FromFile($file.FullName)
                        $testImg.Dispose()
                    } catch {
                        $isCorrupted = $true
                        $quarantineReason = "Ficheiro de imagem corrompido / truncado"
                    }
                }
            }

            if ($isCorrupted) {
                $quarantineDir = Join-Path $base "_corrompidos-corrupted"
                if (-not (Test-Path $quarantineDir)) {
                    New-Item -ItemType Directory -Path $quarantineDir -Force | Out-Null
                }
                $destPath = Join-Path $quarantineDir $file.Name
                # Se já existir um ficheiro com o mesmo nome na quarentena, gera um nome único
                if (Test-Path $destPath) {
                    $destPath = Join-Path $quarantineDir "$([IO.Path]::GetFileNameWithoutExtension($file.Name))_$([Guid]::NewGuid().ToString().Substring(0,8))$($file.Extension)"
                }
                try {
                    Move-Item -Path $file.FullName -Destination $destPath -Force
                    $logFile = Join-Path $quarantineDir "erros_leitura.txt"
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Movido: $($file.FullName) -> Motivo: $quarantineReason" | Out-File -FilePath $logFile -Append -Encoding utf8
                    Write-Host "  [QUARENTENA] Ficheiro corrompido movido: $($file.Name) ($quarantineReason)" -ForegroundColor Yellow
                } catch {
                    Write-Host "  [ERRO] Falha ao mover o ficheiro corrompido: $($file.Name)" -ForegroundColor Red
                }
                return # Salta este ficheiro e continua para o próximo do loop
            }
            # ==================================================================

            if ($totalFiles -gt 0) {
                Write-Progress -Activity $msg_processing `
                                -Status "$processed / $totalFiles" `
                                -PercentComplete ([int](100 * $processed / $totalFiles))
            }

            $name      = $file.Name
            $fileKey   = "$yearFolder/$monthFolder/$name"
            $lastWrite = $file.LastWriteTimeUtc.Ticks

            $photoDate = $null
            if ($cache.ContainsKey($fileKey) -and $cache[$fileKey].lastWrite -eq $lastWrite) {
                $photoDate = $cache[$fileKey].date
                $fromCache++
            }
            else {
$nameNoExt = [IO.Path]::GetFileNameWithoutExtension($name)

$patterns = @(
                    # Com hora (prioridade máxima)
                    'PXL_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})',
                    'MVIMG_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})',
                    'PANO_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})',
                    'Screenshot_(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})',
                    'IMG_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})',
                    'VID_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})',
                    '(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})',
                    # Sem hora (fallback)
                    'PXL_(\d{4})(\d{2})(\d{2})_',
                    'MVIMG_(\d{4})(\d{2})(\d{2})',
                    'PANO_(\d{4})(\d{2})(\d{2})',
                    'Screenshot_(\d{4})(\d{2})(\d{2})',
                    'IMG_(\d{4})(\d{2})(\d{2})',
                    'IMG-(\d{4})(\d{2})(\d{2})-WA',
                    'IMG-(\d{4})(\d{2})(\d{2})',
                    'VID_(\d{4})(\d{2})(\d{2})',
                    'VID-(\d{4})(\d{2})(\d{2})-WA',
                    'VID-(\d{4})(\d{2})(\d{2})',
                    'PTT-(\d{4})(\d{2})(\d{2})-WA',
                    'GOPR(\d{4})(\d{2})(\d{2})',
                    'GH(\d{4})(\d{2})(\d{2})',
                    'DSC_(\d{4})(\d{2})(\d{2})',
                    'DSC\d+_(\d{4})(\d{2})(\d{2})',
                    'photo_(\d{4})-(\d{2})-(\d{2})',
                    'video_(\d{4})-(\d{2})-(\d{2})',
                    'signal-(\d{4})-(\d{2})-(\d{2})',
                    '(\d{4})(\d{2})(\d{2})[_-]',
                    '(\d{4})[-_](\d{2})[-_](\d{2})',
                    '(\d{4})(\d{2})(\d{2})'
                )

foreach ($pat in $patterns) {
                    if ($nameNoExt -match $pat) {
                        try {
                            $yr=[int]$matches[1]; $mo=[int]$matches[2]; $dy=[int]$matches[3]
                            if ($yr -ge 1970 -and $yr -le 2100 -and $mo -ge 1 -and $mo -le 12 -and $dy -ge 1 -and $dy -le 31) {
                                if ($matches[4] -and $matches[5] -and $matches[6]) {
                                    $hh=[int]$matches[4]; $mm=[int]$matches[5]; $ss=[int]$matches[6]
                                    if ($hh -le 23 -and $mm -le 59 -and $ss -le 59) {
                                        $photoDate = (Get-Date -Year $yr -Month $mo -Day $dy -Hour $hh -Minute $mm -Second $ss).ToString("yyyy-MM-dd HH:mm:ss")
                                        break
                                    }
                                }
                                $photoDate = (Get-Date -Year $yr -Month $mo -Day $dy).ToString("yyyy-MM-dd")
                                break
                            }
                        } catch {}
                    }
                }

                if (-not $photoDate) {
                    foreach ($propId in @(36867, 36868, 306)) {
                        try {
                            $img = [System.Drawing.Image]::FromFile($file.FullName)
                            $prop = $img.GetPropertyItem($propId)
                            $dateTaken = [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim([char]0)
                            $img.Dispose()
                            $dt = [datetime]::ParseExact($dateTaken, "yyyy:MM:dd HH:mm:ss", $null)
                            $photoDate = $dt.ToString("yyyy-MM-dd HH:mm:ss")
                            break
                        } catch {}
                    }
                }

                if (-not $photoDate -and (Get-Command exiftool -ErrorAction SilentlyContinue)) {
                    try {
                        $exifDate = & exiftool -DateTimeOriginal -CreateDate -s -s -s `
                                    -d "%Y-%m-%d %H:%M:%S" $file.FullName |
                                    Where-Object { $_ -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$' } |
                                    Select-Object -First 1
                        if ($exifDate) { $photoDate = $exifDate.Trim() }
                    } catch {}
                }

                if (-not $photoDate) {
                    $monthMap = @{
    "janeiro"="01"; "fevereiro"="02"; "marco"="03"; "abril"="04"
    "maio"="05"; "junho"="06"; "julho"="07"; "agosto"="08"
    "setembro"="09"; "outubro"="10"; "novembro"="11"; "dezembro"="12"
    "january"="01"; "february"="02"; "march"="03"; "april"="04"
    "may"="05"; "june"="06"; "july"="07"; "august"="08"
    "september"="09"; "october"="10"; "november"="11"; "december"="12"
}
$normM = $monthFolder.ToLower().Normalize("FormD") -replace '[\p{Mn}]',''
$monthNum = if ($monthMap[$normM]) { $monthMap[$normM] } else { "01" }
$photoDate = "$yearFolder-$monthNum-01"
                }

                $cache[$fileKey] = [pscustomobject]@{
                    key       = $fileKey
                    lastWrite = $lastWrite
                    date      = $photoDate
                }
                $recomputed++
            }

$ext = $file.Extension.ToLower()

            $thumbDir  = Join-Path $thumbRoot "$yearFolder\$normMonth"
            $thumbName = [IO.Path]::GetFileNameWithoutExtension($name) + ".jpg"
            $thumbFull = Join-Path $thumbDir $thumbName
            $thumbRel  = "Album/Thumbnails/$yearFolder/$normMonth/$thumbName"

            if ($ext -in ".mp4", ".mov", ".webm", ".mkv", ".avi", ".mts", ".m2ts", ".3gp", ".hevc") {
                if ($ffmpegCmd) {
                    New-VideoThumbnail -SourcePath $file.FullName -ThumbPath $thumbFull -SourceTicks $lastWrite
                    if (-not (Test-Path $thumbFull)) { $thumbRel = $null }
                } else {
                    $thumbRel = $null
                }
            } else {
                New-Thumbnail -SourcePath $file.FullName -ThumbPath $thumbFull -SourceTicks $lastWrite
            }

            $manifest[$yearFolder][$monthFolder].Add([pscustomobject]@{
                name  = $name
                path  = "Album/Fotos/$yearFolder/$monthFolder/$name"
                thumb = $thumbRel
                date  = $photoDate
            })
        }

        # ── GUARDAR CACHE DO MÊS E CONGELAR ─────────────────
        $manifest[$yearFolder][$monthFolder] |
            ConvertTo-Json -Depth 5 |
            Set-Content -Path $cacheMonth -Encoding UTF8

        [System.IO.File]::WriteAllText($frozenFlag, "")
        attrib +h +s "$frozenFlag" > $null 2>&1
        attrib +h +s "$cacheMonth" > $null 2>&1
    }
}

# =================================================
# Processar pasta sem data (Fotos Diversas com Divisão Automática)
# =================================================
$noDatePT = "__FICHEIROS_SEM_DATA - VERIFICAR_MANUALMENTE"
$noDateEN = "__FILES_WITHOUT_DATE - CHECK_MANUALLY"
$noDateFullPath = $null

foreach ($ndName in @($noDatePT, $noDateEN)) {
    $p = Join-Path $base $ndName
    if (Test-Path $p) { $noDateFullPath = $p; break }
}

if ($noDateFullPath) {
    $specialYear = "9999"
    if (-not $manifest.ContainsKey($specialYear)) {
        $manifest[$specialYear] = @{}
    }

    # 1. Obter todos os ficheiros da pasta sem data
    $noDateFiles = Get-ChildItem -Path $noDateFullPath -File | Sort-Object Name
    
    # --- CONFIGURAÇÃO DO LIMITE ---
    $photoLimit  = 500  # <--- Altera aqui o limite de fotos por bloco (500 é o ideal para performance)
    # ------------------------------

    $chunkIndex  = 1
    $fileCounter = 0

    # Determinar o nome base do idioma para os blocos
    $baseMonthName = if ($cfg['language'] -eq 'en') { "Part" } else { "Parte" }
    
    # Formata como "Parte 01" (o zero à esquerda garante que a ordenação no ecrã fica correta: 01, 02... em vez de 1, 10, 2)
    $chunkStr     = "{0:D2}" -f $chunkIndex
    $specialMonth = "$baseMonthName $chunkStr"
    $normSpecial  = Normalize-Name $specialMonth

    $manifest[$specialYear][$specialMonth] = [System.Collections.Generic.List[object]]::new()
    $noDateFolderLeaf = Split-Path $noDateFullPath -Leaf

    foreach ($file in $noDateFiles) {
        
        # 2. Se atingir o limite de fotos, fecha este bloco e abre a "Parte" seguinte
        if ($fileCounter -ge $photoLimit) {
            $chunkIndex++
            $fileCounter  = 0
            $chunkStr     = "{0:D2}" -f $chunkIndex
            $specialMonth = "$baseMonthName $chunkStr"
            $normSpecial  = Normalize-Name $specialMonth
            $manifest[$specialYear][$specialMonth] = [System.Collections.Generic.List[object]]::new()
        }

        $name = $file.Name
        $ext  = $file.Extension.ToLower()

        $thumbRel = $null
        if ($ext -notin @(".mp4",".mov",".webm",".mkv",".avi",".mts",".m2ts",".3gp",".hevc")) {
            $thumbDir  = Join-Path $thumbRoot "$specialYear\$normSpecial"
            $thumbName = [IO.Path]::GetFileNameWithoutExtension($name) + ".jpg"
            $thumbFull = Join-Path $thumbDir $thumbName
            $thumbRel  = "Album/Thumbnails/$specialYear/$normSpecial/$thumbName"
            New-Thumbnail -SourcePath $file.FullName -ThumbPath $thumbFull -SourceTicks $file.LastWriteTimeUtc.Ticks
        }

        $manifest[$specialYear][$specialMonth].Add([pscustomobject]@{
            name  = $name
            path  = "Album/Fotos/$noDateFolderLeaf/$name"
            thumb = $thumbRel
            date  = ""
        })

        $fileCounter++
    }
    Write-Host "  [SEM DATA] Dividido automaticamente em $chunkIndex parte(s) dentro de '$specialYear'"
}

# =================================================
# Finalizar processamento → guardar cache
# =================================================
$cacheArray = @()
foreach ($k in $cache.Keys) {
    $cacheArray += $cache[$k]
}

$cacheArray | ConvertTo-Json -Depth 5 |
    Set-Content -Path $cachePath -Encoding UTF8

# Tornar cache invisível
attrib +h +s "$cachePath" > $null 2>&1

# Tornar a pasta Thumbnails invisível também
if (Test-Path $thumbRoot) {
    attrib +h +s "$thumbRoot" > $null 2>&1
}

Write-Host ""
Write-Host "Resumo processamento:" -ForegroundColor Cyan
Write-Host "  Total de ficheiros:           $totalFiles"
Write-Host "  Pastas congeladas (skip):     $fromFrozen"
Write-Host "  Reutilizados do cache:        $fromCache"
Write-Host "  Novos/alterados (scan EXIF):  $recomputed"
Write-Host ""

# =================================================
# INJETAR CONFIG + MANIFEST NO TEMPLATE.HTML
# =================================================

if (-not (Test-Path $templatePath)) {
    Write-Host "ERRO: template.html NÃO encontrado em:"
    Write-Host "  $templatePath"
    pause
    exit
}

# Config a embutir no HTML
$configObj = [ordered]@{
    language     = $cfg['language']
    displayName  = $cfg['display_name']
    pageTitle    = $cfg['page_title']
    birthdate    = $cfg['birthdate']
    theme        = $cfg['theme']
    donateURL    = $cfg['donate_url']
    author       = $cfg['author']
    projectName  = $cfg['project_name']
}

$CONFIG   = "const CONFIG = "   + (ConvertTo-Json $configObj -Compress) + ";"
$MANIFEST = "const manifest = " + (ConvertTo-Json $manifest -Depth 6 -Compress) + ";"

# Ler template
$template  = Get-Content -Raw $templatePath -Encoding UTF8

# Inject
$htmlFinal = $template.Replace('<!--CONFIG-->', $CONFIG).Replace('<!--MANIFEST-->', $MANIFEST)

# Favicon com TAG de versão (força refresh no navegador)
$versionTag = (Get-Date).ToString("yyyyMMddHHmmss")
$favicon = "<link rel='icon' type='image/png' href='Album/favicon.png?v=$versionTag'/>"

$htmlFinal = $htmlFinal -replace '(<title>LOCAlbum - Offline Photo Album</title>)',
                           "`$1`r`n  $favicon"

# Escrever ficheiro final
Set-Content -Path $out -Value $htmlFinal -Encoding UTF8

Write-Host ""
Write-Host $msg_cache_saved
Write-Host ""
Write-Host "LOCALBUM gerou com sucesso:"
Write-Host "  $out"
Write-Host ""
Write-Host "Pressiona Enter para fechar..."
pause > $null
