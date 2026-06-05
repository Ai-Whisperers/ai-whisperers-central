Set-Location 'e:\WPG\Git\E21\GitRepos\eneve.domain\cicd\scripts'
$result = Invoke-Pester -Path .\run-mutation-tests.Tests.ps1 -PassThru

Write-Host ""
Write-Host "Test Results:" -ForegroundColor Cyan
Write-Host "Total: $($result.TotalCount)"
Write-Host "Passed: $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed: $($result.FailedCount)" -ForegroundColor Red

$coverage = [math]::Round(($result.PassedCount / $result.TotalCount) * 100, 2)
Write-Host "Coverage: $coverage%"

