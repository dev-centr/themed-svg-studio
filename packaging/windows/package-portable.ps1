[CmdletBinding()]
param(
    [ValidateSet("debug", "release")]
    [string]$Build = "release",
    [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
    $version = (Get-Content VERSION -Raw).Trim()
    dub build -c cli --build=$Build
    if ($LASTEXITCODE -ne 0) { throw "CLI build failed." }
    dub build -c gui --build=$Build
    if ($LASTEXITCODE -ne 0) { throw "GUI build failed." }

    $stage = Join-Path $OutputDirectory "themed-svg-studio-$version-windows-x64"
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    New-Item $stage -ItemType Directory -Force | Out-Null
    Copy-Item themed-svg-studio.exe,themed-svg-studio-cli.exe,README.adoc,CHANGELOG.adoc,LICENSE,VERSION $stage

    $zip = "$stage.zip"
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Compress-Archive -Path "$stage\*" -DestinationPath $zip
    $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText(
        "$zip.sha256",
        "$hash  $(Split-Path $zip -Leaf)`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "Created portable archive: $zip"
    Write-Warning "This is not an installer and is not code-signed."
}
finally {
    Pop-Location
}
