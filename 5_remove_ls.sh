#!/bin/sh

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

sql_pri_rm_ls="
-- Removes the entry for a secondary database on the primary server.
EXEC master.dbo.sp_delete_log_shipping_primary_secondary
	@primary_database = N'$pri_db'
	,@secondary_server = N'$sec_svr_ip,$sec_db_port'
	,@secondary_database = N'$sec_db'

-- Removes log shipping of primary database including backup job as well as local and remote history.
EXEC master.dbo.sp_delete_log_shipping_primary_database
	@database = N'$pri_db'
GO
"

sql_sec_rm_ls="
-- Removes a secondary database and removes the local history and remote history.
EXEC master.dbo.sp_delete_log_shipping_secondary_database
	@secondary_database = N'$sec_db'

-- Removes the information about the specified primary server from the secondary server,
-- and removes the copy job and restore job from the secondary.	
EXEC master.dbo.sp_delete_log_shipping_secondary_primary
	@primary_server = N'$pri_svr_ip,$pri_db_port'
	,@primary_database = N'$pri_db'
GO
"

		SQLCMD="/cygdrive/c/Program Files/Microsoft SQL Server/100/Tools/Binn/SQLCMD.EXE"
		"$SQLCMD" -S $pri_svr_ip,$pri_db_port -U sa -P 8qllyhY -d msdb -Q "$sql_pri_rm_ls"
		"$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d msdb -Q "$sql_sec_rm_ls"
		"$SQLCMD" -S $pri_svr_ip,$pri_db_port -U sa -P 8qllyhY -d msdb -Q "EXEC master.sys.xp_cmdshell 'DEL /F D:\LS_Primary\\$pri_db_port\*.trn && DEL /F D:\LS_Primary\\$pri_db_port\*.bak'"
		find /cygdrive/d/LS_Secondary/$sec_db_port/[$pri_svr_ip][$pri_db_port]/ -name "*.trn" -or -name "*.bak" | xargs rm

		let i++
	done
done

rm -f logshipping.config

rm -f $0;
