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

	echo -e "################ $pri_svr_ip\t$pri_db_port\t:\t$pri_db_list"
    i=0
    for pri_db in ${arr_pri_db[@]}
    do
        sec_db=${arr_sec_db[i]}
		SQLCMD="/cygdrive/c/Program Files/Microsoft SQL Server/100/Tools/Binn/SQLCMD.EXE"

		sql_pri_log="set nocount on;
			declare @tbl_pri_db table(
				primary_id	varchar(64),
				primary_database	varchar(64),
				backup_directory	varchar(1024),
				backup_share	varchar(1024),
				backup_retention_period	varchar(64),
				backup_compression	varchar(8),
				backup_job_id	varchar(64),
				monitor_server	varchar(64),
				monitor_server_security_mode	varchar(8),
				backup_threshold	varchar(64),
				threshold_alert	varchar(1024),
				threshold_alert_enabled	varchar(8),
				last_backup_file	varchar(1024),
				last_backup_date	varchar(64),
				last_backup_date_utc	varchar(64),
				history_retention_period	varchar(64)
			);
			insert @tbl_pri_db exec sp_help_log_shipping_primary_database $pri_db;
			select
				REVERSE(LEFT(REVERSE(last_backup_file), CHARINDEX('\\', REVERSE(last_backup_file))-1)), 
            	REPLACE(CONVERT(varchar,CONVERT(datetime,last_backup_date,120),120),' ','_'),
				'chacha'
			from @tbl_pri_db;"
		
		sql_sec_log="set nocount on;
			declare @tbl_sec_db table(
				secondary_id	varchar(64),
				primary_server	varchar(64),
				primary_database	varchar(64),
				backup_source_directory	varchar(1024),
				backup_destination_directory	varchar(1024),
				file_retention_period	varchar(64),
				copy_job_id	varchar(64),
				restore_job_id	varchar(64),
				monitor_server	varchar(64),
				monitor_server_security_mode	varchar(8),
				secondary_database	varchar(64),
				restore_dalay	varchar(64),
				restore_all	varchar(8),
				restore_mode	varchar(8),
				disconnect_users	varchar(8),
				block_size	varchar(64),
				buffer_count	varchar(64),
				max_transfer_size	varchar(64),
				restore_threshold	varchar(64),
				threshold_alert	varchar(1024),
				threshold_alert_enabled	varchar(8),
				last_copied_file	varchar(1024),
				last_copied_date	varchar(64),
				last_copied_date_utc	varchar(64),
				last_restored_file	varchar(1024),
				last_restored_date	varchar(64),
				last_restored_date_utc	varchar(64),
				history_retention_period	varchar(64),
				last_restored_latency	varchar(64)
			);
			insert @tbl_sec_db exec sp_help_log_shipping_secondary_database $sec_db;
			select
				REVERSE(LEFT(REVERSE(last_copied_file), CHARINDEX('\\', REVERSE(last_copied_file))-1)), 
            	REPLACE(CONVERT(varchar,CONVERT(datetime,last_copied_date,120),120),' ','_'),
				REVERSE(LEFT(REVERSE(last_restored_file), CHARINDEX('\\', REVERSE(last_restored_file))-1)), 
            	REPLACE(CONVERT(varchar,CONVERT(datetime,last_restored_date,120),120),' ','_'),
				'chacha'
			from @tbl_sec_db;"
		
		sql_pri_row="USE $pri_db
			GO 
			CREATE TABLE #ls_row_num(
				tbl_name int,
				row_num bigint
			)
			EXEC sp_MsforeachTable 'INSERT #ls_row_num SELECT 1,COUNT(*) FROM ? WITH (NOLOCK);'
			SELECT COUNT(tbl_name),SUM(row_num)
			FROM #ls_row_num;
			DROP TABLE #ls_row_num;"

		sql_sec_row="USE $sec_db
			GO 
			CREATE TABLE #ls_row_num(
				tbl_name int,
				row_num bigint
			)
			EXEC sp_MsforeachTable 'INSERT #ls_row_num SELECT 1,COUNT(*) FROM ? WITH (NOLOCK);'
			SELECT COUNT(tbl_name),SUM(row_num)
			FROM #ls_row_num;
			DROP TABLE #ls_row_num;"

		rst_pri=`"$SQLCMD" -S $pri_svr_ip,$pri_db_port -U sa -P 8qllyhY -d master -W  -Q "$sql_pri_log" | grep chacha`
		rst_sec=`"$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d master -W  -Q "$sql_sec_log" | grep chacha`
		#echo -e "$rst_pri\n";
		#echo -e "$rst_sec\n";
		
		last_backup_file=`echo $rst_pri | awk '{print $1}'`
		last_backup_date=`echo $rst_pri | awk '{print $2}'`
		last_copied_file=`echo $rst_sec | awk '{print $1}'`
		last_copied_date=`echo $rst_sec | awk '{print $2}'`
		last_restored_file=`echo $rst_sec | awk '{print $3}'`
		last_restored_date=`echo $rst_sec | awk '{print $4}'`
		#echo -e "$last_backup_file\t$last_backup_date\t$last_copied_file\t$last_copied_date\t$last_restored_file\t$last_restored_date";

		rst_pri_row=`"$SQLCMD" -S $pri_svr_ip,$pri_db_port -U sa -P 8qllyhY -d master -W  -Q "$sql_pri_row" | grep chacha`
		rst_sec_row=`"$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d master -W  -Q "$sql_sec_row" | grep chacha`
		
		pri_tbl_num=`echo $rst_pri_row | awk '{print $1}'`
		pri_tbl_row=`echo $rst_pri_row | awk '{print $2}'`
		sec_tbl_num=`echo $rst_sec_row | awk '{print $1}'`
		sec_tbl_row=`echo $rst_sec_row | awk '{print $2}'`

		if [ "$last_backup_file" == "$last_copied_file" -a "$last_copied_file" == "$last_restored_file" ];then
			if [ "$pri_tbl_num" == "$sec_tbl_num" -a "$pri_tbl_row" == "$sec_tbl_row" ];then
				echo -e "###########\t$pri_db is " "\E[32;40m\033[4msynchronized\033[0m"
				echo -e "###########\tBACKUP: $last_backup_date\tCOPIED: $last_copied_date\tRESTORED: $last_restored_date"
			else
				echo -e "###########\t$pri_db is " "\E[31;40m\033[4mnot synchronized\033[0m"
				echo -e "###########\tPRIMARY: $pri_tbl_num\t$pri_tbl_row\tSECONDARY: $sec_tbl_num\t$sec_tbl_row"
			fi
		else
			echo -e "###########\t$pri_db is " "\E[31;40m\033[4mnot synchronized\033[0m"
			echo -e "###########\tBACKUP: $last_backup_file\tCOPIED: $last_copied_file\tRESTORED: $last_restored_file"
			echo -e "###########\tBACKUP: $last_backup_date\tCOPIED: $last_copied_date\tRESTORED: $last_restored_date"
		fi	
	
		let i++
	done
done

rm -f $0;
