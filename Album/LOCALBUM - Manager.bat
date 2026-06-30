@echo off
chcp 65001 >nul
title LOCALBUM Manager - Offline Photo Album
setlocal EnableDelayedExpansion EnableExtensions

:: =====================================================
::  LOCALBUM - OFFLINE PHOTO ALBUM (versão 2025.11)
::  Autor: Rúben Silva
:: =====================================================

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "INI=%ROOT%\config.ini"
set "PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PWSH%" set "PWSH=powershell.exe"

:: Resolução limpa da pasta-mãe (origem do Backup) sem usar ".." no Robocopy
for %%I in ("%ROOT%\..") do set "SOURCE_DIR=%%~fI"

:: =====================================================
::  OCULTAR ficheiros técnicos logo ao arrancar
:: =====================================================
for %%A in (z1.ps1 z3.ps1 template.html favicon.png ajuda_album.png exiftool.exe ffmpeg.exe) do (
    if exist "%ROOT%\%%A" (
        attrib +h +s "%ROOT%\%%A" >nul 2>&1
    )
)

:: =====================================================
::  SELECIONAR LÍNGUA
:: =====================================================
cls
echo =====================================================
echo               LOCALBUM - OFFLINE PHOTO ALBUM
echo =====================================================
echo.
echo 🌍 Escolhe o idioma / Choose language:
echo [1] PT  → Português
echo [2] EN  → English
echo.
set /p LANG_CHOICE="Seleciona uma opção / Choose (1 / 2): "
if "%LANG_CHOICE%"=="2" (
    set "LANG=en"
) else (
    set "LANG=pt"
)

cls
if "%LANG%"=="pt" (
    goto MENU_PT
) else (
    goto MENU_EN
)

:: =====================================================
::  MENU PORTUGUÊS
:: =====================================================
:MENU_PT
cls
echo =====================================================
echo        LOCALBUM - Gestor do Álbum Offline
echo =====================================================
echo.
echo [1] Organizar fotos automaticamente - (ideal para centenas/milhares de fotos)
echo [2] Atualizar / Criar álbum (HTML)  - (cria o Ver album.html ou updates)
echo [3] Repor / Resetar o álbum         - (repõe as definições do Álbum, NÃO apaga fotos)
echo [4] Fazer Cópia de Segurança        - (Backup incremental das tuas fotos e álbum)
echo [i] Informações / Ajuda             - (explicações gerais)
echo [0] Sair
echo.
echo =====================================================
set /p op="Escolhe uma opção: "

if /i "%op%"=="1" goto ORGANIZE
if /i "%op%"=="2" goto GENERATE
if /i "%op%"=="3" goto RESET
if /i "%op%"=="4" goto BACKUP
if /i "%op%"=="i" goto INFO
if "%op%"=="0" exit
goto MENU_PT

:: =====================================================
::  MENU INGLÊS
:: =====================================================
:MENU_EN
cls
echo =====================================================
echo        LOCALBUM - Offline Album Manager
echo =====================================================
echo.
echo [1] Auto-organize photos          - (ideal for hundreds/thousands of photos)
echo [2] Update / Create album (HTML)  - (creates or updates "View album.html")
echo [3] Reset album                   - (resets album settings, keeps all photos)
echo [4] Create Backup (Incremental)   - (Safeguard your photos and album structure)
echo [i] Information / Help            - (how it all works)
echo [0] Exit
echo.
echo =====================================================
set /p op="Choose an option: "

if /i "%op%"=="1" goto ORGANIZE
if /i "%op%"=="2" goto GENERATE
if /i "%op%"=="3" goto RESET
if /i "%op%"=="4" goto BACKUP
if /i "%op%"=="i" goto INFO
if "%op%"=="0" exit
goto MENU_EN


:: =====================================================
::  INFO / AJUDA DETALHADA
:: =====================================================
:INFO
cls
if "%LANG%"=="pt" goto INFO_PT
goto INFO_EN

:INFO_PT
echo =====================================================
echo 📘 INFORMAÇÕES / AJUDA - LOCALBUM
echo =====================================================
echo Versão 2025.11 — Rúben Silva
echo =====================================================
echo.
echo LOCALBUM organiza as tuas fotos por ano e mês automaticamente e cria um álbum HTML offline
echo que pode ser aberto/visto em PCs, Smart TVs (com navegador compatível) ou em macOS/Linux.
echo.
echo ================== EXPLICAÇÃO DE CADA OPÇÃO ==================
echo.
echo ► [1] ORGANIZAR FOTOS AUTOMATICAMENTE
echo        - Escolhe a pasta com as tuas fotos (podem estar também em subpastas) e define "Album\Fotos"
echo          como pasta de destino para que fiquem disponíveis para o LOCALBUM as visualizar.
echo        - Cria automaticamente as subpastas por ANO e MÊS.
echo        - Se encontrar ficheiros exatamente iguais, estes são ignorados.
echo        - Primeiro, esta ferramenta tenta detetar a data de cada foto pelo nome do ficheiro original;
echo          caso contrário, usa a data em que a foto foi tirada (guardada nas propriedades do ficheiro).
echo          Este último método pode tornar o processo um pouco mais demorado, mas é automático.
echo        - Mais tarde, se o utilizador quiser adicionar mais fotos a "Album\Fotos", pode fazê-lo
echo          manualmente (mantendo sempre a estrutura Ano\Mês) ou voltar a usar esta opção se forem muitas.
echo.
echo ► [2] ATUALIZAR / CRIAR ÁLBUM
echo        - Esta opção cria ou updates o "Ver album.html" com as fotos previamente organizadas
echo          dentro da pasta "Album\Fotos".
echo        - Caso não exista configuração (primeira utilização), será pedido ao utilizador que
echo          responda a duas perguntas para criar automaticamente o álbum.
echo        - Depois da primeira utilização, sempre que adicionar mais fotos em Album\Fotos,
echo          deve correr novamente esta opção para que o LOCALBUM detete as novas fotos e atualize
echo          o ficheiro "Ver album.html". Por isso, esta opção faz as duas funções (Atualizar e Criar).
echo.
echo ► [3] REPOR / RESETAR O ÁLBUM
echo        - Apaga os ficheiros HTML antigos e a configuração criada pela opção [2].
echo          Esta opção NÃO apaga as tuas fotos nem vídeos da pasta "Album\Fotos".
echo          Serve apenas para repor o LOCALBUM ao estado original, como se fosse novo.
echo          Depois, basta voltar a correr a opção [2] para criar tudo novamente.
echo.
echo ► [4] FAZER CÓPIA DE SEGURANÇA (BACKUP)
echo        - Cria uma cópia de segurança idêntica e incremental de todo o teu álbum (incluindo fotos,
echo          miniaturas, configurações e a página do site HTML) para outro disco ou pen USB.
echo          Como usa o modo não-destrutivo (/E), o Robocopy apenas adiciona os ficheiros novos ou
echo          atualizados e NUNCA apaga nada na pasta de destino escolhida.
echo.
echo ► [i] INFORMAÇÕES / AJUDA
echo        - Mostra esta explicação. Tudo é offline — nada é enviado/recebido da Internet.
echo.
echo =====================================================
echo NOTA:
echo O ficheiro "Ver album.html" (ou "View album.html" in English) é criado na pasta
echo diretamente acima da pasta "Album".
echo =====================================================
echo.
echo Prima qualquer tecla para voltar ao menu...
pause >nul
goto MENU_PT


:INFO_EN
echo =====================================================
echo 📘 INFORMATION / HELP - LOCALBUM
echo =====================================================
echo Version 2025.11 — Ruben Silva
echo =====================================================
echo.
echo LOCALBUM automatically organizes your photos by year and month and creates an offline HTML album
echo that can be opened/viewed on PCs, Smart TVs (with a compatible browser), or macOS/Linux systems.
echo.
echo ================== EXPLANATION OF EACH OPTION ==================
echo.
echo ► [1] AUTO-ORGANIZE PHOTOS
echo        - Choose the folder containing your photos (they can also be inside subfolders) and set
echo          "Album\Fotos" as the destination so that LOCALBUM can access and display them.
echo        - It automatically creates subfolders by YEAR and MONTH.
echo        - If it finds identical files (same name and size), they are ignored.
echo        - This tool first detects each photo’s date from its filename if possible; otherwise,
echo          it uses the date when the photo was actually taken (from file metadata).
echo          The latter method may take a bit longer, but LOCALBUM handles this automatically.
echo        - Later, if you add more photos to "Album\Fotos", you can do it manually (keeping the
echo          correct Year\Month folder structure) or rerun this tool again if there are many.
echo.
echo ► [2] UPDATE / CREATE ALBUM
echo        - This option creates or updates the "View album.html" file using all the photos
echo          organized inside the "Album\Fotos" folder.
echo        - If no configuration exists (first-time use), it will ask you two quick questions
echo          to automatically generate your personalized album.
echo        - After the first creation, whenever you add more photos to Album\Fotos, you must
echo          run this option again so LOCALBUM detects the new photos and updates the album.
echo          That’s why this option performs both functions (Create + Update).
echo.
echo ► [3] RESET ALBUM
echo        - Deletes old HTML files and configuration created by option [2].
echo          It does NOT delete your photos or videos in "Album\Fotos".
echo          This simply resets LOCALBUM to its original state, as if it was never used.
echo          After using this option, run [2] again to re-enter your information.
echo.
echo ► [4] CREATE BACKUP (INCREMENTAL)
echo        - Generates an exact, incremental safety copy of your ENTIRE album structure (including
echo          photos, thumbnails, configurations, and the generated HTML website) to an external drive.
echo          Since it operates in cumulative mode, it only adds newly discovered or updated
echo          files and will NEVER delete preexisting data within your chosen target directory.
echo.
echo ► [i] INFORMATION / HELP
echo        - Displays this explanation window.
echo          Everything runs 100%% offline — nothing is sent to or received from the Internet.
echo =====================================================
echo NOTE:
echo The generated album file "View album.html" (or "Ver album.html" in Portuguese)
echo is created in the folder directly above the "Album" folder.
echo =====================================================
echo.
echo Press any key to return to the menu...
pause >nul
goto MENU_EN


:: =====================================================
::  ORGANIZE PHOTOS
:: =====================================================
:ORGANIZE
cls
if "%LANG%"=="pt" (
    echo [INFO] A iniciar o organizador de fotos...
) else (
    echo [INFO] Starting photo organizer...
)
echo.
if not exist "%ROOT%\z3.ps1" (
    echo [ERRO] Ficheiro z3.ps1 nao encontrado!
    pause
    if "%LANG%"=="pt" (goto MENU_PT) else (goto MENU_EN)
)
"%PWSH%" -ExecutionPolicy Bypass -NoProfile -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '%ROOT%\z3.ps1' -lang '%LANG%'"
if "%LANG%"=="pt" (goto MENU_PT) else (goto MENU_EN)


:: =====================================================
::  GENERATE / UPDATE ALBUM
:: =====================================================
:GENERATE
cls
echo [INFO] A gerar / atualizar o album...
echo.
if not exist "%ROOT%\z1.ps1" (
    echo [ERRO] Ficheiro z1.ps1 nao encontrado!
    pause
    if "%LANG%"=="pt" (goto MENU_PT) else (goto MENU_EN)
)

if "%LANG%"=="pt" (
    echo Como queres atualizar o album?
    echo.
    echo [A] Atualizacao Rapida    - usa o cache de pastas ^(opcao recomendada se usaste sempre a opcao [1]^)
    echo [B] Atualizacao completa  - volta a fazer scan a tudo ^(uso manual no Explorer^)
    echo.
) else (
    echo How do you want to update the album?
    echo.
    echo [A] Quick update - uses folder cache ^(recommended if you always used option [1]^)
    echo [B] Full update  - rescans everything ^(use if you added photos manually^)
    echo.
)

set /p UPDATE_MODE="[A/B]: "

if /i "!UPDATE_MODE!"=="B" (
    if exist "%ROOT%\Fotos" (
        for /r "%ROOT%\Fotos" %%F in (_frozen.flag) do (
            if exist "%%F" (
                attrib -h -s "%%F" >nul 2>&1
                del /f /q "%%F" >nul 2>&1
            )
        )
    )
    if "!LANG!"=="pt" (
        echo [INFO] Cache de pastas limpo. A fazer scan completo...
    ) else (
        echo [INFO] Folder cache cleared. Running full scan...
    )
)

"%PWSH%" -ExecutionPolicy Bypass -NoProfile -File "%ROOT%\z1.ps1"
if "%LANG%"=="pt" (goto MENU_PT) else (goto MENU_EN)


:: =====================================================
::  RESET / REINICIAR
:: =====================================================
:RESET
cls
if "%LANG%"=="pt" (
    echo [INFO] A repor o álbum LOCALBUM...
    echo Este processo irá apagar o ficheiro de configuração e os ficheiros HTML.
    echo As tuas fotos em "Album/Fotos" NÃO serão apagadas.
    echo.
    choice /c SN /m "Queres continuar?"
    if errorlevel 2 (echo Operacao cancelada.&timeout /t 2 >nul&goto MENU_PT)

    attrib -h -s "%INI%" >nul 2>&1
    del /f /q "%INI%" >nul 2>&1

    del /f /q "%ROOT%\..\Ver album.html" >nul 2>&1
    del /f /q "%ROOT%\..\View album.html" >nul 2>&1

    if exist "%ROOT%\localbum-cache.json" (
        attrib -h -s "%ROOT%\localbum-cache.json" >nul 2>&1
        del /f /q "%ROOT%\localbum-cache.json" >nul 2>&1
    )

    if exist "%ROOT%\Thumbnails\" (
        attrib -h -s "%ROOT%\Thumbnails" >nul 2>&1
        rmdir /s /q "%ROOT%\Thumbnails" >nul 2>&1
    )

    if exist "%ROOT%\Fotos" (
        for /r "%ROOT%\Fotos" %%F in (_frozen.flag _cache_mes.json) do (
            if exist "%%F" del /f /q "%%F" >nul 2>&1
        )
    )

    echo [OK] Reset concluido com sucesso!
    pause
    goto MENU_PT

) else (

    echo [INFO] Resetting LOCALBUM...
    echo This will delete configuration and HTML files.
    echo Your photos in "Album/Fotos" will remain untouched.
    echo.
    choice /c YN /m "Do you want to continue?"
    if errorlevel 2 (echo Operation cancelled.&timeout /t 2 >nul&goto MENU_EN)

    attrib -h -s "%INI%" >nul 2>&1
    del /f /q "%INI%" >nul 2>&1

    del /f /q "%ROOT%\..\Ver album.html" >nul 2>&1
    del /f /q "%ROOT%\..\View album.html" >nul 2>&1

    if exist "%ROOT%\localbum-cache.json" (
        attrib -h -s "%ROOT%\localbum-cache.json" >nul 2>&1
        del /f /q "%ROOT%\localbum-cache.json" >nul 2>&1
    )

    if exist "%ROOT%\Thumbnails\" (
        attrib -h -s "%ROOT%\Thumbnails" >nul 2>&1
        rmdir /s /q "%ROOT%\Thumbnails" >nul 2>&1
    )

    if exist "%ROOT%\Fotos" (
        for /r "%ROOT%\Fotos" %%F in (_frozen.flag _cache_mes.json) do (
            if exist "%%F" del /f /q "%%F" >nul 2>&1
        )
    )

    echo [OK] Reset completed successfully!
    pause
    goto MENU_EN
)


:: =====================================================
::  BACKUP / CÓPIA DE SEGURANÇA
:: =====================================================
:BACKUP
cls
if "%LANG%"=="pt" (
    echo =====================================================
    echo        LOCALBUM - Cópia de Segurança [Backup]
    echo =====================================================
    echo.
    echo Esta opção faz uma cópia incremental de TODO o teu álbum
    echo [fotos, miniaturas, configurações e site HTML].
    echo Usa o modo cumulativo /E, ou seja, nunca apaga nada no destino.
    echo.
    echo [INFO] A abrir a janela de seleção de pasta...
    set "MSG_EXPLORER=Escolha a pasta de destino para o Backup do LOCALBUM:"
) else (
    echo =====================================================
    echo        LOCALBUM - Incremental Backup
    echo =====================================================
    echo.
    echo This option creates an incremental copy of your ENTIRE album
    echo [photos, thumbnails, configs, and HTML files].
    echo Uses cumulative mode /E, meaning it never deletes anything in the destination.
    echo.
    echo [INFO] Opening folder selection window...
    set "MSG_EXPLORER=Select the destination folder for the LOCALBUM Backup:"
)

:: Janela de seleção gráfica nativa via PowerShell (Ficheiro temporário isola parênteses do CMD)
set "BACKUP_DEST="
set "TEMP_TXT=%TEMP%\localbum_backup_dir.txt"
if exist "%TEMP_TXT%" del /f /q "%TEMP_TXT%" >nul 2>&1

"%PWSH%" -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = '%MSG_EXPLORER%'; $f.ShowNewFolderButton = $true; if($f.ShowDialog() -eq 'OK'){ $f.SelectedPath }" > "%TEMP_TXT%"

if exist "%TEMP_TXT%" (
    set /p BACKUP_DEST=<"%TEMP_TXT%"
    del /f /q "%TEMP_TXT%" >nul 2>&1
)

if "%BACKUP_DEST%"=="" (
    if "%LANG%"=="pt" (echo Operação cancelada pelo utilizador.&timeout /t 2 >nul&goto MENU_PT) else (echo Operation cancelled by user.&timeout /t 2 >nul&goto MENU_EN)
)

:: Limpar aspas e normalizar caminhos absolutos
set "BACKUP_DEST=%BACKUP_DEST:"=%"
for %%A in ("%SOURCE_DIR%") do set "SRC=%%~fA"
for %%A in ("%BACKUP_DEST%") do set "DST=%%~fA"

:: VALIDAÇÃO 1: Bloquear Destino igual à Origem
if /I "%SRC%"=="%DST%" (
    echo.
    if "%LANG%"=="pt" (echo ERRO: O destino não pode ser a própria pasta do LOCALBUM.) else (echo ERROR: The destination cannot be the LOCALBUM folder itself.)
    echo.
    pause
    if "%LANG%"=="pt" (goto MENU_PT) else (goto MENU_EN)
)

:: VALIDAÇÃO 2: Bloquear Destino DENTRO da Origem (evita loops infinitos)
echo "%DST%" | find /I "%SRC%" >nul
if not errorlevel 1 (
    echo.
    if "%LANG%"=="pt" (echo ERRO: O destino não pode estar dentro da pasta do LOCALBUM.) else (echo ERROR: The destination cannot be inside the LOCALBUM folder.)
    echo.
    pause
    if "%LANG%"=="pt" (goto MENU_PT) else (goto MENU_EN)
)

:: Ecrã de Confirmação interativo
cls
echo ==========================================
if "%LANG%"=="pt" (
    echo              CONFIRMAR BACKUP
    echo ==========================================
    echo Origem:  %SRC%
    echo Destino: %DST%
    echo ==========================================
    echo.
    choice /M "Pretende iniciar o backup"
    if errorlevel 2 goto MENU_PT
    echo.
    echo A copiar ficheiros de forma segura...
) else (
    echo              CONFIRM BACKUP
    echo ==========================================
    echo Source:      %SRC%
    echo Destination: %DST%
    echo ==========================================
    echo.
    choice /M "Do you want to start the backup"
    if errorlevel 2 goto MENU_EN
    echo.
    echo Copying files safely...
)
echo.

:: Execução do Robocopy em modo /E (Seguro e Incremental) e filtragem de lixo do sistema
robocopy "%SRC%" "%DST%" /E /R:1 /W:1 /FFT /XJD /XF Thumbs.db desktop.ini
set "RC=%ERRORLEVEL%"

echo.
:: Validação real do resultado obtido pelo Robocopy (Códigos >= 8 são erros fatais)
if %RC% GEQ 8 (
    if "%LANG%"=="pt" (echo [ERRO] O backup falhou ou terminou com erros graves!) else (echo [ERROR] The backup failed or finished with critical errors!)
) else (
    if "%LANG%"=="pt" (echo [OK] Cópia de segurança concluída com sucesso!) else (echo [OK] Backup completed successfully!)
)

echo.
pause
if "%LANG%"=="pt" (goto MENU_PT) else (goto MENU_EN)
