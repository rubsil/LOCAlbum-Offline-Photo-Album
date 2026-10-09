# 📸 LOCAlbum – Offline Photo Album  
### 🚀 v1.6 — Smart Update + Safe Backup Edition

[![LOCAlbum Logo](https://i.imgur.com/2r820LY.png)](https://i.imgur.com/2r820LY.png)

---

## 🆕 Novidades da versão 1.6 / What's new in v1.6

🇵🇹
- ⚡ **Atualização rápida inteligente** — a opção **[2] → [A]** deteta sozinha as pastas que mudaram (fotos novas, apagadas ou renomeadas, mesmo à mão no Explorador) e só analisa essas. A **[B]** fica só para quando algo parecer errado.
- 💾 **Backup mais seguro** — cria sempre uma pasta `LOCAlbum-Backup` no destino; copia **todas** as fotos (incluindo as sem data); compara ficheiro a ficheiro; avisa se não houver espaço, se o destino for FAT32 e houver vídeos com mais de 4 GB, e mostra no resumo os ficheiros que **não** foram copiados.
- 🗂️ **Organizador** — já não cria cópias `_DUP` repetidas quando se corre várias vezes sobre a mesma origem; mostra a percentagem de progresso.
- 🖼️ **Fotos** — HEIC (iPhone) convertidas automaticamente para JPG (para abrirem no Chrome/Firefox); WebP suportado; miniaturas rodadas corretamente; vídeos das Live Photos com miniatura própria.
- 📱 **Álbum** — deslizar o dedo para mudar de foto (telemóvel/tablet); ficheiros com `#` no nome abrem; vídeos que o navegador não consegue reproduzir são saltados na apresentação.
- 🛡️ Ficheiros técnicos ocultos apenas como "oculto" (sem atributo de sistema, para evitar falsos alarmes de antivírus).

🇬🇧
- ⚡ **Smart quick update** — option **[2] → [A]** detects changed folders by itself (new, deleted or renamed photos, even when changed by hand in Explorer) and only analyses those. **[B]** is only needed if something looks wrong.
- 💾 **Safer backup** — always uses a `LOCAlbum-Backup` folder at the destination; copies **all** photos (including undated ones); compares file by file; warns about low free space and about videos over 4 GB on FAT32 drives, and lists in the summary any files that were **not** copied.
- 🗂️ **Organizer** — no longer creates repeated `_DUP` copies when run several times on the same source; shows progress percentage.
- 🖼️ **Photos** — HEIC (iPhone) automatically converted to JPG (so they open in Chrome/Firefox); WebP supported; thumbnails correctly rotated; Live Photo videos get their own thumbnail.
- 📱 **Album** — swipe to change photo (phone/tablet); files with `#` in the name open; videos the browser cannot play are skipped in the slideshow.
- 🛡️ Technical files are hidden only as "hidden" (no system attribute, to avoid antivirus false alarms).

---

# 🇵🇹 Apresentação

**LOCAlbum** é uma aplicação leve e totalmente offline que transforma as tuas pastas de fotos num álbum moderno, rápido e organizado por **anos e meses**, com suporte nativo a **fotos e vídeos**, slideshow, temas e cálculo opcional de idade.

Ideal para pais que querem registar as memórias dos filhos desde o nascimento.

---

# 🇬🇧 Overview

**LOCAlbum** is a lightweight and completely offline application that converts your photo folders into a modern, fast, and interactive album organized by **year and month**, supporting photos and videos, themes, slideshow, and optional age calculation.

Perfect for parents capturing their children's growth and memories.
---

## ✨ Highlights / Destaques

| 🇬🇧 **Highlights** | 🇵🇹 **Destaques** |
|--------------------|-------------------|
| 🗂️ Automatic organization by **year and month** | 🗂️ Organização automática por **ano e mês** |
| 🖼️ Support for **photos and videos** | 🖼️ Suporte para **fotos e vídeos** |
| ⏱️ **Automatic slideshow** with adjustable speed | ⏱️ **Slideshow automático** com velocidade ajustável |
| 👶 Optional **age display** based on birthdate | 👶 Cálculo de idade opcional (a partir da data de nascimento) |
| 💾 Works **completely offline** — no internet needed | 💾 Funciona **totalmente offline** — nada é enviado para a internet |
| 🔄 Unified in one tool: **LOCALBUM - Manager.bat** | 🔄 Tudo num único ficheiro: **LOCALBUM - Manager.bat** |
| 🌍 **Bilingual interface (PT/EN)** | 🌍 Interface **bilingue (PT/EN)** |

---

## 🚀 Como usar / How to use

🇵🇹 **Passos**

1. 📦 **Descarrega o projeto completo** através do botão verde **“Code → Download ZIP”** no topo da página e extrai-o **para a raiz de um disco ou pen USB**  
   _(ex.: `C:\Album\` ou `E:\Album\`)_.  
   > ⚠️ **Importante:** recomenda-se a raiz do disco. Funciona noutras pastas, **desde que o caminho não tenha `[` `]` nem `!`** (o Windows PowerShell não consegue correr scripts a partir daí — o Manager avisa se for o caso).

2. ▶️ **Executa o ficheiro** `LOCALBUM - Manager.bat`.  
   - Este é agora o **único ficheiro necessário**: todas as funções estão reunidas aqui.  
   - Ao abrir, escolhe o idioma (**Português / English**).  
   - O menu principal mostra cinco opções:
     ```
     [1] Organizar fotos automaticamente
     [2] Atualizar / Criar álbum (HTML)
     [3] Repor / Resetar o álbum
     [4] Fazer Cópia de Segurança
     [i] Informações / Ajuda
     [0] Sair
     ```
     > 💡 A opção `[i]` mostra explicações detalhadas sobre cada função.

3. 📁 **Organiza e cria o teu álbum:**

- **[1]** organiza automaticamente milhares de fotos por pastas **Ano/Mês** (sem duplicados).  
- **[2]** cria ou atualiza o álbum HTML (`Ver album.html` / `View album.html`).  
  > 🔍 *Nota:* Se existirem muitas fotos, este processo pode demorar um pouco na primeira execução devido à criação das thumbnails.  
  > ⚡ A partir da segunda execução será quase instantâneo graças ao sistema de **pastas congeladas** — só processa pastas que mudaram.  
  > Ao correr escolhes **[A] Rápida** (deteta sozinha o que mudou — usa sempre esta) ou **[B] Completa** (volta a analisar tudo — só se algo parecer errado).
- **[3]** repõe o projeto ao estado original, **sem apagar as tuas fotos**.  
- **[4]** faz uma cópia de segurança incremental de **todas as tuas fotos e vídeos** (incluindo as sem data) para uma pasta `LOCAlbum-Backup` no destino escolhido — recomendada para o disco externo/pen USB seguirem a regra 3-2-1. As miniaturas e o HTML não são copiados: recriam-se com a opção [2]. O backup nunca apaga nada no destino.  
- **[i]** mostra ajuda e instruções.

4. 💾 O ficheiro `Ver album.html` será criado automaticamente **ao lado da pasta `Album/`.**

5. 🌐 **Abre o ficheiro** `Ver album.html` (ou `View album.html`) **no navegador**  
   _(Chrome, Edge, Firefox, etc.)_.

6. 🎨 **Escolhe o tema**, vê as fotos e guarda as tuas preferências.

---

🇬🇧 **Steps**

1. 📦 **Download the full project** using the green **“Code → Download ZIP”** button at the top of this page and extract it **to the root of a drive or USB stick**  
   _(e.g., `C:\Album\` or `E:\Album\`)_.  
   > ⚠️ **Important:** the drive root is recommended. Other folders work too, **as long as the path has no `[` `]` or `!`** (Windows PowerShell cannot run scripts from there — the Manager warns you if so).

2. ▶️ **Run the file** `LOCALBUM - Manager.bat`.  
   - This is now the **only file you need** — all functions are unified here.  
   - When it opens, choose your language (**Portuguese / English**).  
   - The main menu offers five options:
     ```
     [1] Auto-organize photos
     [2] Update / Create album (HTML)
     [3] Reset album
     [4] Create Backup (Incremental)
     [i] Information / Help
     [0] Exit
     ```
     > 💡 Option `[i]` displays detailed explanations about each feature.

3. 📁 **Organize and generate your album:**

- **[1]** automatically sorts thousands of photos into **Year/Month** folders (no duplicates).  
- **[2]** creates or updates the HTML album (`View album.html` / `Ver album.html`).  
  > 🔍 *Note:* If you have many photos, the first run may take a while because thumbnails must be created.  
  > ⚡ From the second run onwards, updates are nearly instant thanks to the **frozen folders** system — only folders that changed are rescanned.  
  > When you run it you choose **[A] Quick** (detects what changed by itself — always use this one) or **[B] Full** (analyses everything again — only if something looks wrong).
- **[3]** resets the project to its original state, **without deleting your photos**.  
- **[4]** creates an incremental backup of **all your photos and videos** (including undated ones) into a `LOCAlbum-Backup` folder at the destination you choose — recommended for your external drive/USB stick as part of a 3-2-1 strategy. Thumbnails and the HTML are not copied: option [2] recreates them. The backup never deletes anything at the destination.  
- **[i]** displays help and instructions.

4. 💾 The file `View album.html` will be automatically created **next to the `Album/` folder.**

5. 🌐 **Open the file** `View album.html` (or `Ver album.html`) **in your browser**  
   _(Chrome, Edge, Firefox, etc.)_.

6. 🎨 **Pick your favorite theme**, browse your photos, and enjoy your offline album.

---

## 📁 Estrutura de Pastas / Folder Structure
```
X:
└── Album
      ├── Fotos
            ├── 2023
            ├── Janeiro
                   ├── _frozen.flag    (oculto / hidden — criado automaticamente)
                   └── _cache_mes.json (oculto / hidden — criado automaticamente)
      ├── Thumbnails (oculto / hidden) ← (criado automaticamente / automatically created)
      ├── Converted (oculto / hidden) ← cópias JPG das fotos HEIC / JPG copies of HEIC photos
      ├── config.ini (oculto / hidden)
      ├── exiftool.exe + exiftool_files (ocultos / hidden)
      ├── ffmpeg.exe (oculto / hidden)
      ├── localbum-cache.json (oculto / hidden)
      ├── LOCALBUM - Manager.bat ← (ficheiro principal / main file)
      ├── ajuda_album.png (oculto / hidden) 
      ├── favicon.png (oculto / hidden)
      ├── template.html (oculto / hidden)
      ├── z1.ps1, z3.ps1, z-backup.ps1 (ocultos / hidden)
└── Ver album.html / View album.html
```
🪄 **🇵🇹 Após a primeira execução**, os ficheiros técnicos são **ocultados automaticamente**,  
restando apenas o **`LOCALBUM - Manager.bat`** visível — simples, limpo e pronto a usar.  

🪄 **🇬🇧 After the first run**, all technical files are **automatically hidden**,  
leaving only the **`LOCALBUM - Manager.bat`** visible — clean, simple, and ready to use.

---

## 🛠️ Ferramentas Auxiliares / Helper Tools

### 🇵🇹 Português
* **`exiftool.exe` (Incluído)** — Utilitário desenvolvido por Phil Harvey. Serve para melhorar e otimizar a leitura de metadados e datas cronológicas em formatos menos comuns.
* **`FFmpeg.exe` (Incluído)** — Utilitário essencial utilizado em pano de fundo pelo sistema para o processamento rápido e a geração automática de miniaturas (*thumbnails*) do teu álbum.

### 🇬🇧 English
* **`exiftool.exe` (Included)** — Utility developed by Phil Harvey. It improves and optimizes date and metadata reading for less common media formats.
* **`FFmpeg.exe` (Included)** — Essential core utility used under the hood for processing and automatically generating the album *thumbnails*. 

---

## 🧠 Dicas e Cuidados / Tips & Notes

### 🇵🇹 **Português**

- 📁 A **pasta principal** é aquela onde estão todos os ficheiros do LOCAlbum — por exemplo:
```
X:
└── Album
      ├── Fotos
            ├── 2023
            ├── Janeiro
                   ├── _frozen.flag    (oculto / hidden — criado automaticamente)
                   └── _cache_mes.json (oculto / hidden — criado automaticamente)
      ├── Thumbnails (oculto / hidden) ← (criado automaticamente / automatically created)
      ├── Converted (oculto / hidden) ← cópias JPG das fotos HEIC / JPG copies of HEIC photos
      ├── config.ini (oculto / hidden)
      ├── exiftool.exe + exiftool_files (ocultos / hidden)
      ├── ffmpeg.exe (oculto / hidden)
      ├── localbum-cache.json (oculto / hidden)
      ├── LOCALBUM - Manager.bat ← (ficheiro principal / main file)
      ├── ajuda_album.png (oculto / hidden) 
      ├── favicon.png (oculto / hidden)
      ├── template.html (oculto / hidden)
      ├── z1.ps1, z3.ps1, z-backup.ps1 (ocultos / hidden)
└── Ver album.html / View album.html
```
## 🇵🇹 Português
- Não alteres nem renomes:
  - a pasta `Fotos/`
  - `template.html`
  - `config.ini`
  - `z1.ps1`, `z3.ps1` e `z-backup.ps1`

- Funciona em:
  - Windows (total suporte)
  - macOS / Linux (visualização do HTML)
  - TVs / Tablets (qualquer navegador)

---

## 🇬🇧 English
- Do not rename:
  - the `Fotos/` folder
  - `template.html`
  - `config.ini`
  - `z1.ps1`, `z3.ps1`, `z-backup.ps1`

- Works on:
  - Windows (full support)
  - macOS / Linux (HTML viewing)
  - Smart TVs and tablets

---

- ⚙️ O ficheiro `config.ini` é criado automaticamente e deve permanecer oculto.  
- 💾 Podes copiar o projeto completo (pasta `Album`) para uma **pen USB** ou **disco externo** —  
  funciona em qualquer PC com **Windows**, e também em **Smart TVs / macOS / Linux**.  
- 🌐 O álbum funciona **totalmente offline**, mas o navegador deve permitir abrir ficheiros locais (`file://`).

---

### 🇬🇧 **English**

- 📁 The **main folder** is the one containing all LOCAlbum files — for example:
```
X:
└── Album
      ├── Fotos
            ├── 2023
            ├── Janeiro
                   ├── _frozen.flag    (oculto / hidden — criado automaticamente)
                   └── _cache_mes.json (oculto / hidden — criado automaticamente)
      ├── Thumbnails (oculto / hidden) ← (criado automaticamente / automatically created)
      ├── Converted (oculto / hidden) ← cópias JPG das fotos HEIC / JPG copies of HEIC photos
      ├── config.ini (oculto / hidden)
      ├── exiftool.exe + exiftool_files (ocultos / hidden)
      ├── ffmpeg.exe (oculto / hidden)
      ├── localbum-cache.json (oculto / hidden)
      ├── LOCALBUM - Manager.bat ← (ficheiro principal / main file)
      ├── ajuda_album.png (oculto / hidden) 
      ├── favicon.png (oculto / hidden)
      ├── template.html (oculto / hidden)
      ├── z1.ps1, z3.ps1, z-backup.ps1 (ocultos / hidden)
└── Ver album.html / View album.html
```
- 🚫 **Do not rename or move** the following folders/files:
  - `Fotos/`
  - `template.html`
  - `config.ini`
  - `z1.ps1`, `z3.ps1`, `z-backup.ps1`

- ⚙️ The `config.ini` file is generated automatically and should remain hidden.  
- 💾 You can copy the whole project (the `Album` folder) to a **USB stick** or **external drive** —  
  it works on any **Windows PC**, and also on **Smart TVs / macOS / Linux**.  
- 🌐 The album works **entirely offline**, but your browser must allow opening local files (`file://`).

---

## 📺 Compatibilidade com Smart TVs / Smart TV Compatibility

### 🇵🇹 Português

Atenção: **a maioria das Smart TVs não consegue abrir ficheiros HTML diretamente de uma pen/disco USB**.  
Isto não é uma limitação do LOCALBUM — é algo comum nas apps de navegador das TVs, que normalmente bloqueiam:

- ficheiros locais (`file://`)
- JavaScript local
- acesso a imagens/vídeos via HTML quando está offline
- caminhos do dispositivo USB dentro do navegador

Por esse motivo, o ficheiro **Ver album.html / View album.html pode não funcionar na TV**.

### ✔️ Mas o álbum continua totalmente utilizável na TV

Mesmo que a versão HTML não abra, **todas as TVs conseguem navegar pelas fotos na pasta organizada pelo LOCALBUM**:

```
Album
 └── Fotos
       ├── 2023
       │     ├── Janeiro
       │     ├── Fevereiro
       │     └── ...
       ├── 2024
       │     ├── Março
       │     ├── Julho
       │     └── ...
       └── ...
```

O LOCALBUM cria automaticamente uma estrutura **Ano → Mês**, compatível com:

- Smart TVs (Samsung, LG, Sony, TCL, Philips…)
- Android TV / Google TV
- Fire Stick
- Boxes Android
- Consolas
- Media players USB

### 📌 O que a Smart TV consegue fazer

- Abrir fotos diretamente da pen/disco  
- Navegar por Ano → Mês → Foto  
- Criar slideshow nativo da TV  
- Reproduzir vídeos (MP4/MOV) diretamente das pastas  
- Funciona 100% offline, sem browser

### 📌 Conclusão

Mesmo que a tua TV não suporte o HTML, **podes sempre usar a pasta `Album/Fotos` como uma versão “TV-ready”**, totalmente compatível com qualquer dispositivo.

---

### 🇬🇧 English

Note: **most Smart TVs cannot open HTML files directly from a USB drive**.  
This is not a limitation of LOCALBUM but of TV web browsers, which usually block:

- local `file://` access  
- local JavaScript  
- loading images/videos from HTML pages offline  
- USB drive paths inside the browser

As a result, **View album.html / Ver album.html may NOT work on a Smart TV**.

### ✔️ But the album is still fully usable on any Smart TV

Even if the HTML viewer doesn’t work, **all TVs can browse the photo folder structure created by LOCALBUM**:

```
Album
 └── Fotos
       ├── 2023
       │     ├── January
       │     ├── February
       │     └── ...
       ├── 2024
       │     ├── March
       │     ├── July
       │     └── ...
       └── ...
```

LOCALBUM automatically organizes photos/videos into **Year → Month**, which is supported by:

- Smart TVs (Samsung, LG, Sony, TCL, Philips…)  
- Android TV / Google TV  
- Fire Stick  
- Android media boxes  
- Game consoles  
- Any USB media player  

### 📌 What the Smart TV CAN do

- Open the USB drive and enter the `Album/Fotos` folder  
- Browse Year → Month → Photo  
- Display photos in a slideshow  
- Play videos (MP4/MOV) natively  
- No browser or internet required  

### 📌 Summary

Even if your TV cannot open HTML, **LOCALBUM always provides a TV-friendly version** through the `Album/Fotos` folder structure, ensuring full compatibility everywhere.

---

## 🖼️ Screenshots / Capturas de ecrã

**Álbum — primeiros dias de vida / Album — first days of life**
![LOCAlbum screenshot 1](https://i.imgur.com/qOrwXz0.png)

**Álbum — navegação por ano e mês, separadores de dia, contador de idade / Album — year/month navigation, day separators, age counter**
![LOCAlbum screenshot 2](https://i.imgur.com/EQrIsDG.png)

**Pasta limpa + menu do Manager / Clean folder + Manager menu**
![LOCAlbum screenshot 3](https://i.imgur.com/KOpFnQl.png)

---

### ⚠️ Nota sobre Antivírus / Antivirus Notice

🇵🇹  
Alguns antivírus ou o Microsoft Defender podem **mostrar um aviso falso** ao abrir o ficheiro `LOCALBUM - Manager.bat`.  
Isto acontece porque o Windows reconhece scripts `.bat` como “automatizações do sistema”.  
🔒 **O LOCALBUM é 100% seguro** — não se liga à Internet, não altera o sistema e não contém código malicioso.  

> 💡 Podes verificar o conteúdo do ficheiro em qualquer editor de texto (como o Notepad) — é totalmente transparente e legível.  
> Nenhuma informação é enviada para fora do teu computador.

🇬🇧  
Some antivirus programs or Microsoft Defender may **show a false alert** when opening the `LOCALBUM - Manager.bat` file.  
This happens because Windows often flags `.bat` scripts as “system automation tools.”  
🔒 **LOCALBUM is 100% safe** — it runs fully offline, does not modify your system, and contains no malicious code.  

> 💡 You can open the file with any text editor (like Notepad) to check its contents — it’s completely transparent and human-readable.  
> No information is ever sent outside your computer.

---

## 💝 Apoia o projeto / Support the project

Se este projeto te foi útil, considera apoiar o desenvolvimento.  
If this project was useful to you, consider supporting its development.

<p align="center">
  <a href="https://www.buymeacoffee.com/rubsil" target="_blank">
    <img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black&style=for-the-badge" />
  </a>
  <a href="https://www.paypal.me/rubsil" target="_blank">
    <img src="https://img.shields.io/badge/Donate%20via%20PayPal-0070ba?logo=paypal&logoColor=white&style=for-the-badge" />
  </a>
</p>

---

## 🧑‍💻 Autor / Author

**Desenvolvido por Rúben Silva**  
📧 [GitHub Profile](https://github.com/rubsil)  
📸 Projeto: *LOCAlbum - Offline Photo Album*  

💡 *Because your memories deserve a place — even without internet.*

---

## 📜 Licença / License

Distribuído sob a **licença MIT** — uso livre, com crédito ao autor.  
Distributed under the **MIT License** — free to use, with author attribution.

### ⚖️ Softwares de Terceiros / Third-Party Software

🇵🇹 O **LOCAlbum** depende de excelentes ferramentas de código aberto desenvolvidas pela comunidade. Este projeto inclui e distribui ou suporta os seguintes utilitários sob as suas respetivas licenças originais:

* **ExifTool** (por Phil Harvey) — Utilitário multiplataforma de leitura e escrita de metadados. Disponível em: [exiftool.org](https://exiftool.org) (Licenciado sob os mesmos termos do Perl: Artistic License / GPL).
* **FFmpeg** — Solução completa e multiplataforma para processamento e gravação de áudio e vídeo. Disponível em: [ffmpeg.org](https://ffmpeg.org). O binário incluído é a build estática "essentials" [2026-06-26-git-d66e84695b](https://github.com/GyanD/codexffmpeg/releases/tag/2026-06-26-git-d66e84695b) da [gyan.dev](https://www.gyan.dev/ffmpeg/builds/), licenciada sob a **GNU General Public License v3 (GPLv3)** — não LGPL. Código-fonte correspondente a este build: [FFmpeg/FFmpeg@d66e84695b](https://github.com/FFmpeg/FFmpeg/commit/d66e84695b). O FFmpeg é invocado apenas como processo externo (não é ligado/linkado ao código do LOCAlbum), mas se fores redistribuir este projeto verifica as obrigações de disponibilização de código-fonte da GPLv3. *(Nota: isto não é aconselhamento jurídico — consulta um profissional se tiveres dúvidas sobre conformidade de licenças.)*

🇬🇧 **LOCAlbum** relies on excellent open-source tools developed by the community. This project includes, distributes, or supports the following utilities under their respective original licenses:

* **ExifTool** (by Phil Harvey) — A cross-platform utility for reading and writing metadata. Available at: [exiftool.org](https://exiftool.org) (Licensed under the same terms as Perl: Artistic License / GPL).
* **FFmpeg** — A complete, cross-platform solution to record, convert, and stream audio and video. Available at: [ffmpeg.org](https://ffmpeg.org). The bundled binary is the "essentials" static build [2026-06-26-git-d66e84695b](https://github.com/GyanD/codexffmpeg/releases/tag/2026-06-26-git-d66e84695b) from [gyan.dev](https://www.gyan.dev/ffmpeg/builds/), licensed under the **GNU General Public License v3 (GPLv3)** — not LGPL. Corresponding source for this build: [FFmpeg/FFmpeg@d66e84695b](https://github.com/FFmpeg/FFmpeg/commit/d66e84695b). FFmpeg is invoked only as an external process (not linked into LOCAlbum's own code), but if you redistribute this project, check the GPLv3 source-availability obligations. *(Note: this is not legal advice — consult a professional if you have licensing compliance questions.)*
