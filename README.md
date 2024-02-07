# MS SQL Server container image version 2022 + CU11 Build version 16.0.4105.2
An **unofficial**, **unsupported** and **in no way connected to Microsoft** container image for MS SQL Server

~~Resulting container images can be found at the Docker hub ([MS SQL Developer Edition](https://hub.docker.com/r/tobiasfenster/mssql-server-dev-unsupported/tags?page=1&ordering=last_updated) / [MS SQL Express](https://hub.docker.com/r/tobiasfenster/mssql-server-exp-unsupported/tags?page=1&ordering=last_updated))~~ **Update:** I was told by Microsoft that sharing the images on the Docker hub violates the EULA, so I had to remove them.

More background and instructions for usage in [this blog post](https://tobiasfenster.io/ms-sql-server-in-windows-containers)

# Update 02.07.2024:
This version was updated by me, Isaac Kramer based on the work of Tobias.
This version update the container to Sql Server 2022 + Comulative Update 11 (CU11) Build version 16.0.4105.2
for WINDOWS(!) container.

The steps for build are explaind in the Dockerfile.

You need 3 setup folders on the host to be ready for the build as seen in the Dockerfile:

1. The main SQL Server 2022 express setup media extracted so that the root SETUP.EXE will be in 'SQLSetupMedia/SQLEXPRADV_x64_ENU/' folder.
2. The CU update (in this case CU11) EXE file (don't need to be extacted) in '\SQLSetupMedia\CU\CU11\SQLServer2022-KB5032679-x64.exe'
3. Due to strange bug that the servercore 2022 image don't have old server controls (used to be at 1809) you must 
    have The Missing Server control files/folders - which is a bunch of folders which include old control dll's under 'Missing' folder.
    as explaind in here:  https://github.com/microsoft/mssql-docker/issues/540.
   So 4 folders needs to be in the folder '\SQLSetupMedia/CU/CU11/Missing/' to fix this strange bug i mentioned there.
you can get them from an old sql server installation from the GAC folder.
For convenience for the public i  uploaded  a zip file with all the folders to just drop it there.
zip file: OldServerControlsFolders.zip

SQL Server 2022 express (I believe it work the same for Dev/Ent) on WINDOWS container build 16.0.4105.2 (!)
Cheers.