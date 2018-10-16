#! /bin/bash

if [ $# -lt 4 ];then
        echo -e "\n-------------------------------------------------\n\n\t-- Usage:  ${0} project_name action rollback_version flag\n\n  -$'1'\t项目包名\n  -$'2'\t确认执行update or rollback\n  -$'3'\t确认回退版本号\t\n\n--------------------------------------------------\n\n" && exit
fi
#===============
#  nfs 挂载
#===============
nfs_ip='10.133.115.244'  # 可能需要修改
nfs_dir='/app/public'  # 可能需要修改
war_data="/srv" # 可能需要修改
war_bak_path='/app/app_bak' # 可能需要修改
	nfs_judge=`rpm -qa | grep nfs-utils &>/dev/null && rpm -qa | grep rpcbind &>/dev/null && echo 1 || echo 0`
	if [ ${nfs_judge} -eq 0 ];then yum install -y nfs-utils rpcbind || exit;fi
	mount -t nfs ${nfs_ip}:${nfs_dir} ${war_data}


#===================
#   全局变量 
#===================

DATE=`date +%F_%H:%M:%S`
nfs_path=/srv
project_name="${1}"
confirm_action="${2}"
Rollback_version="${3}"

#==================
#可更改变量
#==================

app_path=/app
app_name='sales_qna_deployment'
app_bak='/app/bak_assistant'
app_start='bash service.sh start' 
app_stop='bash service.sh stop' 
url='localhost:8081'
progress='/usr/local/Anaconda3/bin/python'
[[ -d ${app_bak} ]] || mkdir -p ${app_bak}
#===== 回退变量 ===

mount_dir=${war_data}
APP_BAK="${app_bak}"
APP_NAME="${app_name}"

#再次声明旧文件备份目录
backup_dir=${app_bak}
# 最新的备份文件保留几份
files=10
#   备份
#=========
Clean_backups () {
	cd ${backup_dir}; Total=$(ls | wc -l) ;Num=$((${Total} - ${files}))
	echo -e "\n\n====::))\t当前${backup_dir}下共计${Total}个备份文件\t((::====\n\n"
	if [ ${Num} -gt 0 ];then
		echo -e "\n\n******\t开始清理备份文件\t******\n\n"
		for file in $(cd ${backup_dir}; ls -1t | tail -n ${Num});do echo -e "\n---\t${file} is deleted\t---\n";rm $file;done
	else 
		echo -e "\n\n----\t${backup_dir}下备份文件数量小于${files}个,将不再进行清理...\t----\n\n"
	fi
}

APP_backup () {
	cd ${app_path}; ls ${app_name} &>/dev/null && export bkd=1 || export bkd=0
if [ ${bkd} -eq 1 ];then
	cd ${app_path};tar zcf ${app_bak}/${app_name}bak${DATE}.tgz ${app_name}*
	[[ -f ${app_bak}/${app_name}bak${DATE}.tgz ]] && export bk=1 || export bk=0
	if [ ${bk} -eq 1 ];then
		echo -e "\n\n=======::))\t${app_name}备份成功, 备份文件为:   ${app_name}bak${DATE}.tgz\t((::=========\n\n"
		rm -rf ${app_path}/${app_name}*
	elif [ ${bk} -eq 0 ];then
		echo -e "\n\n*************\t${app_name}备份失败,任务即将退出,请检查后重试....\t*************\n\n"
	fi
elif [ ${bkd} -eq 0 ];then
	echo -e "\n\n=======::))\t${app_name}文件不存在,不再执行数据备份......\t((::=========\n\n"
fi
		
		
}

#   更新
#=========

APP_update () {
	ls ${app_path}/${app_name}* &>/dev/null
	if [ $? -ne 0 ];then 
		cd ${nfs_path}; cp -a ${project_name} ${app_path}/${app_name}
		cd ${app_path}; ls ${app_name} &>/dev/null 
		if [ $? -eq 0 ];then
			echo -e "\n\n====::))\t${app_name} -----> 更新完成,即将启动...\t((::===="
		elif [ $? -ne 0 ];then
			echo -e "\n\n***********\t在${app_path}路径下${app_name} 不存在,请检查后重试....\t***************"; exit
		fi
	else
		echo -e "\n\n***********\t在${app_path}路径下,环境未清理,任务即将退出....\t***************"; exit
		
	fi
}

#  启动
#=======

APP_start () {

	echo -e "\n\n======::))\t正在停止 ${app_name}服务...\t((::=======\n\n"
	cd ${app_path}/${app_name}; ${app_stop}
	echo -e "\n\n=====::))\t再次killed ${app_name}服务,所有进程....\t((::======\n\n"
	ps -ef |grep ${progress} | grep -v grep | awk '{print $2}' >  /usr/local/bin/pid
        sudo -u root cat /usr/local/bin/pid | sort | uniq > /usr/local/bin/delete.pid
        while read delete_pid; do kill -9 ${delete_pid} && echo -e "\nkilled ${delete_pid}" ;done < /usr/local/bin/delete.pid
	echo -e "\n\n=====::))\t开始启动${app_name}服务\t((::======\n\n"	
	cd ${app_path}/${app_name}; ${app_start}
}

#  健康检查
#===========

health_check () {
for i in `seq 1 6`
do
        read -t ${i}
        echo -e "\n\n====::))\tstarting health check for ${i}\t((::====\n\n"
        timeout 10s curl ${url} --head -s 
        if [ $? -eq 0 ];then
                echo -e "\n==\n====\n======\n\n------->\t${project_name} deploy is Successfulled\t<--------\n\n\n" ;break 
        elif [ $? -ne 0 ];then
                #echo -e "\n\n\n*******\t\t${project_name}   deploy is failed\t********\n\n";
		if [ ${i} -eq 6 ];then
			echo -e "\n\n\t---->\t应用发布失败,即将开始回滚...\t<----\n\n"
			Rollback 1
		fi
			
        fi
done
}
#======= 回退 ========

Rollback () {
#    Global 
#numr=${Rollback_version}
numr=${1}
#开始清理最新数据
	rm -rf ${app_path}/${app_name}*
#开始恢复备份数据
	[[ -f $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1) ]] || echo -e "\n\n\t****\t备份文件不存在,回滚失败...\t****\n\n"
	[[ -f $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1) ]] || exit
	echo -e "\n\n\t---->\t开始恢复备份文件: $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1)...\t<----\n\n"
#   局部 
	ls ${app_path}/${app_name}* &>/dev/null
	if [ $? -ne 0 ];then 
		cd ${app_bak}; tar xf $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1)  -C  ${app_path}/
		cd ${app_path}; ls ${app_name} &>/dev/null 
			if [ $? -eq 0 ];then
				echo -e "\n\n====::))\t${app_name} -----> 恢复完成,即将启动...\t((::===="
				APP_start
				
			elif [ $? -ne 0 ];then
				echo -e "\n\n***********\t在${app_path}路径下${app_name} 不存在,请检查后重试....\t***************"; exit
			fi
	else
		echo -e "\n\n***********\t在${app_path}路径下,环境未清理,任务即将退出....\t***************"; exit
		
	fi

# ==== 再次进行健康检查 =====
        for i in `seq 1 6`
        do
                read -t ${i}
                echo -e "\n\n====::))\tstarting health check for ${i}\t((::====\n\n"
        timeout 10s curl ${url} --head -s 
        if [ $? -eq 0 ];then
                echo -e "\n==\n====\n======\n\n------->\t${project_name} deploy is Successfulled\t<--------\n\n\n" ;break
        else
                if [ ${i} -eq 6 ];then
                        echo -e "\n\n\t---->\t${APP_NAME}回滚失败，请手动恢复后重试...\t<----\n\n"
                fi

        fi
done
}

# 构建后操作
Post_steps () {

	echo -e "\n当前所有备份文件对应序号如下:\n\n--------------------------\n"
	a1=0
	for i in `cd ${APP_BAK};ls -1t ${APP_NAME}*`
	do
		a1=$(( ${a1} + 1 )) 
		echo -e "\n${a1} :\t${i}\n"
	done
	sudo umount ${mount_dir}	
}



case ${confirm_action} in
update)
	Clean_backups && APP_backup && APP_update && APP_start && health_check && Post_steps
;;
rollback)
	Rollback ${Rollback_version}
	Post_steps
;;
*)
	echo -e "\n\n\t----> Usage: ${0} project_name confirm:(update/rollback)  Rollback_version\n\n"
	sudo umount ${mount_dir}
;;
esac






















