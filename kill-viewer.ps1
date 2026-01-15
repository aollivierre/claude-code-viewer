# Kill viewer process on port 3400
$conn = Get-NetTCPConnection -LocalPort 3400 -State Listen -ErrorAction SilentlyContinue
if ($null -ne $conn) {
    Stop-Process -Id $conn.OwningProcess -Force
    Write-Host "Killed process $($conn.OwningProcess)"
} else {
    Write-Host "No process listening on port 3400"
}
