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
 * Description: Create the DB Maintenance objects
 *				For more information see http://ola.hallengren.com/ 
 *	   History: 5/10/2011 - Michael Wells - Adapted for Auto-Install
 *				10/9/2011 - Updated to Ola's Sept 2011 release
 *****************************************************************************************************/

CREATE PROCEDURE [dbo].[CommandExecute]

@Command nvarchar(max),
@CommandType nvarchar(max),
@Mode int,
@Comment nvarchar(max) = NULL,
@DatabaseName nvarchar(max) = NULL,
@SchemaName nvarchar(max) = NULL,
@ObjectName nvarchar(max) = NULL,
@ObjectType nvarchar(max) = NULL,
@IndexName nvarchar(max) = NULL,
@IndexType int = NULL,
@StatisticsName nvarchar(max) = NULL,
@PartitionNumber int = NULL,
@ExtendedInfo xml = NULL,
@LogToTable nvarchar(max),
@Execute nvarchar(max)

AS

BEGIN

  ----------------------------------------------------------------------------------------------------
  --// Source: http://ola.hallengren.com                                                          //--
  ----------------------------------------------------------------------------------------------------

  SET NOCOUNT ON

  DECLARE @StartMessage nvarchar(max)
  DECLARE @EndMessage nvarchar(max)
  DECLARE @ErrorMessage nvarchar(max)
  DECLARE @ErrorMessageOriginal nvarchar(max)

  DECLARE @StartTime datetime
  DECLARE @EndTime datetime

  DECLARE @StartTimeSec datetime
  DECLARE @EndTimeSec datetime

  DECLARE @ID int

  DECLARE @Error int
  DECLARE @ReturnCode int

  SET @Error = 0
  SET @ReturnCode = 0

  ----------------------------------------------------------------------------------------------------
  --// Check core requirements                                                                    //--
  ----------------------------------------------------------------------------------------------------

  IF @LogToTable = 'Y' AND NOT EXISTS (SELECT * FROM sys.objects objects INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id] WHERE objects.[type] = 'U' AND schemas.[name] = 'dbo' AND objects.[name] = 'CommandLog')
  BEGIN
    SET @ErrorMessage = 'The table CommandLog is missing. Download http://ola.hallengren.com/scripts/CommandLog.sql.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Error <> 0
  BEGIN
    SET @ReturnCode = @Error
    GOTO ReturnCode
  END

  ----------------------------------------------------------------------------------------------------
  --// Check input parameters                                                                     //--
  ----------------------------------------------------------------------------------------------------

  IF @Command IS NULL OR @Command = ''
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Command is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @CommandType IS NULL OR @CommandType = '' OR LEN(@CommandType) > 60
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @CommandType is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Mode NOT IN(1,2) OR @Mode IS NULL
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Mode is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @LogToTable NOT IN('Y','N') OR @LogToTable IS NULL
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @LogToTable is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Execute NOT IN('Y','N') OR @Execute IS NULL
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Execute is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Error <> 0
  BEGIN
    SET @ReturnCode = @Error
    GOTO ReturnCode
  END

  ----------------------------------------------------------------------------------------------------
  --// Log initial information                                                                    //--
  ----------------------------------------------------------------------------------------------------

  SET @StartTime = GETDATE()
  SET @StartTimeSec = CONVERT(datetime,CONVERT(nvarchar,@StartTime,120),120)

  SET @StartMessage = 'Date and time: ' + CONVERT(nvarchar,@StartTimeSec,120) + CHAR(13) + CHAR(10)
  SET @StartMessage = @StartMessage + 'Command: ' + @Command
  IF @Comment IS NOT NULL SET @StartMessage = @StartMessage + CHAR(13) + CHAR(10) + 'Comment: ' + @Comment
  SET @StartMessage = REPLACE(@StartMessage,'%','%%')
  RAISERROR(@StartMessage,10,1) WITH NOWAIT

  IF @LogToTable = 'Y'
  BEGIN
    INSERT INTO dbo.CommandLog (DatabaseName, SchemaName, ObjectName, ObjectType, IndexName, IndexType, StatisticsName, PartitionNumber, ExtendedInfo, CommandType, Command, StartTime)
    VALUES (@DatabaseName, @SchemaName, @ObjectName, @ObjectType, @IndexName, @IndexType, @StatisticsName, @PartitionNumber, @ExtendedInfo, @CommandType, @Command, @StartTime)
  END

  SET @ID = SCOPE_IDENTITY()

  ----------------------------------------------------------------------------------------------------
  --// Execute command                                                                            //--
  ----------------------------------------------------------------------------------------------------

  IF @Mode = 1 AND @Execute = 'Y'
  BEGIN
    EXECUTE(@Command)
    SET @Error = @@ERROR
    SET @ReturnCode = @Error
  END

  IF @Mode = 2 AND @Execute = 'Y'
  BEGIN
    BEGIN TRY
      EXECUTE(@Command)
    END TRY
    BEGIN CATCH
      SET @Error = ERROR_NUMBER()
      SET @ReturnCode = @Error
      SET @ErrorMessageOriginal = ERROR_MESSAGE()
      SET @ErrorMessage = 'Msg ' + CAST(@Error AS nvarchar) + ', ' + ISNULL(@ErrorMessageOriginal,'')
      RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    END CATCH
  END

  ----------------------------------------------------------------------------------------------------
  --// Log completing information                                                                 //--
  ----------------------------------------------------------------------------------------------------

  SET @EndTime = GETDATE()
  SET @EndTimeSec = CONVERT(datetime,CONVERT(varchar,@EndTime,120),120)

  SET @EndMessage = 'Outcome: ' + CASE WHEN @Execute = 'N' THEN 'Not Executed' WHEN @Error = 0 THEN 'Succeeded' ELSE 'Failed' END + CHAR(13) + CHAR(10)
  SET @EndMessage = @EndMessage + 'Duration: ' + CASE WHEN DATEDIFF(ss,@StartTimeSec, @EndTimeSec)/(24*3600) > 0 THEN CAST(DATEDIFF(ss,@StartTimeSec, @EndTimeSec)/(24*3600) AS nvarchar) + '.' ELSE '' END + CONVERT(nvarchar,@EndTimeSec - @StartTimeSec,108) + CHAR(13) + CHAR(10)
  SET @EndMessage = @EndMessage + 'Date and time: ' + CONVERT(nvarchar,@EndTimeSec,120) + CHAR(13) + CHAR(10) + ' '
  SET @EndMessage = REPLACE(@EndMessage,'%','%%')
  RAISERROR(@EndMessage,10,1) WITH NOWAIT

  IF @LogToTable = 'Y'
  BEGIN
    UPDATE dbo.CommandLog
    SET EndTime = @EndTime,
        ErrorNumber = CASE WHEN @Execute = 'N' THEN NULL ELSE @Error END,
        ErrorMessage = @ErrorMessageOriginal
    WHERE ID = @ID
  END

  ReturnCode:
  IF @ReturnCode <> 0
  BEGIN
    RETURN @ReturnCode
  END

  ----------------------------------------------------------------------------------------------------

END
GO
