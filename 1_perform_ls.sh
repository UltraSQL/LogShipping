#!/bin/sh

####################################################################################################
# Name:
#		Perform SQL Server Log Shipping
#
# Created:
#		ryanxu 2012.04
#
# Execution Description:
#		1. Edit the Configuration file logshipping.config.
#		2. Execute the Bash Script on secondary server.
# 
# Script Description:
#		1: Create a Full Database Backup.
#		2: Use Winscp.exp to copy the Full Database Backup from primary server to secondary server.
#		3: Restore the Full Database Backup with norecovery on secondary server.
#		4: Configure Log Shipping.
#		5: Change the proxy account for the copy job on secondary server.
#		6: Modify the instance name of Log Shipping jobs.
#		7: Add the SQL Server Agent service account for Log Shipping jobs to execute.
####################################################################################################

sec_svr_ip=$1
sec_db_port=$2

awk -v tmp_sec_svr_ip=$sec_svr_ip -v tmp_sec_db_port=$sec_db_port '$1 == tmp_sec_svr_ip && $2 == tmp_sec_db_port' /cygdrive/d/upload/logshipping.config | while read sec_svr_ip sec_db_port sec_db_list pri_svr_ip pri_db_port pri_db_list bwlimit
do
	OLD_IFS="$IFS"
	IFS=","
	arr_pri_db=($pri_db_list)
	arr_sec_db=($sec_db_list)
	IFS="$OLD_IFS"
	
	i=0
	for pri_db in ${arr_pri_db[@]}
	do
		sec_db=${arr_sec_db[i]}
		
		
		
# Run the SQL Script on Primary Database.
sql_pri_db="

DECLARE @LS_BackupJobId AS uniqueidentifier 
DECLARE @LS_PrimaryId   AS uniqueidentifier 
DECLARE @SP_Add_RetCode As int 


EXEC @SP_Add_RetCode = master.dbo.sp_add_log_shipping_primary_database 
        @database = N'$pri_db' 
        ,@backup_directory = N'd:\LS_Primary\\$pri_db_port' 
        ,@backup_share = N'\\\\$pri_svr_ip\\d$\\LS_Primary\\$pri_db_port' 
        ,@backup_job_name = N'LSBackup_Primary_$pri_db' 
        ,@backup_retention_period = 900
        ,@backup_compression = 2
        ,@backup_threshold = 180 
        ,@threshold_alert_enabled = 1
		,@history_retention_period = 5760 
		,@backup_job_id = @LS_BackupJobId OUTPUT 
		,@primary_id = @LS_PrimaryId OUTPUT 
		,@overwrite = 1 


IF (@@ERROR = 0 AND @SP_Add_RetCode = 0) 
BEGIN 

DECLARE @LS_BackUpScheduleUID   As uniqueidentifier 
DECLARE @LS_BackUpScheduleID    AS int 


EXEC msdb.dbo.sp_add_schedule 
        @schedule_name =N'LSBackupSchedule_Primary' 
        ,@enabled = 1 
        ,@freq_type = 4 
        ,@freq_interval = 1 
        ,@freq_subday_type = 4 
        ,@freq_subday_interval = 2 
        ,@freq_recurrence_factor = 0 
        ,@active_start_date = 20120405 
        ,@active_end_date = 99991231 
        ,@active_start_time = 0 
        ,@active_end_time = 235900 
        ,@schedule_uid = @LS_BackUpScheduleUID OUTPUT 
        ,@schedule_id = @LS_BackUpScheduleID OUTPUT 

EXEC msdb.dbo.sp_attach_schedule 
        @job_id = @LS_BackupJobId 
        ,@schedule_id = @LS_BackUpScheduleID  

EXEC msdb.dbo.sp_update_job 
        @job_id = @LS_BackupJobId 
        ,@enabled = 1 


END 


EXEC master.dbo.sp_add_log_shipping_alert_job 

EXEC master.dbo.sp_add_log_shipping_primary_secondary 
        @primary_database = N'$pri_db' 
        ,@secondary_server = N'$sec_svr_ip,$sec_db_port' 
        ,@secondary_database = N'$sec_db' 
        ,@overwrite = 1 
"

# Run the SQL Script on Secondary Database.
sql_sec_db="
DECLARE @LS_Secondary__CopyJobId	AS uniqueidentifier 
DECLARE @LS_Secondary__RestoreJobId	AS uniqueidentifier 
DECLARE @LS_Secondary__SecondaryId	AS uniqueidentifier 
DECLARE @LS_Add_RetCode	As int 


EXEC @LS_Add_RetCode = master.dbo.sp_add_log_shipping_secondary_primary 
		@primary_server = N'$pri_svr_ip,$pri_db_port' 
		,@primary_database = N'$pri_db' 
		,@backup_source_directory = N'\\\\$pri_svr_ip\\d$\\LS_Primary\\$pri_db_port' 
		,@backup_destination_directory = N'd:\LS_Secondary\\$sec_db_port\\[${pri_svr_ip}][${pri_db_port}]' 
		,@copy_job_name = N'LSCopy_Secondary_$sec_db' 
		,@restore_job_name = N'LSRestore_Secondary_$sec_db' 
		,@file_retention_period = 60 
		,@overwrite = 1 
		,@copy_job_id = @LS_Secondary__CopyJobId OUTPUT 
		,@restore_job_id = @LS_Secondary__RestoreJobId OUTPUT 
		,@secondary_id = @LS_Secondary__SecondaryId OUTPUT 

IF (@@ERROR = 0 AND @LS_Add_RetCode = 0) 
BEGIN 

DECLARE @LS_SecondaryCopyJobScheduleUID	As uniqueidentifier 
DECLARE @LS_SecondaryCopyJobScheduleID	AS int 


EXEC msdb.dbo.sp_add_schedule 
		@schedule_name =N'DefaultCopyJobSchedule' 
		,@enabled = 1 
		,@freq_type = 4 
		,@freq_interval = 1 
		,@freq_subday_type = 4 
		,@freq_subday_interval = 3 
		,@freq_recurrence_factor = 0 
		,@active_start_date = 20120405 
		,@active_end_date = 99991231 
		,@active_start_time = 0 
		,@active_end_time = 235900 
		,@schedule_uid = @LS_SecondaryCopyJobScheduleUID OUTPUT 
		,@schedule_id = @LS_SecondaryCopyJobScheduleID OUTPUT 

EXEC msdb.dbo.sp_attach_schedule 
		@job_id = @LS_Secondary__CopyJobId 
		,@schedule_id = @LS_SecondaryCopyJobScheduleID  

DECLARE @LS_SecondaryRestoreJobScheduleUID	As uniqueidentifier 
DECLARE @LS_SecondaryRestoreJobScheduleID	AS int 


EXEC msdb.dbo.sp_add_schedule 
		@schedule_name =N'DefaultRestoreJobSchedule' 
		,@enabled = 1 
		,@freq_type = 4 
		,@freq_interval = 1 
		,@freq_subday_type = 4 
		,@freq_subday_interval = 2 
		,@freq_recurrence_factor = 0 
		,@active_start_date = 20120405 
		,@active_end_date = 99991231 
		,@active_start_time = 0 
		,@active_end_time = 235900 
		,@schedule_uid = @LS_SecondaryRestoreJobScheduleUID OUTPUT 
		,@schedule_id = @LS_SecondaryRestoreJobScheduleID OUTPUT 

EXEC msdb.dbo.sp_attach_schedule 
		@job_id = @LS_Secondary__RestoreJobId 
		,@schedule_id = @LS_SecondaryRestoreJobScheduleID  


END 


DECLARE @LS_Add_RetCode2	As int 


IF (@@ERROR = 0 AND @LS_Add_RetCode = 0) 
BEGIN 

EXEC @LS_Add_RetCode2 = master.dbo.sp_add_log_shipping_secondary_database 
		@secondary_database = N'$sec_db' 
		,@primary_server = N'$pri_svr_ip,$pri_db_port' 
		,@primary_database = N'$pri_db' 
		,@restore_delay = 0 
		,@restore_mode = 1 
		,@disconnect_users	= 1 
		,@restore_threshold = 45   
		,@threshold_alert_enabled = 1 
		,@history_retention_period	= 5760 
		,@overwrite = 1 

END 


IF (@@error = 0 AND @LS_Add_RetCode = 0) 
BEGIN 

EXEC msdb.dbo.sp_update_job 
		@job_id = @LS_Secondary__CopyJobId 
		,@enabled = 1 

EXEC msdb.dbo.sp_update_job 
		@job_id = @LS_Secondary__RestoreJobId 
		,@enabled = 1 

END 
"
# Run the SQL Script on Secondary Database.
sql_restore_db="
DECLARE @DBName_Restore nvarchar(256),
    @BakFile nvarchar(4000),
    @RestoreFolder nvarchar(4000),
    @Restore_MOVE nvarchar(4000)

    ,@rtn int, @cmd nvarchar(4000), @sql nvarchar(4000)
    ,@LogicalName nvarchar(128)
    ,@Type char(1)
    ;
    
SELECT @DBName_Restore = '$sec_db',
	@BakFile='D:\LS_Secondary\\$sec_db_port\\[${pri_svr_ip}][${pri_db_port}]\\${pri_db}.bak',
	@RestoreFolder='D:\gamedb\\$sec_db_port\\'
	;
	
    CREATE TABLE #FileList(
    LogicalName nvarchar(128),
    Physicalname nvarchar(260),
    Type char(1),
    FileGroupName nvarchar(128),
    Size numeric(20,0),
    MaxSize numeric(20),
    FileID bigint,
    CreateLSN numeric(25,0),
    DropLSN numeric(25,0) NULL,
    UniqueID uniqueidentifier,
    ReadOnlyLSN numeric(25,0) NULL,
    ReadWriteLSN numeric(25,0) NULL,
    BackupSizeInBytes bigint,
    SourceBlockSize int,
    FileGroupID int ,
    LogGroupGUID uniqueidentifier NULL,
    DifferentialBaseLSN numeric(25,0) NULL,
    DifferentialBaseGUID uniqueidentifier,
    IsReadOnly bit,
    IsPresent bit,
    TDEThumbprint varbinary(32)
);

DECLARE @csrF CURSOR;
SET @csrF=CURSOR FOR
SELECT LogicalName,Type FROM #FileList WHERE Type IN ('D','L');

SELECT @sql = 'RESTORE FILELISTONLY FROM DISK=@BakFile',@Restore_MOVE = '';
INSERT #FileList(LogicalName,Physicalname,Type,FileGroupName,Size,MaxSize,FileID,CreateLSN,DropLSN
    ,UniqueID,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroupID,LogGroupGUID
    ,DifferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent,TDEThumbprint)
EXEC sp_executesql @sql,N'@BakFile nvarchar(512)', @BakFile=@BakFile;

OPEN @csrF;
FETCH NEXT FROM @csrF INTO @LogicalName,@Type;
WHILE(@@FETCH_STATUS=0)
BEGIN
    SELECT @Restore_MOVE = @Restore_MOVE + ',MOVE ''' + @LogicalName
        + ''' TO ''' + @RestoreFolder + @DBName_Restore + '[' + @LogicalName
        + '].' + CASE @Type WHEN 'D' THEN 'mdf' ELSE 'ldf' END + '''';

    NEXT_File:
    FETCH NEXT FROM @csrF INTO @LogicalName,@Type;
END
CLOSE @csrF;

SELECT @sql = 'DBCC TRACEON(1807);
    RESTORE DATABASE @DBName_Restore FROM DISK=@BakFile WITH REPLACE,NORECOVERY' + @Restore_MOVE;
EXEC sp_executesql @sql, N'@DBName_Restore nvarchar(256), @BakFile nvarchar(4000)', @DBName_Restore = @DBName_Restore, @BakFile = @BakFile;


DROP TABLE #FileList;
"
# Run the SQL Script on Secondary Database.
sql_proxy="
DECLARE @Identity nvarchar(32), @sql nvarchar(1024);
SELECT @Identity = host_name() + '\mssql',
	@sql = 'CREATE CREDENTIAL mssql WITH IDENTITY = ''' + @Identity + ''', SECRET = ''syhy2yH''';
EXEC sp_executesql @sql;
GO

EXEC msdb.dbo.sp_add_proxy @proxy_name=N'mssql',@credential_name=N'mssql', 
		@enabled=1
GO

EXEC msdb.dbo.sp_grant_proxy_to_subsystem @proxy_name=N'mssql', @subsystem_id=3
GO
"
# Run the SQL Script on Primary Database.
sql_pri_inst_name="
DECLARE @OldServer sysname, @NewServer sysname,
	@OldHostName sysname, @NewHostName sysname,
	@InstanceUpdated sysname,
	@OldLogin sysname, @NewLogin sysname,
	@Cmd nvarchar(max)
	;  

--获取旧实例名和新实例名
SET @OldServer = @@SERVERNAME;  
SET @NewServer = CAST(SERVERPROPERTY('ServerName') AS sysname);
             
--获取旧机器名           
IF CHARINDEX('\\',@OldServer,1) <> 0
	SET @OldHostName = SUBSTRING(@OldServer,1,CHARINDEX('\\',@OldServer,1)-1);
ELSE
	SET @OldHostName = @OldServer;

--获取新机器名（远程执行时HOST_NAME()函数不代表远程主机）          
IF CHARINDEX('\\',@NewServer,1) <> 0
	SET @NewHostName = SUBSTRING(@NewServer,1,CHARINDEX('\\',@NewServer,1)-1);
ELSE
	SET @NewHostName = @NewServer;

IF @OldServer <> @NewServer  
BEGIN
	--更新实例名
	SELECT @InstanceUpdated = ISNULL(srvname,'')
	FROM sys.sysservers
	WHERE srvid = 0; 
	IF @InstanceUpdated <> @NewServer
	BEGIN
		EXEC sp_dropserver @OldServer; 
		EXEC sp_addserver @NewServer, 'LOCAL';
	END

	--更新作业里的实例名
    SELECT @Cmd = REPLACE(js.command, @OldServer, @NewServer)
    FROM msdb.dbo.sysjobsteps AS js INNER JOIN msdb.dbo.sysjobs AS j
        ON js.job_id = j.job_id
    WHERE j.name = 'LSBackup_Primary_$pri_db'
        AND js.step_id = 1 AND js.subsystem = 'CMDEXEC';

    EXEC msdb.dbo.sp_update_jobstep
        @job_name = N'LSBackup_Primary_$pri_db',
        @step_id = 1,
        @command = @Cmd;

	--更新Logins
	DECLARE @cur CURSOR;
	SET @cur = CURSOR FOR
		SELECT name FROM sys.syslogins WHERE isntuser=1 AND name LIKE @OldHostName + '%';
	OPEN @cur;
	FETCH NEXT FROM @cur INTO @OldLogin;
	WHILE(@@FETCH_STATUS=0)
	BEGIN
		--删除受影响的系统登陆用户（如有基于该帐号的验证对象，需要先删除该对象）
		EXEC sp_revokelogin @OldLogin;  

		--添加正确的系统登陆用户    
		SET @NewLogin = REPLACE(@OldLogin,@OldHostName,@NewHostName);
		EXEC sp_grantlogin @NewLogin;  
		EXEC sp_addsrvrolemember @NewLogin, 'sysadmin' 

		FETCH NEXT FROM @cur INTO @OldLogin;
	END
	CLOSE @cur;
	DEALLOCATE @cur;
END

--日志传送用到代理服务启动账号
SET @NewLogin = @NewHostName + '\sqlserver';   
IF NOT EXISTS(SELECT name FROM sys.syslogins WHERE isntuser=1 AND name = @NewLogin)
BEGIN
	EXEC sp_grantlogin @NewLogin;  
	EXEC sp_addsrvrolemember @NewLogin, 'sysadmin' 
END
"
# Run the SQL Script on Secondary Database.
sql_sec_inst_name="
DECLARE @OldServer sysname, @NewServer sysname,
	@OldHostName sysname, @NewHostName sysname,
	@InstanceUpdated sysname,
	@OldLogin sysname, @NewLogin sysname,
	@Cmd nvarchar(max), @Cmd2 nvarchar(max)
	;  

--获取旧实例名和新实例名
SET @OldServer = @@SERVERNAME;  
SET @NewServer = CAST(SERVERPROPERTY('ServerName') AS sysname);


--获取旧机器名           
IF CHARINDEX('\\',@OldServer,1) <> 0
	SET @OldHostName = SUBSTRING(@OldServer,1,CHARINDEX('\\',@OldServer,1)-1);
ELSE
	SET @OldHostName = @OldServer;

--获取新机器名（远程执行时HOST_NAME()函数不代表远程主机）          
IF CHARINDEX('\\',@NewServer,1) <> 0
	SET @NewHostName = SUBSTRING(@NewServer,1,CHARINDEX('\\',@NewServer,1)-1);
ELSE
	SET @NewHostName = @NewServer;

IF @OldServer <> @NewServer  
BEGIN
	--更新实例名
	SELECT @InstanceUpdated = ISNULL(srvname,'')
	FROM sys.sysservers
	WHERE srvid = 0; 
	IF @InstanceUpdated <> @NewServer
	BEGIN
		EXEC sp_dropserver @OldServer; 
		EXEC sp_addserver @NewServer, 'LOCAL';
	END

	--更新作业里的实例名
	SELECT @Cmd = REPLACE(js.command, @OldServer, @NewServer)
	FROM msdb.dbo.sysjobsteps AS js INNER JOIN msdb.dbo.sysjobs AS j
		ON js.job_id = j.job_id
	WHERE j.name = 'LSCopy_Secondary_$sec_db'
		AND js.step_id = 1 AND js.subsystem = 'CMDEXEC';

	EXEC msdb.dbo.sp_update_jobstep
		@job_name = N'LSCopy_Secondary_$sec_db',
		@step_id = 1,
		@command = @Cmd;

    SELECT @Cmd2 = REPLACE(js.command, @OldServer, @NewServer)
    FROM msdb.dbo.sysjobsteps AS js INNER JOIN msdb.dbo.sysjobs AS j
        ON js.job_id = j.job_id
    WHERE j.name = 'LSRestore_Secondary_$sec_db'
        AND js.step_id = 1 AND js.subsystem = 'CMDEXEC';

    EXEC msdb.dbo.sp_update_jobstep
        @job_name = N'LRestore_Secondary_$sec_db',
        @step_id = 1,
        @command = @Cmd;

	--更新Logins
	DECLARE @cur CURSOR;
	SET @cur = CURSOR FOR
		SELECT name FROM sys.syslogins WHERE isntuser=1 AND name LIKE @OldHostName + '%';
	OPEN @cur;
	FETCH NEXT FROM @cur INTO @OldLogin;
	WHILE(@@FETCH_STATUS=0)
	BEGIN
		--删除受影响的系统登陆用户（如有基于该帐号的验证对象，需要先删除该对象）
		EXEC sp_revokelogin @OldLogin;  

		--添加正确的系统登陆用户    
		SET @NewLogin = REPLACE(@OldLogin,@OldHostName,@NewHostName);
		EXEC sp_grantlogin @NewLogin;  
		EXEC sp_addsrvrolemember @NewLogin, 'sysadmin' 

		FETCH NEXT FROM @cur INTO @OldLogin;
	END
	CLOSE @cur;
	DEALLOCATE @cur;
END

--日志传送用到代理服务启动账号
SET @NewLogin = @NewHostName + '\sqlserver';   
IF NOT EXISTS(SELECT name FROM sys.syslogins WHERE isntuser=1 AND name = @NewLogin)
BEGIN
	EXEC sp_grantlogin @NewLogin;  
	EXEC sp_addsrvrolemember @NewLogin, 'sysadmin' 
END
"

SQLCMD="/cygdrive/c/Program Files/Microsoft SQL Server/100/Tools/Binn/SQLCMD.EXE"

		echo "######### Begin perform logshipping from $pri_svr_ip,$pri_db_port:$pri_db to $sec_svr_ip,$sec_db_port:$sec_db #########"

		#Disable Backup jobs on Primary Database.
		"$SQLCMD" -S $pri_svr_ip,$pri_db_port -U sa -P 8qllyhY -d msdb -Q "EXEC msdb.dbo.sp_update_job @job_name=N'[dbo]-backup-time', @enabled=0;EXEC msdb.dbo.sp_update_job @job_name=N'[dbo]-backup-day', @enabled=0;"
	
		#Create a directory on Secondary Server.
		"$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d msdb -Q "EXEC master.sys.xp_cmdshell 'mkdir -p D:\LS_Secondary\\$sec_db_port\\[${pri_svr_ip}][${pri_db_port}] D:\gamedb\\$sec_db_port'"
	
		#Create a Full Database Backup on Primary Database.
		"$SQLCMD" -S $pri_svr_ip,$pri_db_port -U sa -P 8qllyhY -d msdb -Q "ALTER DATABASE $pri_db SET RECOVERY FULL;EXEC master.sys.xp_cmdshell 'mkdir -p D:\LS_Primary\\$pri_db_port';BACKUP DATABASE $pri_db TO DISK='D:\LS_Primary\\$pri_db_port\\${pri_db}.bak' WITH FORMAT,INIT;"

		#SCP the Full Database Backup to Secondary Server.
		/cygdrive/d/upload/winscp.exp $pri_svr_ip mssql syhy2yH 36000 /cygdrive/d/LS_Primary/$pri_db_port/${pri_db}.bak /cygdrive/d/LS_Secondary/$sec_db_port/[$pri_svr_ip][$pri_db_port] pull $bwlimit -1

		#Restore Database on Secondary Database.
	    "$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d msdb -Q "$sql_restore_db"

		#echo "$sql_pri_db">/cygdrive/d/upload/ls_pri_db.sql
		#echo "$sql_proxy">/cygdrive/d/upload/add_proxy.sql
		#echo "$sql_sec_db">/cygdrive/d/upload/ls_sec_db.sql

		#Configure Log Shipping on Primary Database.
		"$SQLCMD" -S $pri_svr_ip,$pri_db_port -U sa -P 8qllyhY -d msdb -Q "$sql_pri_db"

		#Add a proxy account on Secondary Database.
		"$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d msdb -Q "$sql_proxy"

		#Configure Log Shipping on Secondary Database.
		"$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d msdb -Q "$sql_sec_db"

		#Change the proxy account of copy job on Secondary Database.
		"$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d msdb -Q "EXEC msdb.dbo.sp_update_jobstep @job_name = N'LSCopy_Secondary_$sec_db',@step_id = 1,@proxy_name= 'mssql';"

		#Modify the instance name of all Log Shipping jobs on Primary Database.
		"$SQLCMD" -S $pri_svr_ip,$pri_db_port -U sa -P 8qllyhY -d msdb -Q "$sql_pri_inst_name"

		#Modify the instance name of all Log Shipping jobs on Secondary Database.
		"$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d msdb -Q "$sql_sec_inst_name"

		echo "######### End perform logshipping from $pri_svr_ip,$pri_db_port:$pri_db to $sec_svr_ip,$sec_db_port:$sec_db #########"

		let i++
	done
done

rm -f $0;
