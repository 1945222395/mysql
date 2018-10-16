#! /bin/bash

excel_path='/sq_data/excel'
Url=${1}

if [ $# -lt 2 ];then exit ;fi
#再次声明旧文件备份目录
backup_dir=/app/war_bak
# 最新的备份文件保留几份
files=2
#   备份
#=========
Clean_backups () {
        cd ${backup_dir}; Total=$(ls excel* | wc -l) ;Num=$((${Total} - ${files}))
        echo -e "\n\n====::))\t当前${backup_dir}下共计${Total}个备份文件\t((::====\n\n"
        if [ ${Num} -gt 0 ];then
                echo -e "\n\n******\t开始清理备份文件\t******\n\n"
                for file in $(cd ${backup_dir}; ls -1t excel* | tail -n ${Num});do echo -e "\n---\t${file} is deleted\t---\n";rm $file;done
        else
                echo -e "\n\n----\t${backup_dir}下备份文件数量小于${files}个,将不再进行清理...\t----\n\n"
        fi
}




backup () {
APP_BAK=/app/war_bak
APP_NAME=excel
	cd /sq_data; tar zcf excel-bak$(date +%F_%H-%M-%S).tgz excel
	cd /sq_data; mv excel-bak*.tgz /app/war_bak
	echo -e "\n当前所有备份文件对应序号如下:\n\n--------------------------\n"
	a1=0
	for i in `cd ${APP_BAK};ls -1t ${APP_NAME}*`
	do
		a1=$(( ${a1} + 1 )) 
		echo -e "\n${a1} :\t${i}\n"
	done
}


update () {
	rm -rf ${excel_path}
	mkdir -p ${excel_path}  
	cd ${excel_path} ; wget-proxy.sh -ftp "-c -r -np -nd -k -L -p ${Url}"  &>/dev/null
	if [ $? -ne 0 ];then
		cd ${excel_path}; wget-proxy.sh "-c -r -np -nd -k -L -p ${Url}" 
	else
		cd ${excel_path}; ls -lart
	fi
	chown -R appuser:appuser ${excel_path}
}

Clean_backups
backup
update

