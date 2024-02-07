#Build for  SQL SERVER Express 2022 WINDOWS on server core 2022 + CU11 (!!)
#Created by Isaac Kramer : tzahik1@gmail.com
#Based on the work of Tobias Fenster  https://github.com/tfenster/mssql-image/
#But with a twist of using 2 stages of SQL Server Install - 1. SysPrep (with FULL updates of CU) 2.CreatImage
# (normal CU update after server installed didn't worked for me when containerizeing)
# This version was for SQL Express buy I believe it can be done the same for Developer/Enterprise versions
#
# You need 3 setup folders on the host to be ready for the build as seen in the Dockerfile:

# 1. The main SQL Server 2022 express setup media extracted so that the root SETUP.EXE will be in 'SQLSetupMedia/SQLEXPRADV_x64_ENU/' folder.
# 2. The CU update (in this case CU11) EXE file (don't need to be extacted) in '\SQLSetupMedia\CU\CU11\SQLServer2022-KB5032679-x64.exe'
# 3. Due to strange bug that the servercore 2022 image don't have old server controls (used to be at 1809) you must 
#     have The Missing Server control files/folders - which is a bunch of folders which include old control dll's under 'Missing' folder.
#     as explaind in here:  https://github.com/microsoft/mssql-docker/issues/540.
#    So 4 folders needs to be in the folder '\SQLSetupMedia/CU/CU11/Missing/' to fix this strange bug i mentioned there.
# you can get them from an old sql server installation from the GAC folder.
# For convenience for the public i  uploaded  a zip file with all the folders to just drop it there.
# zip file: OldServerControlsFolders.zip

# How to use after build:
# docker build `
# --build-arg VERSION=16.0.1000.6 --build-arg TYPE=exp `
# -f Dockerfile.prep.txt ` (or without this line for fileName regular Dockerfile...)
# -t vanilla-sqlserver2022-exp-prep-based:2022-win-CU11-FINAL-1.0 .




#Step 1: Start from base image mcr.microsoft.com/windows/servercore
FROM mcr.microsoft.com/windows/servercore:ltsc2022
RUN echo "Step 1: Start from base image mcr.microsoft.com/windows/servercore"

LABEL maintainer "Isaac Kramer: tzahik1@gmail.com"


#Step 1.1 define ev and args:
ARG EXP_EXE="Something"   
ARG CU="" 
ARG VERSION 
ARG TYPE="exp"
ARG sa_password

ENV EXP_EXE=${EXP_EXE} 
ENV CU=$CU 
ENV VERSION=${VERSION}
ENV sa_password="Vmw0NTY3dmxzaTI1MDAh"
ENV attach_dbs="[]" 
ENV accept_eula="_"
ENV sa_password_path="C:\ProgramData\Docker\secrets\sa-password"

#Step 2: Create temporary directory to hold SQL Server XXXX installation files + CU
RUN echo "Step 2: Create temporary directory to hold SQL Server XXXX installation files + CU"
RUN powershell -Command (mkdir C:\co_SQLExp_Setup)
RUN powershell -Command (mkdir C:\co_CU_Setup)

#Step 2.1 because of Strange error on CU install : https://github.com/microsoft/mssql-docker/issues/540
# need to copy ahead missing files to GAC. Missing files (ServerControls) are in self made folder
# that can be created from old installment of Sql server in real PC and searching there the controls files
# as explained in the github issue above
RUN echo 'Step 2.1 because of error on CU install need to copy ahead missing files to GAC'
COPY '\SQLSetupMedia/CU/CU11/Missing/' C:/Windows/Microsoft.Net/assembly/GAC_MSIL

#Step 3: Copy SQL Server XXXX installation files from the host to the container image
RUN echo 'Step 3: Copy SQL Server XXXX installation files from the host to the container image'
COPY  '\SQLSetupMedia/SQLEXPRADV_x64_ENU/'  C:/co_SQLExp_Setup

#Step 3.1: Copy CU  XXXX installation .EXE file from the host to the container image to another folder
RUN echo 'Step 3.1: Copy CU  XXXX installation .EXE file from the host to the container image'
COPY '\SQLSetupMedia\CU\CU11\SQLServer2022-KB5032679-x64.exe' C:/co_CU_Setup

#Step 3.3 check size of setup media directory in container -should be  652431336 (622M)
RUN echo 'Step 3.3 check size of setup media directory in container -should be  652431336 (622M)'
WORKDIR  C:/co_SQLExp_Setup
RUN powershell -Command "(ls -r | measure -sum Length)"
# RUN powershell -Command "(Get-ChildItem -Recurse | Measure-Object -Sum Length)"
#back to origin
WORKDIR /


#Step 3.4 setup PowerShell for  error messages and user
RUN echo 'Step 3.4 setup PowerShell for  error messages and user'
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
USER ContainerAdministrator

#Step 3.5 get chocolatey to install 7zip vim and sqlpackage
RUN echo 'Step 3.5 get chocolatey to install 7zip vim and sqlpackage'
RUN $ProgressPreference = 'SilentlyContinue'; \
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    choco feature enable -n allowGlobalConfirmation; \
    choco install --no-progress --limit-output vim 7zip sqlpackage; \
     # Setup and use the Chocolatey helpers
    Import-Module "${ENV:ChocolateyInstall}\helpers\chocolateyProfile.psm1"; \
    Update-SessionEnvironment;
    # Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1" - didn't worked for me here \
    # refreshenv;      - didn't worked for me here

#Step 4: Install SQL Server Express SysPrep (Only Prepare Image with FULL UPDATES) via command line inside powershell
RUN echo 'Step 4: Install SQL Server Express SysPrep (Only Prepare Image with FULL UPDATES) via command line inside powershell'
RUN if (-not [string]::IsNullOrEmpty($env:EXP_EXE)) { \
        .\co_SQLExp_Setup\SETUP.exe /q /ACTION=PrepareImage   \
        /INSTANCEID=SQLEXPRESS  \
        /IACCEPTSQLSERVERLICENSETERMS /SUPPRESSPRIVACYSTATEMENTNOTICE /IACCEPTPYTHONLICENSETERMS \
        /IACCEPTROPENLICENSETERMS  \
        /INDICATEPROGRESS \
        # /SECURITYMODE=SQL /SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE" \
        #   /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' \
        # /SECURITYMODE=SQL /SAPWD=$sa_password /SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE" \
        # /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS'  \
        #  /UPDATEENABLED=True /UpdateSource='C:\co_CU_Setup\SQLServer2022-KB5032679-x64.exe' \
         /UPDATEENABLED=True /UpdateSource='C:\co_CU_Setup' \
        # /FEATURES=SQLEngine; \
        #  SQL= Installs the SQL Server Database Engine, Replication, Fulltext, and Data Quality Server.
        #  SQLEngine= Installs Only the SQL Server Database Engine.
        /FEATURES=SQL; \
        #test without delete - remove if nessacery: \
        # remove-item -recurse -force c:\co_SQLExp_Setup -ErrorAction SilentlyContinue; \
    }
        # Few tests here:
        # or:
        # /FEATURES=SQL,AS,IS \
        # /AGTSVCACCOUNT="NT AUTHORITY\System"  
    
#Step 4.5 Install SQL Server Express 'Complete Image' AFTER SysPrep Stage above via command line inside powershell
RUN echo 'Step 4.5 Install SQL Server Express 'Complete Image' AFTER SysPrep Stage via command line inside powershell'
RUN mkdir 'C:\databases';

RUN if (-not [string]::IsNullOrEmpty($env:EXP_EXE)) { \
        .\co_SQLExp_Setup\SETUP.exe /q /ACTION=CompleteImage /INSTANCEID=SQLEXPRESS \
        /IACCEPTSQLSERVERLICENSETERMS /SUPPRESSPRIVACYSTATEMENTNOTICE /IACCEPTPYTHONLICENSETERMS \
        /IACCEPTROPENLICENSETERMS  \
        /INDICATEPROGRESS \
        /INSTANCENAME=SQLEXPRESS  /INSTANCEID=SQLEXPRESS \
        # /SECURITYMODE=SQL /SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE" \
        # The password here we are inserting is NOT IMPORTANT because we change it at docker run (container) \
        # so you can enter here anything but must be SOMETHING, otherwise it won't work. \
        /SECURITYMODE=SQL /SAPWD='blaBlaBlaPass1!' /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' \
        # /SECURITYMODE=SQL /SAPWD=$sa_password /SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE" \
        /AGTSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' \
        /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' \
        /TCPENABLED=1 /NPENABLED=1    \
        # /FEATURES=SQLEngine \
        # /FEATURES=SQL; \
        /SQLUSERDBDIR='C:\databases' /SQLUSERDBLOGDIR='C:\databases'; \ 
        #test without delete - remove if nessacery:
        #clean up install media file to reduce container size
        remove-item -recurse -force c:\co_SQLExp_Setup -ErrorAction SilentlyContinue; \
        remove-item -recurse -force c:\co_CU_Setup -ErrorAction SilentlyContinue; \
    }
        # or:
        # /FEATURES=SQL,AS,IS \
        # /AGTSVCACCOUNT="NT AUTHORITY\System"  

# RUN $SqlServiceName = 'MSSQLSERVER'; `  // if working with developer version - but we WON'T!
#     if ($env:TYPE -eq 'exp') { `
#         $SqlServiceName = 'MSSQL$SQLEXPRESS'; `
#     } `
#Step 5 - Finished  Basic setup, now configure SERVICES and Registry Values
RUN echo 'Step 5: Finished  Basic setup, now configure SERVICES and Registry Values'
RUN  $SqlServiceName = 'MSSQL$SQLEXPRESS'; \
    While (!(get-service $SqlServiceName -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 5 } ; \
    Stop-Service $SqlServiceName ; \
    $databaseFolder = 'c:\databases'; \
    # mkdir > $null don't throw exception when dir already exist
    # this command creates directory and not return exception if already exist as we create it above
    New-Item -Path  $databaseFolder -ItemType Directory -Force; \
    $SqlWriterServiceName = 'SQLWriter'; \
    $SqlBrowserServiceName = 'SQLBrowser'; \
    Set-Service $SqlServiceName -startuptype automatic ; \
    Set-Service $SqlWriterServiceName -startuptype manual ; \
    Stop-Service $SqlWriterServiceName; \
    Set-Service $SqlBrowserServiceName -startuptype manual ; \
    Stop-Service $SqlBrowserServiceName; \
    $SqlTelemetryName = 'SQLTELEMETRY'; \
    if ($env:TYPE -eq 'exp') { \
        $SqlTelemetryName = 'SQLTELEMETRY$SQLEXPRESS'; \
    } \
    Set-Service $SqlTelemetryName -startuptype manual ; \
    Stop-Service $SqlTelemetryName; \
    $version = [System.Version]::Parse($env:VERSION); \
    $id = ('mssql' + $version.Major + '.MSSQLSERVER'); \
    if ($env:TYPE -eq 'exp') { \
        $id = ('mssql' + $version.Major + '.SQLEXPRESS'); \
    } \
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpdynamicports -value '' ; \
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpdynamicports -value '' ; \
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpport -value 1433 ; \
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name LoginMode -value 2; 
    # not needed anymore , set it above at  /SQLUSERDBDIR='C:\databases' /SQLUSERDBLOGDIR='C:\databases'; \ 
    # Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name DefaultData -value $databaseFolder; \
    # Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name DefaultLog -value $databaseFolder; 

#Step 6 - Check to Install Updates -CU - were not doing it that way any more - did update above at SysPrep stage
RUN echo "Disabled -Step 6 - Check to Install Updates -CU - Skipping!"
# RUN if (-not [string]::IsNullOrEmpty($env:CU)) { \
#         $ProgressPreference = 'SilentlyContinue'; \
#         Write-Host ('Install CU from ' + $env:CU) ; \
#          Invoke-WebRequest -UseBasicParsing -Uri $env:CU -OutFile c:\SQLServer-cu.exe ; \
#          .\SQLServer-cu.exe /q /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances ; \
#         $try = 0; \
#         while ($try -lt 20) { \
#             try { \
#                 $var = sqlcmd -Q 'select SERVERPROPERTY(''productversion'') as version' -W -m 1 | ConvertFrom-Csv | Select-Object -Skip 1 ; \
#                 if ($var.version[0] -eq $env:VERSION) { \
#                     Write-Host ('Patch done, found expected version ' + $var.version[0]) ; \
#                     $try = 21 ; \
#                 } else { \
#                     Write-Host ('Patch seems to be ongoing, found version ' + $var.version[0] + ', try ' + $try) ; \
#                 } \
#             } catch { \
#                 Write-Host 'Something unexpected happened, try' $try ; \
#                 Write-Host $_.ScriptStackTrace ; \
#             } finally { \
#                 if ($try -lt 20) { \
#                     Start-Sleep -Seconds 60 ; \
#                 } \
#                 $try++ ; \
#             } \
#         } \
#         if ($try -eq 20) { \
#             Write-Error 'Patch failed' \
#         } else { \
#             Write-Host 'Successfully patched!' \
#         } \
#      \
#      remove-item c:\SQLServer-cu.exe -ErrorAction SilentlyContinue; \
#      }

RUN echo "Skipped! -Finish step 6  CU Update!"



#Step 7: Set and create working directory for script execution
RUN echo 'Step 7: Set and create working directory for script execution at c:\scripts'
WORKDIR C:/scripts

#Step 8: Copy Start.ps1 to image on scripts directory
RUN echo 'Step 8: Copy Start.ps1 to image on scripts directory'
COPY start.ps1 C:/scripts

#Step 9: Run PowerShell script Start.ps1, passing inside the script  the -ACCEPT_EULA parameter with a value of Y
# and $sa_password to create/change sa password
# and json strcuture to attach_dbs
# BUT ACTUALLY we don't inserting these values here , but in Docker-compose.yaml file ore in docker run command
RUN echo 'Step 9: Run PowerShell script Start.ps1, passing inside the script  the -ACCEPT_EULA parameter with \
 a value of Y etc'
CMD .\start.ps1  


