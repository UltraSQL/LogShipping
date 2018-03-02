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
		SQLCMD="/cygdrive/c/Program Files/Microsoft SQL Server/100/Tools/Binn/SQLCMD.EXE"
		"$SQLCMD" -S $sec_svr_ip,$sec_db_port -U sa -P 8qllyhY -d msdb -Q "RESTORE DATABASE $sec_db WITH RECOVERY;"
		let i++
	done
done

rm -f $0;
