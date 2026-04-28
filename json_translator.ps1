<#
.SYNOPSIS
    JSON dosyalarındaki string değerleri hedef dile çevirir.

.DESCRIPTION
    Bu betik tek bir JSON dosyasını, bir klasördeki dosyaları veya glob deseniyle
    eşleşen okunabilir JSON dosyalarını işler. JSON içindeki string değerleri
    çeviri servisleriyle hedef dile çevirir ve çıktıyı belirtilen dosyaya veya
    klasöre yazar. JSON anahtar adları çevrilmez.

.PARAMETER InputDirectory
    Girdi dosyası, klasörü veya glob deseni. Varsayılan: .\*
    Klasör veya glob kullanıldığında yalnızca okunabilir JSON içerikleri işlenir.

.PARAMETER InputLanguage
    Kaynak dil kodu (örn: tr, en, de). Verilmezse basit otomatik tespit kullanılır.

.PARAMETER OutputDirectory
    Çıktı dosyası veya klasörü. Verilmezse InputDirectory değeri kullanılır.
    InputDirectory tek dosyaysa ve OutputDirectory sonunda \ veya / yoksa dosya yolu kabul edilir.
    InputDirectory çoklu dosya üretiyorsa OutputDirectory klasör kabul edilir ve dosya adları korunur.


.PARAMETER OutputLanguage
    Hedef dil kodu (örn: en, ru, de). Verilmezse sistem arayüz dilinin iki harfli kodu kullanılır.
    Sistem dili okunamazsa varsayılan olarak en kullanılır.

.PARAMETER Help
    Yardım metnini gösterir. Sadece -Help, -Help tr veya -Help en yazılırsa işlem yapılmaz.
    -Help işlem parametrelerinden önceyse yardım önce, işlem parametrelerinden sonraysa yardım
    işlemden sonra gösterilir.

EXAMPLE
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help tr -InputLanguage tr -OutputDirectory .\File_en.json -OutputLanguage en
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help tr -InputDirectory .\File.json -InputLanguage tr -OutputDirectory .\Triype_en.json -OutputLanguage en
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help tr -InputDirectory C:\* -OutputDirectory .\results\ -OutputLanguage en
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help tr
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\* -help tr -InputLanguage tr -OutputLanguage en
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputLanguage tr -OutputLanguage en -InputDirectory .\File.json -OutputDirectory .\File-en.json -help en
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -OutputLanguage en -InputDirectory .\File.json -help
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -OutputLanguage en -SkipOnError

#>
param(
    [string]$InputDirectory = ".\*",
    [string]$InputLanguage,
    [string]$OutputDirectory,
    [string]$OutputLanguage,
    [switch]$SkipOnError,
    [switch]$Help,
    [Parameter(Position=0)]
    [string]$HelpLanguage
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

function Show-Help {
        param([string]$lang)
        $supported = @{ 'tr' = 'Turkce'; 'en' = 'Ingilizce' }
        if ($lang -eq 'tr') {
                Write-Output @"
KULLANIM:
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 [seçenekler]

AMAÇ:
    JSON dosyalarındaki string değerleri hedef dile çevirir.
    JSON anahtar adları, sayılar, boolean değerler, null değerler ve yalnızca sayı/noktalama içeren
    metinler çevrilmez.

HIZLI BAŞLANGIÇ:
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\File.json -InputLanguage tr -OutputDirectory .\File_en.json -OutputLanguage en
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\* -InputLanguage tr -OutputDirectory .\results -OutputLanguage ru
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help tr

ÖRNEKLER:
    Tek dosyayı tek çıktı dosyasına çevir:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\File.json -InputLanguage tr -OutputDirectory .\File_en.json -OutputLanguage en

    Tek dosyayı bir klasöre, aynı dosya adıyla yaz:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\File.json -OutputDirectory .\translated\ -OutputLanguage en

    Bulunduğun klasördeki okunabilir JSON dosyalarını results klasörüne çevir:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\* -InputLanguage tr -OutputDirectory .\results -OutputLanguage ru

    Sadece yardım göster:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help tr
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help en

    Yardımı işlemden önce göster, sonra çevir:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help tr -InputDirectory .\File.json -OutputDirectory .\File_en.json -OutputLanguage en

    Yardımı işlemden sonra göster:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\File.json -OutputDirectory .\File_en.json -OutputLanguage en -help tr

Parametreler:
    -InputDirectory <yol|glob>
        Girdi dosyası, klasörü veya glob desenidir. Varsayılan: .\*
        Dosya yolu verilebilir: .\File.json
        Klasör verilebilir: .\json\
        Glob verilebilir: .\*.json veya .\*
        Klasör/glob kullanıldığında dosyalar okunur ve yalnızca geçerli JSON içerikleri işlenir.
        .json uzantısı yazılmadıysa aynı adda .json dosyası da denenir.

    -InputLanguage <dil>
        Kaynak dil kodudur. Örnek: tr, en, de, fr, ru, es, ja, zh
        Yazılmazsa betik içerikten basit otomatik dil tespiti yapmaya çalışır.
        Otomatik tespit hızlıdır; kesin dil kontrolü gereken işlerde bu parametreyi açıkça yazın.

    -OutputDirectory <yol>
        Çıktı dosyası veya çıktı klasörüdür. Yazılmazsa -InputDirectory değeri kullanılır.
        Tek dosya girişinde sonunda \ veya / yoksa dosya yolu kabul edilir:
            -InputDirectory .\File.json -OutputDirectory .\out
            Çıktı: .\out
        Tek dosya girişinde klasöre yazmak için sonda \ veya / kullanın:
            -InputDirectory .\File.json -OutputDirectory .\out\
            Çıktı: .\out\File.json
        Çoklu girişte her zaman klasör kabul edilir ve dosya adları değiştirilmez:
            -InputDirectory .\* -OutputDirectory .\results
            Çıktı: .\results\<girdi-dosya-adı>.json
        Betik alternatif ad üretmez; -ru, -en gibi ekler dosya adına otomatik eklenmez.

    -OutputLanguage <dil>
        Hedef dil kodudur. Örnek: en, tr, ru, de, fr, es, ja, zh
        Yazılmazsa sistem arayüz dilinin iki harfli kodu kullanılır.
        Sistem dili okunamazsa varsayılan hedef dil en olur.

    -SkipOnError
        Yazılmazsa herhangi bir string tüm sağlayıcılarda çevrilemezse betik hata verip durur.
        Yazılırsa çevrilemeyen stringler orijinal haliyle bırakılır ve işlem devam eder.
        Bu seçenek çıktı üretmeyi kolaylaştırır; ancak çevrilmemiş alan kalabileceğini unutmayın.

    -Help [tr|en]
        Yardımı gösterir. Dil yazılmazsa sistem diline göre tr veya en seçilir; desteklenmeyen sistem
        dillerinde en kullanılır. Sadece yardım parametresi yazılırsa işlem yapılmaz.

YARDIM PARAMETRESİNİN KONUMU:
    Sadece -help, -help tr veya -help en:
        Yalnızca yardım gösterilir, işlem yapılmaz.
    -help ilk işlem parametresinden önceyse:
        Önce yardım gösterilir, sonra işlem yapılır.
    -help işlem parametrelerinden sonra veya en sonda ise:
        Önce işlem yapılır, sonra yardım gösterilir.

ÇIKTI VE ÜZERİNE YAZMA KURALLARI:
    - Giriş ve çıktı yolu birebir aynıysa dosya yerinde çevrilir ve üzerine yazılır.
    - Yerinde çeviri yapmadan önce önemli dosyalarınızın yedeğini alın.
    - Tek dosya girişinde -OutputDirectory sonunda \ veya / yoksa değer dosya yolu kabul edilir.
    - Çoklu girişte -OutputDirectory klasör kabul edilir.
    - Çıktı klasörü yoksa oluşturulur.
    - Dil kodları aynı olsa bile çeviri akışı çalışır.

VARSAYILANLAR:
    -InputDirectory   .\*
    -OutputDirectory  -InputDirectory ile aynı değer
    -InputLanguage    otomatik tespit
    -OutputLanguage   sistem arayüz dili; okunamazsa en
    -SkipOnError      kapalı

İŞLEME MANTIĞI:
    1. Girdi yolu dosyalara çözülür.
    2. Dosyalar okunur ve geçerli JSON olup olmadıkları doğrulanır.
    3. JSON içindeki benzersiz string değerler toplanır.
    4. Metinler çeviri servislerine gönderilir.
    5. Başarılı çeviriler JSON içindeki string değerlerin yerine yazılır.
    6. Orijinal biçimlendirme büyük ölçüde korunarak çıktı dosyasına yazılır.

PERFORMANS:
    Benzersiz stringler önbelleğe alınır; aynı metin tekrar tekrar çevrilmez.
    Çeviri işleri paralel çalışır. Paralellik sayısını değiştirmek için ortam değişkeni kullanabilirsiniz:
        `$env:TRANSLATE_MAX_PARALLEL = '20'

Desteklenen Diller:
    Çeviri servislerinin desteklediği ISO dil kodları kullanılabilir.
    Örnekler: tr, en, de, fr, es, ru, it, ar, ja, ko, zh

Kullanılan Çeviri Hizmetleri:
    Google Translate (gtx)
    Lingva Translate
    SimplyTranslate
    MyMemory
    LibreTranslate

Notlar:
    - İnternet erişimi gerekir; servislerden biri başarısız olursa betik diğer sağlayıcıları dener.
    - Büyük JSON dosyalarında işlem süresi servis yanıtlarına bağlıdır.
    - Çeviri kalitesi kullanılan ücretsiz sağlayıcıların yanıtına bağlıdır; kritik içerikleri gözden geçirin.
"@
        } else {
                Write-Output @"
USAGE:
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 [options]

PURPOSE:
    Translates string values inside JSON files to a target language.
    JSON property names, numbers, booleans, null values, and strings that contain only numbers or
    punctuation are not translated.

QUICK START:
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\File.json -InputLanguage tr -OutputDirectory .\File_en.json -OutputLanguage en
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\* -InputLanguage tr -OutputDirectory .\results -OutputLanguage ru
    powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help en

EXAMPLES:
    Translate one file to one output file:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\File.json -InputLanguage tr -OutputDirectory .\File_en.json -OutputLanguage en

    Translate one file into a folder while preserving the input file name:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\File.json -OutputDirectory .\translated\ -OutputLanguage en

    Translate readable JSON files in the current folder into the results folder:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\* -InputLanguage tr -OutputDirectory .\results -OutputLanguage ru

    Show help only:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help tr
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help en

    Show help before processing, then translate:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -help en -InputDirectory .\File.json -OutputDirectory .\File_en.json -OutputLanguage en

    Show help after processing:
        powershell -ExecutionPolicy Bypass -File json_translator.ps1 -InputDirectory .\File.json -OutputDirectory .\File_en.json -OutputLanguage en -help en

PARAMETERS:
    -InputDirectory <path|glob>
        Input file, folder, or glob pattern. Default: .\*
        File path example: .\File.json
        Folder example: .\json\
        Glob examples: .\*.json or .\*
        For folders and globs, files are read and only valid JSON contents are processed.
        If a path does not end with .json, a same-named .json file is also tried.

    -InputLanguage <lang>
        Source language code. Examples: tr, en, de, fr, ru, es, ja, zh
        If omitted, the script attempts simple automatic language detection from the content.
        Auto-detection is lightweight; pass this parameter explicitly when source language matters.

    -OutputDirectory <path>
        Output file or output folder. If omitted, the -InputDirectory value is used.
        With a single input file, a value without trailing \ or / is treated as a file path:
            -InputDirectory .\File.json -OutputDirectory .\out
            Output: .\out
        To write a single input file into a folder, use trailing \ or /:
            -InputDirectory .\File.json -OutputDirectory .\out\
            Output: .\out\File.json
        With multiple inputs this is always treated as a folder and file names are preserved:
            -InputDirectory .\* -OutputDirectory .\results
            Output: .\results\<input-file-name>.json
        The script does not generate alternate file names; suffixes such as -ru or -en are not added automatically.

    -OutputLanguage <lang>
        Target language code. Examples: en, tr, ru, de, fr, es, ja, zh
        If omitted, the system UI language two-letter code is used.
        If the system language cannot be read, the fallback target language is en.

    -SkipOnError
        If omitted, the script stops when any string cannot be translated by all providers.
        If set, untranslated strings are kept in their original form and processing continues.
        This helps produce an output file, but some values may remain untranslated.

    -Help [tr|en]
        Shows this help text. If no language is passed, tr or en is selected from the system
        language; unsupported system languages fall back to en. If only help is requested, no
        processing is performed.

HELP POSITION:
    Only -help, -help tr, or -help en:
        Shows help only; no processing is performed.
    -help before the first processing parameter:
        Shows help first, then processes files.
    -help after processing parameters or at the end:
        Processes files first, then shows help.

OUTPUT AND OVERWRITE RULES:
    - If input and output paths are identical, the file is translated in place and overwritten.
    - Back up important files before running in-place translation.
    - With a single input file, -OutputDirectory without trailing \ or / is treated as a file path.
    - With multiple inputs, -OutputDirectory is treated as a folder.
    - Missing output folders are created automatically.
    - Translation runs even when source and target language codes are the same.

DEFAULTS:
    -InputDirectory   .\*
    -OutputDirectory  same value as -InputDirectory
    -InputLanguage    automatic detection
    -OutputLanguage   system UI language; fallback en
    -SkipOnError      off

PROCESSING MODEL:
    1. Input paths are resolved to files.
    2. Files are read and validated as JSON.
    3. Unique string values are collected from the JSON.
    4. Text values are sent to translation providers.
    5. Successful translations replace the original JSON string values.
    6. Output is written while preserving the original formatting as much as possible.

PERFORMANCE:
    Unique strings are cached, so repeated text is translated once.
    Translation jobs run in parallel. To tune parallelism, set:
        `$env:TRANSLATE_MAX_PARALLEL = '20'

Supported Languages:
    Use ISO language codes supported by the translation providers.
    Examples: tr, en, de, fr, es, ru, it, ar, ja, ko, zh

Translation Services Used:
    Google Translate (gtx)
    Lingva Translate
    SimplyTranslate
    MyMemory
    LibreTranslate

Notes:
    - Internet access is required; if one provider fails, the script tries the next provider.
    - Large JSON files may take longer depending on provider response times.
    - Translation quality depends on the free providers; review important content manually.
"@
        }
}

function Get-EncodingInfo {
    param([byte[]]$bytes)
    $len = $bytes.Length
    if ($len -ge 4) {
        if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
            $enc = New-Object System.Text.UTF32Encoding $false, $true
            return @{ Encoding = $enc; Bom = 4 }
        }
        if ($bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
            $enc = New-Object System.Text.UTF32Encoding $true, $true
            return @{ Encoding = $enc; Bom = 4 }
        }
    }
    if ($len -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return @{ Encoding = [System.Text.Encoding]::UTF8; Bom = 3 }
    }
    if ($len -ge 2) {
        if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { return @{ Encoding = [System.Text.Encoding]::Unicode; Bom = 2 } }
        if ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { return @{ Encoding = [System.Text.Encoding]::BigEndianUnicode; Bom = 2 } }
    }

    # No BOM: try detect UTF8 by round-trip
    try {
        $utf8 = [System.Text.Encoding]::UTF8
        $s = $utf8.GetString($bytes)
        $re = $utf8.GetBytes($s)
        $equal = $false
        if ($re.Length -eq $bytes.Length) {
            $equal = $true
            for ($i = 0; $i -lt $re.Length; $i++) { if ($re[$i] -ne $bytes[$i]) { $equal = $false; break } }
        }
        if ($equal) { return @{ Encoding = [System.Text.Encoding]::UTF8; Bom = 0 } }
    } catch { }

    return @{ Encoding = [System.Text.Encoding]::Default; Bom = 0 }
}

function Escape-JsonString {
    param([string]$s)
    if ($null -eq $s) { return "" }
    return $s.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`r", '\r').Replace("`t", '\t')
}

function Detect-LanguageFromText {
    param([string]$text)
    if ([string]::IsNullOrWhiteSpace($text)) { return 'auto' }
    # Use Unicode char codes to avoid script encoding issues (çğıöşüÇĞİÖŞÜ)
    $trChars = [char]0xe7, [char]0x11f, [char]0x131, [char]0xf6, [char]0x15f, [char]0xfc, [char]0xc7, [char]0x11e, [char]0x130, [char]0xd6, [char]0x15e, [char]0xdc
    $turkishChars = ($text.ToCharArray() | Where-Object { $trChars -contains $_ }).Count
    $ratio = $turkishChars / [math]::Max(1, $text.Length)
    if ($ratio -gt 0.003) { return 'tr' }
    return 'en'
}

function Split-TextChunks {
    param([string]$text, [int]$max = 4000)
    $chunks = @()
    if (-not $text) { return $chunks }
    $pos = 0
    while ($pos -lt $text.Length) {
        $len = [Math]::Min($max, $text.Length - $pos)
        if ($len -eq $max) {
            $slice = $text.Substring($pos, $len)
            $lastSpace = $slice.LastIndexOf(' ')
            if ($lastSpace -gt 0) { $len = $lastSpace }
        }
        $chunks += $text.Substring($pos, $len)
        $pos += $len
    }
    return $chunks
}

function Invoke-GoogleTranslate {
    param($text, $from, $to)
    $sl = if ($from) { $from } else { 'auto' }
    $q = [System.Uri]::EscapeDataString($text)
    $uri = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sl&tl=$to&dt=t&dj=1&q=$q"
    try {
        $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 15 -ErrorAction Stop
        if ($resp -and $resp.sentences) { return ($resp.sentences | ForEach-Object { $_.trans }) -join '' }
        if ($resp -is [System.Array]) { $translated = ''; foreach ($s in $resp[0]) { $translated += $s[0] }; return $translated }
    } catch { }
    return $null
}

function Invoke-LingvaTranslate {
    param($text, $from, $to)
    $sl = if ($from) { $from } else { 'auto' }
    $q = [System.Uri]::EscapeDataString($text)
    $uri = "https://lingva.ml/api/v1/$sl/$to/$q"
    try {
        $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 15 -ErrorAction Stop
        if ($resp -and $resp.translation) { return $resp.translation }
    } catch { }
    return $null
}

function Invoke-SimplyTranslate {
    param($text, $from, $to)
    $sl = if ($from) { $from } else { 'auto' }
    $q = [System.Uri]::EscapeDataString($text)
    # Using a common instance. 
    $uri = "https://simplytranslate.org/api/translate?text=$q&from=$sl&to=$to"
    try {
        $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 15 -ErrorAction Stop
        if ($resp -and $resp.translated_text) { return $resp.translated_text }
    } catch { }
    return $null
}

function Invoke-LibreTranslate {
    param($text, $from, $to)
    $uri = 'https://libretranslate.de/translate'
    $source = if ($from) { $from } else { 'auto' }
    $body = @{ q = $text; source = $source; target = $to; format = 'text' } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 20 -ErrorAction Stop
        if ($resp -and $resp.translatedText) { return $resp.translatedText }
        if ($resp -and $resp.translations) { return ($resp.translations | ForEach-Object { $_.text }) -join ' ' }
    } catch { return $null }
    return $null
}

function Invoke-MyMemory {
    param($text, $from, $to)
    $sl = if ($from) { $from } else { 'en' }
    $q = [System.Uri]::EscapeDataString($text)
    $uri = "https://api.mymemory.translated.net/get?q=$q&langpair=$sl|$to"
    try {
        $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 15 -ErrorAction Stop
        if ($resp -and $resp.responseData -and $resp.responseData.translatedText) { return $resp.responseData.translatedText }
    } catch { return $null }
    return $null
}

function Translate-Text {
    param([string]$text, [string]$from, [string]$to)
    if (-not $text) { return $text }
    $chunks = Split-TextChunks -text $text -max 4000
    if ($chunks.Count -eq 0) { return $text }
    $result = ''
    foreach ($chunk in $chunks) {
        $translated = $null
        $providers = @('Google', 'Lingva', 'Simply', 'MyMemory', 'Libre')
        $attempts = 0
        while ($attempts -lt 2 -and -not $translated) {
            foreach ($provider in $providers) {
                switch ($provider) {
                    'Google'   { $translated = Invoke-GoogleTranslate -text $chunk -from $from -to $to }
                    'Lingva'   { $translated = Invoke-LingvaTranslate -text $chunk -from $from -to $to }
                    'Simply'   { $translated = Invoke-SimplyTranslate -text $chunk -from $from -to $to }
                    'MyMemory' { $translated = Invoke-MyMemory -text $chunk -from $from -to $to }
                    'Libre'    { $translated = Invoke-LibreTranslate -text $chunk -from $from -to $to }
                }
                if ($translated) { break }
                Start-Sleep -Milliseconds (Get-Random -Minimum 300 -Maximum 800)
            }
            $attempts++
            if (-not $translated -and $attempts -lt 2) { Start-Sleep -Seconds 2 }
        }
        
        if (-not $translated) { return $null }
        $result += $translated
    }
    return $result
}

# Translation cache and skip rules to avoid redundant translations and speed up processing
$translationCache = @{}

function Should-SkipTranslation {
    param([string]$text)
    if ($null -eq $text) { return $true }
    if ([string]::IsNullOrWhiteSpace($text)) { return $true }
    # If the string contains only numbers, whitespace (space, tab, newline), punctuation or symbols, skip translation
    $pattern = '^[\p{N}\s\p{P}\p{S}]+$'
    try {
        return [regex]::IsMatch($text, $pattern)
    } catch { return $false }
}

function Get-Or-Translate {
    param([string]$text, [string]$from, [string]$to)
    if ($null -eq $text) { return $text }
    if (Should-SkipTranslation $text) { return $text }
    $key = "$from|$to|$text"
    if ($translationCache.ContainsKey($key)) {
        $cached = $translationCache[$key]
        if ($cached -ne $null) { return $cached }
    }
    $translated = Translate-Text -text $text -from $from -to $to
    if ($translated -eq $null) {
        if (-not $SkipOnError) {
            Write-Error -Message "ERROR: Translation failed for '$text'. All providers failed. Stopping. Use -SkipOnError to keep the original text."
            exit 2
        } else {
            Write-Warning "WARNING: Translation failed for '$text'. Keeping the original text."
            $translated = $text
        }
    }
    $translationCache[$key] = $translated
    return $translated
}

# Collect unique strings from JSON structure (skip ones matching skip rules)
function Collect-UniqueStrings {
    param([object]$node, [ref]$set)
    if ($null -eq $node) { return }
    if ($node -is [string]) {
        if (-not (Should-SkipTranslation $node)) { $set.Value[$node] = $true }
        return
    }
        if ($node -is [System.Collections.IEnumerable] -and -not ($node -is [string])) {
        foreach ($it in $node) { Collect-UniqueStrings $it $set }
        return
    }
    if ($node -is [psobject]) {
        foreach ($p in $node.PSObject.Properties) { Collect-UniqueStrings $p.Value $set }
        return
    }
}

# Translate a list of texts in parallel by splitting into N batches and using Start-Job per batch
function Translate-TextsInParallel {
    param(
        [string[]]$texts,
        [string]$from,
        [string]$to,
        [int]$maxParallel = 20
    )
    $map = @{}
    if (-not $texts -or $texts.Count -eq 0) { return $map }

    # Create batched chunks (slice texts into up to $maxParallel batches)
    $jobs = @()
    $count = if ($texts -is [System.Array]) { $texts.Count } else { ($texts | Measure-Object).Count }
    if ($count -eq 0) { return $map }
    $maxParallel = [Math]::Max(1, [int]$maxParallel)
    $batchSize = [int][Math]::Ceiling($count / $maxParallel)
    for ($start = 0; $start -lt $count; $start += $batchSize) {
        $end = [Math]::Min($start + $batchSize - 1, $count - 1)
        $batch = $texts[$start..$end]
        if (-not $batch -or $batch.Count -eq 0) { continue }
        $j = Start-Job -ArgumentList ($batch, $from, $to) -ScriptBlock {
            param($batch, $from, $to)
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

            function Split-LocalChunks {
                param([string]$text, [int]$max=3000)
                $chunks = @()
                if (-not $text) { return $chunks }
                $pos = 0
                while ($pos -lt $text.Length) {
                    $len = [Math]::Min($max, $text.Length - $pos)
                    if ($len -eq $max) {
                        $slice = $text.Substring($pos, $len)
                        $lastSpace = $slice.LastIndexOf(' ')
                        if ($lastSpace -gt 0) { $len = $lastSpace }
                    }
                    $chunks += $text.Substring($pos, $len)
                    $pos += $len
                }
                return $chunks
            }

            $out = @()
            foreach ($text in $batch) {
                if ([string]::IsNullOrEmpty($text)) { $out += [pscustomobject]@{ Key = $text; Value = $text }; continue }
                $chunks = Split-LocalChunks -text $text -max 3000
                $translatedString = ''
                $anyFailure = $false
                
                foreach ($chunk in $chunks) {
                    $chunkTranslated = $null
                    $pAttempts = 0
                    while ($pAttempts -lt 2 -and -not $chunkTranslated) {
                        # Google
                        try {
                            $sl = if ($from) { $from } else { 'auto' }
                            $q = [System.Uri]::EscapeDataString($chunk)
                            $uri = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sl&tl=$to&dt=t&dj=1&q=$q"
                            $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 15 -ErrorAction Stop
                            if ($resp -and $resp.sentences) { $chunkTranslated = ($resp.sentences | ForEach-Object { $_.trans }) -join '' }
                            elseif ($resp -is [System.Array]) { foreach ($s in $resp[0]) { $chunkTranslated += $s[0] } }
                        } catch { }

                        # MyMemory
                        if (-not $chunkTranslated) {
                            try {
                                $slM = if ($from) { $from } else { 'en' }
                                $qM = [System.Uri]::EscapeDataString($chunk)
                                $resp = Invoke-RestMethod -Uri "https://api.mymemory.translated.net/get?q=$qM&langpair=$slM|$to" -Method Get -TimeoutSec 15 -ErrorAction Stop
                                if ($resp -and $resp.responseData -and $resp.responseData.translatedText) { $chunkTranslated = $resp.responseData.translatedText }
                            } catch { }
                        }

                        # Lingva
                        if (-not $chunkTranslated) {
                            try {
                                $qL = [System.Uri]::EscapeDataString($chunk)
                                $resp = Invoke-RestMethod -Uri "https://lingva.ml/api/v1/$(if($from){$from}else{'auto'})/$to/$qL" -Method Get -TimeoutSec 15 -ErrorAction Stop
                                if ($resp -and $resp.translation) { $chunkTranslated = $resp.translation }
                            } catch { }
                        }

                        $pAttempts++
                        if (-not $chunkTranslated) { Start-Sleep -Milliseconds (Get-Random -Minimum 500 -Maximum 1000) }
                    }

                    if ($chunkTranslated) { $translatedString += $chunkTranslated }
                    else { $anyFailure = $true; break }
                    Start-Sleep -Milliseconds (Get-Random -Minimum 200 -Maximum 500)
                }
                
                $finalValue = if ($anyFailure) { $null } else { $translatedString }
                $out += [pscustomobject]@{ Key = $text; Value = $finalValue }
            }
            return $out
        }
        $jobs += $j
    }

    if ($jobs.Count -gt 0) { Wait-Job -Job $jobs | Out-Null }
    foreach ($j in $jobs) {
        $res = Receive-Job -Job $j -ErrorAction SilentlyContinue
        foreach ($o in $res) { $map[$o.Key] = $o.Value }
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }

    return $map
}

function Translate-TextsWithFallback {
    param(
        [string[]]$texts,
        [string]$from,
        [string]$to,
        [int]$maxParallel = 20
    )

    $map = Translate-TextsInParallel -texts $texts -from $from -to $to -maxParallel $maxParallel
    $fallbackCount = 0

    foreach ($text in $texts) {
        if (-not $map.ContainsKey($text) -or $null -eq $map[$text]) {
            $fallbackCount++
            $map[$text] = Translate-Text -text $text -from $from -to $to
        }
    }

    if ($fallbackCount -gt 0) {
        Write-Host "Fallback translations attempted in main session: $fallbackCount"
    }

    return $map
}

function Resolve-InputFiles {
    param([string]$pattern)
    if (-not $pattern) { $pattern = '.\*' }
    $pattern = $pattern.Trim()
    if ($pattern -like '*[*?]*') {
        $dir = Split-Path $pattern -Parent
        if (-not $dir) { $dir = '.' }
        $leaf = Split-Path $pattern -Leaf
        return Get-ChildItem -Path $dir -Filter $leaf -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }
    if (Test-Path $pattern -PathType Container) { return Get-ChildItem -Path $pattern -File | Select-Object -ExpandProperty FullName }
    if (Test-Path $pattern -PathType Leaf) { return @(Resolve-Path $pattern).ProviderPath }
    try {
        $items = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        if ($items) { return $items }
    } catch { }
    if (-not ($pattern.ToLower().EndsWith('.json'))) {
        $maybe = $pattern + '.json'
        if (Test-Path $maybe) { return @(Resolve-Path $maybe).ProviderPath }
    }
    return @()
}

function Test-InputValueIsSingleFile {
    param([string]$pattern)
    if ([string]::IsNullOrWhiteSpace($pattern)) { return $false }
    $pattern = $pattern.Trim()
    if ($pattern -like '*[*?]*') { return $false }
    if (Test-Path $pattern -PathType Leaf) { return $true }
    if (-not ($pattern.ToLower().EndsWith('.json'))) {
        $maybe = $pattern + '.json'
        if (Test-Path $maybe -PathType Leaf) { return $true }
    }
    return $false
}

function Test-DirectoryLikePath {
    param([string]$path)
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    return ($path.EndsWith('\') -or $path.EndsWith('/'))
}

function Get-InputSetOutputDirectory {
    param(
        [string]$inputPattern,
        [string]$outputPattern,
        [bool]$outputSpecified
    )

    if ($outputSpecified) { return $outputPattern }
    if ([string]::IsNullOrWhiteSpace($inputPattern)) { return '.' }

    $inputPattern = $inputPattern.Trim()
    if (Test-Path $inputPattern -PathType Container) { return $inputPattern }
    if ($inputPattern -like '*[*?]*') {
        $dir = Split-Path -Path $inputPattern -Parent
        if ($dir) { return $dir }
        return '.'
    }
    $parent = Split-Path -Path $inputPattern -Parent
    if ($parent) { return $parent }
    return '.'
}

function Get-OutputPathForInput {
    param(
        [string]$filePath,
        [string]$inputPattern,
        [string]$outputPattern,
        [bool]$outputSpecified,
        [bool]$inputValueIsSingleFile
    )

    if ($inputValueIsSingleFile) {
        if (-not $outputSpecified) { return $filePath }
        if (Test-DirectoryLikePath -path $outputPattern) {
            return Join-Path -Path $outputPattern -ChildPath (Split-Path -Path $filePath -Leaf)
        }
        return $outputPattern
    }

    $outDir = Get-InputSetOutputDirectory -inputPattern $inputPattern -outputPattern $outputPattern -outputSpecified $outputSpecified
    return Join-Path -Path $outDir -ChildPath (Split-Path -Path $filePath -Leaf)
}

function Parse-SrtCues {
    param([string]$content)
    $lines = $content -split "\r?\n"
    $cues = @()
    $i = 0
    while ($i -lt $lines.Length) {
        if ([string]::IsNullOrWhiteSpace($lines[$i])) { $i++; continue }
        $idxLine = $lines[$i].Trim()
        $idx = $null
        if ([regex]::IsMatch($idxLine, '^\d+$')) { $idx = [int]$idxLine; $i++ }
        if ($i -ge $lines.Length) { break }
        $timeLine = $lines[$i].Trim()
        if (-not [regex]::IsMatch($timeLine, '^\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}')) {
            # invalid timecode, skip this block
            $i++; continue
        }
        $i++
        $textLines = @()
        while ($i -lt $lines.Length -and -not [string]::IsNullOrWhiteSpace($lines[$i])) {
            $textLines += $lines[$i]
            $i++
        }
        $text = ($textLines -join "`n")
        $cues += [pscustomobject]@{ Index = $idx; Time = $timeLine; Text = $text }
    }
    return $cues
}

function Parse-VttCues {
    param([string]$content)
    $lines = $content -split "\r?\n"
    $cues = @()
    $header = ''
    $i = 0
    # detect header (WEBVTT) and capture until first blank line
    for ($j = 0; $j -lt $lines.Length; $j++) {
        if (-not [string]::IsNullOrWhiteSpace($lines[$j])) { $i = $j; break }
    }
    if ($i -lt $lines.Length -and $lines[$i].TrimStart().ToUpper().StartsWith('WEBVTT')) {
        $headerLines = @()
        while ($i -lt $lines.Length) {
            if ([string]::IsNullOrWhiteSpace($lines[$i])) { $i++; break }
            $headerLines += $lines[$i]
            $i++
        }
        $header = ($headerLines -join "`n")
    } else { $i = 0 }

    while ($i -lt $lines.Length) {
        if ([string]::IsNullOrWhiteSpace($lines[$i])) { $i++; continue }
        $possibleId = $lines[$i].Trim()
        $timeLine = $null
        if ($i+1 -lt $lines.Length -and [regex]::IsMatch($lines[$i+1], '^\s*\d{2}:\d{2}:\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}')) {
            $cueId = $possibleId
            $i++
            $timeLine = $lines[$i].Trim()
        } elseif ([regex]::IsMatch($lines[$i], '^\s*\d{2}:\d{2}:\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}')) {
            $cueId = $null
            $timeLine = $lines[$i].Trim()
        } else {
            $i++; continue
        }
        $i++
        $textLines = @()
        while ($i -lt $lines.Length -and -not [string]::IsNullOrWhiteSpace($lines[$i])) {
            $textLines += $lines[$i]
            $i++
        }
        $text = ($textLines -join "`n")
        $cues += [pscustomobject]@{ Id = $cueId; Time = $timeLine; Text = $text }
    }
    return [pscustomobject]@{ Header = $header; Cues = $cues }
}

function Reconstruct-SrtContent {
    param([array]$cues)
    $parts = @()
    $counter = 1
    foreach ($c in $cues) {
        $index = if ($c.Index) { $c.Index } else { $counter }
        $parts += $index
        $parts += $c.Time
        $parts += ($c.Text -replace "`n", "`r`n")
        $parts += ""
        $counter++
    }
    return ($parts -join "`r`n")
}

function Reconstruct-VttContent {
    param([string]$header, [array]$cues)
    $parts = @()
    if ($header) { $parts += $header; $parts += "" }
    foreach ($c in $cues) {
        if ($c.Id) { $parts += $c.Id }
        $parts += $c.Time
        $parts += ($c.Text -replace "`n", "`r`n")
        $parts += ""
    }
    return ($parts -join "`r`n")
}

function Get-ReadableInputs {
    param([string[]]$paths)
    $items = @()
    $candidateCount = @($paths).Count
    foreach ($filePath in $paths) {
        if (-not (Test-Path $filePath -PathType Leaf)) { continue }
        $isJsonNamedFile = ([IO.Path]::GetExtension($filePath).ToLower() -eq '.json')
        $isVttNamedFile = ([IO.Path]::GetExtension($filePath).ToLower() -eq '.vtt')
        $isSrtNamedFile = ([IO.Path]::GetExtension($filePath).ToLower() -eq '.srt')
        try {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
        } catch {
            if ($candidateCount -eq 1 -or $isJsonNamedFile -or $isVttNamedFile -or $isSrtNamedFile) { Write-Warning "Dosya okunamadı: $filePath" }
            continue
        }

        $encInfo = Get-EncodingInfo -bytes $bytes
        $enc = $encInfo.Encoding
        $bom = $encInfo.Bom
        $content = $enc.GetString($bytes, $bom, $bytes.Length - $bom)

        $format = 'unknown'
        $jsonObj = $null
        try {
            $jsonObj = $content | ConvertFrom-Json -ErrorAction Stop
            $format = 'json'
        } catch {
            $firstNonEmpty = ($content -split "(\r?\n)" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
            if ($firstNonEmpty -and $firstNonEmpty.TrimStart().ToUpper().StartsWith('WEBVTT')) { $format = 'vtt' }
            elseif ([regex]::IsMatch($content, '^\s*\d+\s*\r?\n\s*\d{2}:\d{2}:\d{2},\d{3}\s*-->', [System.Text.RegularExpressions.RegexOptions]::Multiline)) { $format = 'srt' }
            if ($format -eq 'unknown') {
                if ($isVttNamedFile) { $format = 'vtt' }
                elseif ($isSrtNamedFile) { $format = 'srt' }
                elseif ($isJsonNamedFile) {
                    if ($candidateCount -eq 1) { Write-Warning "Okunabilir JSON değil, atlandı: $filePath" }
                    continue
                }
            }
        }

        if ($format -eq 'json') {
            $items += [pscustomobject]@{
                Path = $filePath
                Bytes = $bytes
                EncodingInfo = $encInfo
                Encoding = $enc
                Bom = $bom
                Content = $content
                Json = $jsonObj
                Format = 'json'
            }
        } elseif ($format -eq 'vtt') {
            $parsed = Parse-VttCues -content $content
            if (-not $parsed -or -not $parsed.Cues) {
                if ($candidateCount -eq 1 -or $isVttNamedFile) { Write-Warning "VTT içeriği anlaşılamadı, atlandı: $filePath" }
                continue
            }
            $items += [pscustomobject]@{
                Path = $filePath
                Bytes = $bytes
                EncodingInfo = $encInfo
                Encoding = $enc
                Bom = $bom
                Content = $content
                Header = $parsed.Header
                Cues = $parsed.Cues
                Format = 'vtt'
            }
        } elseif ($format -eq 'srt') {
            $cues = Parse-SrtCues -content $content
            if (-not $cues -or $cues.Count -eq 0) {
                if ($candidateCount -eq 1 -or $isSrtNamedFile) { Write-Warning "SRT içeriği anlaşılamadı, atlandı: $filePath" }
                continue
            }
            $items += [pscustomobject]@{
                Path = $filePath
                Bytes = $bytes
                EncodingInfo = $encInfo
                Encoding = $enc
                Bom = $bom
                Content = $content
                Cues = $cues
                Format = 'srt'
            }
        } else {
            if ($candidateCount -eq 1) { Write-Warning "Desteklenmeyen içerik, atlandı: $filePath" }
            continue
        }
    }
    return $items
}

## Determine help position and behavior (use command-line args for reliable ordering)
$mainNames = @('-inputdirectory','-inputlanguage','-outputdirectory','-outputlanguage')
$cmdArgs = [Environment]::GetCommandLineArgs()
$lowerArgs = $cmdArgs | ForEach-Object { if ($_ -ne $null) { $_.ToString().ToLower() } else { '' } }

$firstMainPos = -1
for ($i = 0; $i -lt $lowerArgs.Count; $i++) {
    foreach ($n in $mainNames) {
        if ($lowerArgs[$i] -eq $n -or $lowerArgs[$i].StartsWith($n + ':') -or $lowerArgs[$i].StartsWith($n + '=')) {
            $firstMainPos = $i
            break
        }
    }
    if ($firstMainPos -ne -1) { break }
}

$helpPos = -1
for ($i = 0; $i -lt $lowerArgs.Count; $i++) { if ($lowerArgs[$i] -eq '-help') { $helpPos = $i; break } }

$showHelpBefore = ($helpPos -ge 0 -and ($firstMainPos -eq -1 -or $helpPos -lt $firstMainPos))
$showHelpAfter = ($helpPos -ge 0 -and $firstMainPos -ne -1 -and $helpPos -gt $firstMainPos)

## help language and defaults
$supportedLangs = @('tr','en')
$sysLang = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName

$helpArg = $null
if ($HelpLanguage) {
    $candidate = $HelpLanguage.ToString().ToLower()
    if ($candidate -in $supportedLangs) { $helpArg = $candidate }
}
if (-not $helpArg -and $helpPos -ge 0 -and ($helpPos + 1) -lt $lowerArgs.Count) {
    $candidate = $lowerArgs[$helpPos + 1]
    if ($candidate -in $supportedLangs) { $helpArg = $candidate }
}

if ($helpArg) { $helpLang = $helpArg }
else { $helpLang = $sysLang; if ($helpLang -notin $supportedLangs) { $helpLang = 'en' } }

if ($helpPos -ge 0 -and $firstMainPos -eq -1) {
    # only help requested -> show help and exit
    Show-Help -lang $helpLang
    exit 0
}

if ($showHelpBefore) { Show-Help -lang $helpLang }

if ($HelpLanguage -and -not ($Help -and $helpArg -and $HelpLanguage.ToString().ToLower() -eq $helpArg)) {
    Write-Error -Message "Beklenmeyen konumsal argüman: $HelpLanguage. Parametre değerini ilgili parametre adının hemen ardından yazın."
    exit 1
}

$outputSpecified = $PSBoundParameters.ContainsKey('OutputDirectory')
if (-not $OutputDirectory) { $OutputDirectory = $InputDirectory }

# If OutputLanguage not provided, default to the system UI language; fallback to 'en'
if (-not $OutputLanguage) {
    if ($sysLang) { $OutputLanguage = $sysLang } else { $OutputLanguage = 'en' }
    Write-Host "OutputLanguage belirtilmedi; varsayılan olarak: $OutputLanguage"
}

$files = Resolve-InputFiles -pattern $InputDirectory
if (-not $files -or $files.Count -eq 0) { Write-Error "Girdi dosyası bulunamadı: $InputDirectory"; exit 1 }

$inputItems = Get-ReadableInputs -paths $files
if (-not $inputItems -or $inputItems.Count -eq 0) { Write-Error "Okunabilir girdi dosyası bulunamadı: $InputDirectory"; exit 1 }

$inputValueIsSingleFile = Test-InputValueIsSingleFile -pattern $InputDirectory

foreach ($item in $inputItems) {
    $filePath = $item.Path
    $enc = $item.Encoding
    $bom = $item.Bom
    $content = $item.Content
    $format = $item.Format

    # detect language (use provided InputLanguage if present)
    if ($format -eq 'json') { $textForDetect = $content } elseif ($format -in @('srt','vtt')) { $textForDetect = ($item.Cues | ForEach-Object { $_.Text }) -join ' ' } else { $textForDetect = $content }
    $detected = if ($InputLanguage) { $InputLanguage } else { Detect-LanguageFromText -text $textForDetect }

    # Determine output path early so we can decide copy/skip vs translate
    $outPath = Get-OutputPathForInput -filePath $filePath -inputPattern $InputDirectory -outputPattern $OutputDirectory -outputSpecified $outputSpecified -inputValueIsSingleFile $inputValueIsSingleFile

    $outDir = Split-Path -Path $outPath -Parent
    if (-not $outDir) { $outDir = '.' }
    if (Test-Path $outDir -PathType Leaf) {
        Write-Warning "Çıktı klasörü mevcut bir dosya olduğu için atlandı: $outDir"
        continue
    }
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    # Collect unique strings to translate (skip numeric/whitespace-only tokens)
    $uniqueMap = @{}
    $textsToTranslate = @()
    if ($format -eq 'json') {
        Collect-UniqueStrings $item.Json ([ref]$uniqueMap)
        if ($uniqueMap.Keys.Count -gt 0) { $textsToTranslate = $uniqueMap.Keys }
    } elseif ($format -in @('srt','vtt')) {
        foreach ($c in $item.Cues) { if (-not (Should-SkipTranslation $c.Text)) { $uniqueMap[$c.Text] = $true } }
        if ($uniqueMap.Keys.Count -gt 0) { $textsToTranslate = $uniqueMap.Keys }
    }
    Write-Host "Unique strings found: $($textsToTranslate.Count)"

    # Translate unique texts in parallel and fill cache
    Write-Host "Fetching translations..."
    $maxParallel = if ($env:TRANSLATE_MAX_PARALLEL) { [int]$env:TRANSLATE_MAX_PARALLEL } else { 20 }
    $translations = Translate-TextsWithFallback -texts $textsToTranslate -from $detected -to $OutputLanguage -maxParallel $maxParallel
    $successCount = 0
    foreach ($k in $translations.Keys) { 
        $val = $translations[$k]
        if ($null -eq $val -and -not $SkipOnError) {
            Write-Error -Message "ERROR: Translation failed for '$k'. All providers failed. Stopping. Use -SkipOnError to keep the original text."
            exit 2
        }
        if ($null -ne $val) { $successCount++ }
        $translationCache["$detected|$OutputLanguage|$k"] = $val
    }
    Write-Host "Successful translations: $successCount / $($textsToTranslate.Count)"

    # Apply translations
    if ($format -eq 'json') {
        # Surgical replacement to preserve formatting, comments and indentation
        $pattern = '(?<prefix>(?::|[\[,])\s*)"(?<content>(?:[^"\\]|\\.)*)"(?=\s*(?:[,\]\}]|$))'
        $outText = [regex]::Replace($content, $pattern, {
            param($m)
            $prefix = $m.Groups['prefix'].Value
            $rawContent = $m.Groups['content'].Value
            try { $unescaped = '"' + $rawContent + '"' | ConvertFrom-Json } catch { $unescaped = $rawContent.Replace('\\"', '"').Replace('\\\\', '\\').Replace('\\n', "`n").Replace('\\r', "`r").Replace('\\t', "`t") }
            $cacheKey = "$detected|$OutputLanguage|$unescaped"
            if ($translationCache.ContainsKey($cacheKey)) {
                $translated = $translationCache[$cacheKey]
                if ($null -ne $translated) { return $prefix + '"' + (Escape-JsonString $translated) + '"' }
            }
            return $m.Value
        })
        $preamble = $enc.GetPreamble()
        $outBytes = $enc.GetBytes($outText)
        if ($preamble.Length -gt 0 -and $bom -gt 0) { $final = $preamble + $outBytes } else { $final = $outBytes }
    } elseif ($format -eq 'srt') {
        foreach ($c in $item.Cues) {
            $orig = $c.Text
            $cacheKey = "$detected|$OutputLanguage|$orig"
            $translated = $null
            if ($translationCache.ContainsKey($cacheKey)) { $translated = $translationCache[$cacheKey] }
            elseif ($translations.ContainsKey($orig)) { $translated = $translations[$orig] }
            if ($null -eq $translated -and -not $SkipOnError) { Write-Error -Message "ERROR: Translation failed for cue text: '$orig'"; exit 2 }
            if ($null -ne $translated) { $c.Text = $translated }
        }
        $outText = Reconstruct-SrtContent -cues $item.Cues
        $preamble = $enc.GetPreamble()
        $outBytes = $enc.GetBytes($outText)
        if ($preamble.Length -gt 0 -and $bom -gt 0) { $final = $preamble + $outBytes } else { $final = $outBytes }
    } elseif ($format -eq 'vtt') {
        foreach ($c in $item.Cues) {
            $orig = $c.Text
            $cacheKey = "$detected|$OutputLanguage|$orig"
            $translated = $null
            if ($translationCache.ContainsKey($cacheKey)) { $translated = $translationCache[$cacheKey] }
            elseif ($translations.ContainsKey($orig)) { $translated = $translations[$orig] }
            if ($null -eq $translated -and -not $SkipOnError) { Write-Error -Message "ERROR: Translation failed for cue text: '$orig'"; exit 2 }
            if ($null -ne $translated) { $c.Text = $translated }
        }
        $outText = Reconstruct-VttContent -header $item.Header -cues $item.Cues
        $preamble = $enc.GetPreamble()
        $outBytes = $enc.GetBytes($outText)
        if ($preamble.Length -gt 0 -and $bom -gt 0) { $final = $preamble + $outBytes } else { $final = $outBytes }
    } else {
        Write-Warning "Desteklenmeyen format: $format - atlandı: $filePath"
        continue
    }

    try {
        [System.IO.File]::WriteAllBytes($outPath, $final)
        Write-Host "Çevrildi: $filePath -> $outPath"
    } catch {
        Write-Warning "Dosya yazılamadı: $outPath"
    }
}

if ($showHelpAfter) { Show-Help -lang $helpLang }
