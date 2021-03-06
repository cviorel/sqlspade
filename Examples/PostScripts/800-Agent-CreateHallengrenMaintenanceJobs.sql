/* 2005,2008,2008R2,2012,2014,2016 */

/*****************************************************************************************************
 * Auto-Install Script Template
 *----------------------------------------------------------------------------------------------------
 *
 * Instructions:
 * The top line of this document must contain a commented comma seperated list of the versions of SQL 
 * that this script applies to.  Example: "/* 2000,2005,2008,2008R2 */"
 * 
 * This script template is only suitable for statements that are to be executed as part of the 
 * auto-install process and must run only against the server instance being installed.
 *
 * The script must terminate each statement using the ";" operator and the keyword 
 * "GO" must be enclosed in square brackets [].
 *
 * This template does not support scripts that need to be called with parameters.  If your script 
 * requires parameters please use the PowerShell Script template.
 *
 * Scripts must be named using the following pattern:
 * level-level name-script name
 *
 * level: The numeric level of the script.  This controls the order in which scripts are applied to
 *		  ensure that dependancies are not broken.  See Level list for the possible values.
 *
 * level name: The friendly name of the level.  This is meant to makes the scripts more easily
 *			   identifiable.  See Level list for the possible values.
 *
 * script name: The friendly name of the script.  This should be short, but detailed enought to tell
 *				what the script will accomplish.
 *
 * Example: "10-Server-AddExtendedProperty.sql" - Server level script that adds the DBA Extended
 *			property to the master and model databases
 *
 * Level List:
 * ---------------
 * 300 - Server - Scripts that create/alter/drop server level objects and settings
 * 400 - Database - Scripts that create/alter/drop databases and settings
 * 500 - Table - Scripts that create/alter/drop tables, schemas, users, roles
 * 600 - View - Scripts that create/alter/drop views, indexes, or other objects with table dependancies
 * 700 - Procedure - Scripts that create/alter/drop objects with table/view dependancies
 * 800 - Agent - Scripts that create/alter/drop agent jobs, job steps, job schedules, notifications, etc
 * 900 - Management - Scripts that are used for management operations
 *****************************************************************************************************/
 
 /*****************************************************************************************************
 * Script Information
 *----------------------------------------------------------------------------------------------------
 *		Author: Ola Hallengren
 *		  Date: Unknown
 * Description: Create the DB Maintenance jobs
 *				For more information see http://ola.hallengren.com/ 
 *	   History: 5/10/2011 - Michael Wells - Adapted for Auto-Install
 *				10/9/2011 - Updated to Ola's Sept 2011 release
 *****************************************************************************************************/

/*

SQL Server Backup, Integrity Check and Index Optimization.

The solution is supported on SQL Server 2005, SQL Server 2008 and SQL Server 2008 R2.

The documentation is available on http://ola.hallengren.com/Documentation.html.

The solution is free. The license is available on http://ola.hallengren.com/License.html.

My e-mail address is ola@hallengren.com. Please feel free to contact me.

Last updated 4 September 2011.

Ola Hallengren
http://ola.hallengren.com

*/

USE [master] -- <== This is the database that the objects will be created in.

SET NOCOUNT ON

DECLARE @BackupDirectory nvarchar(max)
DECLARE @CreateJobs nvarchar(max)
DECLARE @Version numeric(18,10)
DECLARE @Error int

SET @BackupDirectory = N'C:\Backup' -- <== Change this to your backup directory.

SET @CreateJobs = 'Y' -- <== Should jobs be created, 'Y' or 'N'?

SET @Error = 0

SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))

IF IS_SRVROLEMEMBER('sysadmin') = 0
BEGIN
  RAISERROR('The server role SysAdmin is needed for the installation.',16,1)
  SET @Error = @@ERROR
END

IF @Version < 9
BEGIN
  RAISERROR('The solution is supported on SQL Server 2005, SQL Server 2008 and SQL Server 2008 R2.',16,1)
  SET @Error = @@ERROR
END

IF (SELECT [compatibility_level] FROM sys.databases WHERE database_id = DB_ID()) < 90
BEGIN
  RAISERROR('The database that you are creating the objects in has to be in compatibility_level 90 or 100.',16,1)
  SET @Error = @@ERROR
END

IF OBJECT_ID('tempdb..#Config') IS NOT NULL DROP TABLE #Config

CREATE TABLE #Config ([Name] nvarchar(max),
                      [Value] nvarchar(max))

DECLARE @ErrorLog TABLE (LogDate datetime,
                         ProcessInfo nvarchar(max),
                         ErrorText nvarchar(max))

INSERT INTO @ErrorLog (LogDate, ProcessInfo, ErrorText)
EXECUTE [master].dbo.sp_readerrorlog 0

IF @@ERROR <> 0
BEGIN
  RAISERROR('Error reading from the error log.',16,1)
  SET @Error = @@ERROR
END

INSERT INTO #Config ([Name], [Value])
SELECT 'LogDirectory', REPLACE(REPLACE(ErrorText,'Logging SQL Server messages in file ''',''),'\ERRORLOG''.','')
FROM @ErrorLog
WHERE ErrorText LIKE 'Logging SQL Server messages in file%'

IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
BEGIN
  RAISERROR('The log directory could not be found.',16,1)
  SET @Error = @@ERROR
END

INSERT INTO #Config ([Name], [Value])
VALUES('BackupDirectory', @BackupDirectory)

INSERT INTO #Config ([Name], [Value])
VALUES('Database', DB_NAME(DB_ID()))

INSERT INTO #Config ([Name], [Value])
VALUES('Jobs', @CreateJobs)

INSERT INTO #Config ([Name], [Value])
VALUES('Error', CAST(@Error AS nvarchar))

IF (SELECT CAST([Value] AS nvarchar) FROM #Config WHERE Name = 'Error') <> '0' OR (SELECT [Value] FROM #Config WHERE Name = 'Jobs') <> 'Y' OR SERVERPROPERTY('EngineEdition') = 4
BEGIN
  RETURN
END
GO

DECLARE @LogDirectory nvarchar(max)
DECLARE @BackupDirectory nvarchar(max)
DECLARE @Database nvarchar(max)

DECLARE @Version numeric(18,10)

DECLARE @TokenServer nvarchar(max)
DECLARE @TokenJobID nvarchar(max)
DECLARE @TokenStepID nvarchar(max)
DECLARE @TokenDate nvarchar(max)
DECLARE @TokenTime nvarchar(max)

DECLARE @JobName01 nvarchar(max)
DECLARE @JobName02 nvarchar(max)
DECLARE @JobName03 nvarchar(max)
DECLARE @JobName04 nvarchar(max)
DECLARE @JobName05 nvarchar(max)
DECLARE @JobName06 nvarchar(max)
DECLARE @JobName07 nvarchar(max)
DECLARE @JobName08 nvarchar(max)
DECLARE @JobName09 nvarchar(max)
DECLARE @JobName10 nvarchar(max)

DECLARE @JobCommand01 nvarchar(max)
DECLARE @JobCommand02 nvarchar(max)
DECLARE @JobCommand03 nvarchar(max)
DECLARE @JobCommand04 nvarchar(max)
DECLARE @JobCommand05 nvarchar(max)
DECLARE @JobCommand06 nvarchar(max)
DECLARE @JobCommand07 nvarchar(max)
DECLARE @JobCommand08 nvarchar(max)
DECLARE @JobCommand09 nvarchar(max)
DECLARE @JobCommand10 nvarchar(max)

DECLARE @OutputFile01 nvarchar(max)
DECLARE @OutputFile02 nvarchar(max)
DECLARE @OutputFile03 nvarchar(max)
DECLARE @OutputFile04 nvarchar(max)
DECLARE @OutputFile05 nvarchar(max)
DECLARE @OutputFile06 nvarchar(max)
DECLARE @OutputFile07 nvarchar(max)
DECLARE @OutputFile08 nvarchar(max)
DECLARE @OutputFile09 nvarchar(max)
DECLARE @OutputFile10 nvarchar(max)

SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))

IF @Version >= 9.002047
BEGIN
  SET @TokenServer = '$' + '(ESCAPE_SQUOTE(SRVR))'
  SET @TokenJobID = '$' + '(ESCAPE_SQUOTE(JOBID))'
  SET @TokenStepID = '$' + '(ESCAPE_SQUOTE(STEPID))'
  SET @TokenDate = '$' + '(ESCAPE_SQUOTE(STRTDT))'
  SET @TokenTime = '$' + '(ESCAPE_SQUOTE(STRTTM))'
END
ELSE
BEGIN
  SET @TokenServer = '$' + '(SRVR)'
  SET @TokenJobID = '$' + '(JOBID)'
  SET @TokenStepID = '$' + '(STEPID)'
  SET @TokenDate = '$' + '(STRTDT)'
  SET @TokenTime = '$' + '(STRTTM)'
END

SELECT @LogDirectory = Value
FROM #Config
WHERE [Name] = 'LogDirectory'

SELECT @BackupDirectory = Value
FROM #Config
WHERE [Name] = 'BackupDirectory'

SELECT @Database = Value
FROM #Config
WHERE [Name] = 'Database'

SET @JobName01 = 'DatabaseBackup - SYSTEM_DATABASES - FULL'
SET @JobCommand01 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @Database + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 24, @CheckSum = ''Y''" -b'
SET @OutputFile01 = @LogDirectory + '\DatabaseBackup_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

SET @JobName02 = 'DatabaseBackup - USER_DATABASES - DIFF'
SET @JobCommand02 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @Database + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''DIFF'', @Verify = ''Y'', @CleanupTime = 24, @CheckSum = ''Y''" -b'
SET @OutputFile02 = @LogDirectory + '\DatabaseBackup_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

SET @JobName03 = 'DatabaseBackup - USER_DATABASES - FULL'
SET @JobCommand03 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @Database + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 24, @CheckSum = ''Y''" -b'
SET @OutputFile03 = @LogDirectory + '\DatabaseBackup_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

SET @JobName04 = 'DatabaseBackup - USER_DATABASES - LOG'
SET @JobCommand04 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @Database + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''LOG'', @Verify = ''Y'', @CleanupTime = 24, @CheckSum = ''Y''" -b'
SET @OutputFile04 = @LogDirectory + '\DatabaseBackup_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

SET @JobName05 = 'DatabaseIntegrityCheck - SYSTEM_DATABASES'
SET @JobCommand05 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @Database + ' -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''SYSTEM_DATABASES''" -b'
SET @OutputFile05 = @LogDirectory + '\DatabaseIntegrityCheck_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

SET @JobName06 = 'DatabaseIntegrityCheck - USER_DATABASES'
SET @JobCommand06 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @Database + ' -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''USER_DATABASES''" -b'
SET @OutputFile06 = @LogDirectory + '\DatabaseIntegrityCheck_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

SET @JobName07 = 'IndexOptimize - USER_DATABASES'
SET @JobCommand07 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @Database + ' -Q "EXECUTE [dbo].[IndexOptimize] @Databases = ''USER_DATABASES''" -b'
SET @OutputFile07 = @LogDirectory + '\IndexOptimize_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

SET @JobName08 = 'sp_delete_backuphistory'
SET @JobCommand08 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + 'msdb' + ' -Q "DECLARE @CleanupDate datetime SET @CleanupDate = DATEADD(dd,-30,GETDATE()) EXECUTE dbo.sp_delete_backuphistory @oldest_date = @CleanupDate" -b'
SET @OutputFile08 = @LogDirectory + '\sp_delete_backuphistory_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

SET @JobName09 = 'sp_purge_jobhistory'
SET @JobCommand09 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + 'msdb' + ' -Q "DECLARE @CleanupDate datetime SET @CleanupDate = DATEADD(dd,-30,GETDATE()) EXECUTE dbo.sp_purge_jobhistory @oldest_date = @CleanupDate" -b'
SET @OutputFile09 = @LogDirectory + '\sp_purge_jobhistory_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

SET @JobName10 = 'Output File Cleanup'
SET @JobCommand10 = 'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' + @LogDirectory + '" /m *_*_*_*_*.txt /d -30 2^>^&1'') do if not "%v" == "ERROR: No files found with the specified search criteria." echo del "' + @LogDirectory + '"\%v& del "' + @LogDirectory + '"\%v"'
SET @OutputFile10 = @LogDirectory + '\OutputFileCleanup_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName01)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName01
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName01, @step_name = @JobName01, @subsystem = 'CMDEXEC', @command = @JobCommand01, @output_file_name = @OutputFile01
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName01
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName02)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName02
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName02, @step_name = @JobName02, @subsystem = 'CMDEXEC', @command = @JobCommand02, @output_file_name = @OutputFile02
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName02
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName03)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName03
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName03, @step_name = @JobName03, @subsystem = 'CMDEXEC', @command = @JobCommand03, @output_file_name = @OutputFile03
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName03
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName04)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName04
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName04, @step_name = @JobName04, @subsystem = 'CMDEXEC', @command = @JobCommand04, @output_file_name = @OutputFile04
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName04
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName05)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName05
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName05, @step_name = @JobName05, @subsystem = 'CMDEXEC', @command = @JobCommand05, @output_file_name = @OutputFile05
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName05
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName06)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName06
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName06, @step_name = @JobName06, @subsystem = 'CMDEXEC', @command = @JobCommand06, @output_file_name = @OutputFile06
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName06
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName07)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName07
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName07, @step_name = @JobName07, @subsystem = 'CMDEXEC', @command = @JobCommand07, @output_file_name = @OutputFile07
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName07
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName08)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName08
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName08, @step_name = @JobName08, @subsystem = 'CMDEXEC', @command = @JobCommand08, @output_file_name = @OutputFile08
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName08
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName09)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName09
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName09, @step_name = @JobName09, @subsystem = 'CMDEXEC', @command = @JobCommand09, @output_file_name = @OutputFile09
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName09
END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName10)
BEGIN
  EXECUTE msdb.dbo.sp_add_job @job_name = @JobName10
  EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName10, @step_name = @JobName10, @subsystem = 'CMDEXEC', @command = @JobCommand10, @output_file_name = @OutputFile10
  EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName10
END