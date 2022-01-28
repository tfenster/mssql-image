# Heavily inspired by https://github.com/microsoft/mssql-docker/blob/3d2c7d0779124ff4a1cccc9a21e7b038118f623f/windows/mssql-server-windows-developer/start.ps1

# The script sets the sa password and start the SQL Service
# Also it attaches additional database from the disk

$sa_password = $env:sa_password
$attach_dbs = $env:attach_dbs
$accept_eula = $env:accept_eula
$before_startup = $env:before_startup
$after_startup = $env:after_startup

if($accept_eula -ne "Y" -And $accept_eula -ne "y")
{
	Write-Host "ERROR: You must accept the End User License Agreement before this container can start."
	Write-Host "Set the environment variable accept_eula to 'Y' if you accept the agreement."

    exit 1
}

# run powershell scripts before starting SQL service
Write-Host "Running pre start-up scripts:"

if (-not (test-path $before_startup))
{
    Write-Host "before_startup is not a valid path: $before_startup"
    Write-Host "Skipping pre start-up scripts"
}
else
{
    Get-ChildItem $before_startup -Filter *.ps1 -File | Sort-Object Name | ForEach-Object {
        . $before_startup\$($_.Name)
    }
}

# start the service
Write-Host "Starting SQL Server"
$SqlServiceName = 'MSSQLSERVER'; 
if (-not [string]::isNullOrEmpty($env:EXP_EXE)) { 
    $SqlServiceName = 'MSSQL$SQLEXPRESS'; 
} 
start-service $SqlServiceName

if($sa_password -eq "_") {
    if (Test-Path $env:sa_password_path) {
        $sa_password = Get-Content -Raw $secretPath
    }
    else {
        Write-Host "WARN: Using default SA password, secret file not found at: $secretPath"
    }
}

if($sa_password -ne "_")
{
    Write-Host "Changing SA login credentials"
    $sqlcmd = "ALTER LOGIN sa with password=" +"'" + $sa_password + "'" + ";ALTER LOGIN sa ENABLE;"
    & sqlcmd -Q $sqlcmd
}

$attach_dbs_cleaned = $attach_dbs.TrimStart('\\').TrimEnd('\\')

$dbs = $attach_dbs_cleaned | ConvertFrom-Json

if ($null -ne $dbs -And $dbs.Length -gt 0)
{
    Write-Host "Attaching $($dbs.Length) database(s)"
	    
    Foreach($db in $dbs) 
    {            
        $files = @();
        Foreach($file in $db.dbFiles)
        {
            $files += "(FILENAME = N'$($file)')";           
        }

        $files = $files -join ","
        $sqlcmd = "IF EXISTS (SELECT 1 FROM SYS.DATABASES WHERE NAME = '" + $($db.dbName) + "') BEGIN EXEC sp_detach_db [$($db.dbName)] END;CREATE DATABASE [$($db.dbName)] ON $($files) FOR ATTACH;"

        Write-Host "Invoke-Sqlcmd -Query $($sqlcmd)"
        & sqlcmd -Q $sqlcmd
	}
}

Write-Host "Started SQL Server."

# run powershell scripts after starting SQL service
Write-Host "Running post start-up scripts:"
if (-not (test-path $after_startup))
{
    Write-Host "after_startup is not a valid path: $after_startup"
    Write-Host "Skipping post start-up scripts"
}
else
{
    Get-ChildItem $after_startup -Filter *.ps1 -File | Sort-Object Name | ForEach-Object {
        . $after_startup\$($_.Name)
    }
}

$lastCheck = (Get-Date).AddSeconds(-2) 
while ($true) 
{ 
    Get-EventLog -LogName Application -Source "MSSQL*" -After $lastCheck | Select-Object TimeGenerated, EntryType, Message	 
    $lastCheck = Get-Date 
    Start-Sleep -Seconds 2 
}