# Render every page of a PDF to PNG with the Windows.Data.Pdf API (Windows PowerShell 5.1).
#   powershell.exe -ExecutionPolicy Bypass -File report\render_pdf.ps1 -Pdf <file.pdf> -OutDir <dir> [-Width 1240]
param([string]$Pdf, [string]$OutDir, [int]$Width = 1240)

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]

$asTaskOp = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]

function Await($op, [Type]$type) {
    $task = $asTaskOp.MakeGenericMethod($type).Invoke($null, @($op))
    $task.Wait(-1) | Out-Null
    $task.Result
}
function AwaitAction($op) {
    $task = $asTaskAction.Invoke($null, @($op))
    $task.Wait(-1) | Out-Null
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync((Resolve-Path $Pdf).Path)) ([Windows.Storage.StorageFile])
$doc = Await ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
for ($i = 0; $i -lt $doc.PageCount; $i++) {
    $page = $doc.GetPage($i)
    $stream = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
    $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
    $opts.DestinationWidth = $Width
    AwaitAction ($page.RenderToStreamAsync($stream, $opts))
    $bytes = New-Object byte[] ([int]$stream.Size)
    $reader = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
    $reader.Position = 0
    $null = $reader.Read($bytes, 0, $bytes.Length)
    $out = Join-Path $OutDir ("page{0:D2}.png" -f ($i + 1))
    [System.IO.File]::WriteAllBytes($out, $bytes)
    $page.Dispose()
    Write-Output $out
}
