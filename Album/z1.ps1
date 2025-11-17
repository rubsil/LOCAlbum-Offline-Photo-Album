# =================================================
# LOCAlbum - Offline Photo Album - Generator (2025)
# =================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# --- Auto-elevate to Administrator if needed ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[INFO] Reexecutando como Administrador..."
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" @args"
    exit
}

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
)

# Contar ficheiros totais para progress bar
$allFiles = Get-ChildItem -Path $base -Recurse -File
$totalFiles = $allFiles.Count
$processed  = 0
$fromCache  = 0
$recomputed = 0

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
        $manifest[$yearFolder][$monthFolder] = @()

        $normMonth = Normalize-Name $monthFolder

        Get-ChildItem -Path $_.FullName -File | Sort-Object Name | ForEach-Object {

            $file = $_
            $processed++

            # Barra de progresso
            if ($totalFiles -gt 0) {
                Write-Progress -Activity $msg_processing `
                                -Status "$processed / $totalFiles" `
                                -PercentComplete ([int](100 * $processed / $totalFiles))
            }

            $name      = $file.Name
            $fileKey   = "$yearFolder/$monthFolder/$name"
            $lastWrite = $file.LastWriteTimeUtc.Ticks

            # ------------------------------
            # Tentar usar cache
            # ------------------------------
            $photoDate = $null
            if ($cache.ContainsKey($fileKey) -and $cache[$fileKey].lastWrite -eq $lastWrite) {
                $photoDate = $cache[$fileKey].date
                $fromCache++
            }
            else {
                # ------------------------------
                # Tentar extrair data do nome
                # ------------------------------
                $patterns = @(
                    '(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})',
                    '(\d{4})(\d{2})(\d{2})[_-]',
                    '(\d{8})[_-]',
                    '(\d{4})[-_](\d{2})[-_](\d{2})',
                    'PXL_(\d{4})(\d{2})(\d{2})_',
                    'IMG_(\d{4})(\d{2})(\d{2})',
                    'VID_(\d{4})(\d{2})(\d{2})',
                    'PHOTO_(\d{4})(\d{2})(\d{2})'
                )

                foreach ($pat in $patterns) {
                    if ($name -match $pat) {
                        try {
                            $y=[int]$matches[1]; $m=[int]$matches[2]; $d=[int]$matches[3]
                            $photoDate = (Get-Date -Year $y -Month $m -Day $d).ToString("yyyy-MM-dd")
                            break
                        } catch {}
                    }
                }

                # ------------------------------
                # Se falhou → tentar EXIF
                # ------------------------------
                if (-not $photoDate) {
                    try {
                        $img = [System.Drawing.Image]::FromFile($file.FullName)
                        $prop = $img.GetPropertyItem(36867)
                        $dateTaken = [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim([char]0)
                        $img.Dispose()
                        $dt = [datetime]::ParseExact($dateTaken, "yyyy:MM:dd HH:mm:ss", $null)
                        $photoDate = $dt.ToString("yyyy-MM-dd")
                    } catch {}
                }

                # ------------------------------
                # Último recurso → lastwrite
                # ------------------------------
                if (-not $photoDate) {
                    $photoDate = $file.LastWriteTime.ToString("yyyy-MM-dd")
                }

                # Guardar no cache
                $cache[$fileKey] = [pscustomobject]@{
                    key       = $fileKey
                    lastWrite = $lastWrite
                    date      = $photoDate
                }

                $recomputed++
            }

            # ------------------------------
            # THUMBNAIL (somente fotos)
            # ------------------------------
            $ext = $file.Extension.ToLower()

            if ($ext -in ".mp4", ".mov", ".avi", ".mkv", ".wmv") {

                # VÍDEO → NÃO cria thumbnail, usa ícone no HTML
                $thumbRel = $null

            }
            else {
                # FOTO → criar thumbnail normalmente
                $thumbDir   = Join-Path $thumbRoot "$yearFolder\$normMonth"
                $thumbName  = [IO.Path]::GetFileNameWithoutExtension($name) + ".jpg"
                $thumbFull  = Join-Path $thumbDir $thumbName
                $thumbRel   = "Album/Thumbnails/$yearFolder/$normMonth/$thumbName"

                New-Thumbnail -SourcePath $file.FullName -ThumbPath $thumbFull -SourceTicks $lastWrite
            }

            # ------------------------------
            # Entrada no MANIFEST
            # ------------------------------
            $manifest[$yearFolder][$monthFolder] += [pscustomobject]@{
                name  = $name
                path  = "Album/Fotos/$yearFolder/$monthFolder/$name"
                thumb = $thumbRel
                date  = $photoDate
            }
        }
    }
}

Write-Progress -Activity $msg_processing -Completed

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
Write-Host "Resumo processamento:"
Write-Host "  Total de ficheiros:           $totalFiles"
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
$htmlFinal = $template -replace '<!--CONFIG-->',   $CONFIG `
                       -replace '<!--MANIFEST-->', $MANIFEST

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
