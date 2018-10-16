#! /bin/bash
Date=`date +%F_%H-%M-%S`

if [ $# -lt 4 ];then
        echo -e "\n-------------------------------------------------\n\n\t-- Usage:  ${0} Job_name app_name action rollback_version flag\n\n  -$'1'\tJenkins项目名\n  -$'2'\t发布zip包名称\n  -$'3'\t确认执行update or rollback\n  -$'4'\t确认回退版本号\t\n\n--------------------------------------------------\n\n" && exit
fi
#===============
#  nfs 挂载
#===============
nfs_ip='10.133.115.244'  # 可能需要修改
nfs_dir='/app/public'  # 可能需要修改
zip_data="/srv" # 可能需要修改
zip_bak_path='/app/zip_bak' # 可能需要修改
	nfs_judge=`rpm -qa | grep nfs-utils &>/dev/null && rpm -qa | grep rpcbind &>/dev/null && echo 1 || echo 0`
	if [ ${nfs_judge} -eq 0 ];then yum install -y nfs-utils rpcbind || exit;fi
	mount -t nfs ${nfs_ip}:${nfs_dir} ${zip_data}
#=============
#定义全局变量
#=============

export JAVA_HOME=/usr/local/jdk
export CLASSPATH=$JAVA_HOME/lib
export PATH=$PATH:$JAVA_HOME/bin
export TOMCAT_HOME=/usr/local/tomcat
export TOMCAT_LOG_PATH=/app/logs/tomcat
#================
# 定义tomcat变量
#================
tomcat_user='appuser'
tomcat_start='/usr/local/tomcat/bin/catalina.sh start'
tomcat_stop='/usr/local/tomcat/bin/catalina.sh stop'
url='http://localhost:8080' # 可能需要修改

#======================================
# 定义最新zip包存储目录及zip包名称获取
#======================================
job_name="${1}"
zip_name="${2}"
confirm_action="${3}"
Rollback_version="${4}"
zip_path="${zip_data}/${job_name}"
zip_all_name=`cd  ${zip_path};ls -1t *.zip | head -n1`
zip_version=`echo ${zip_all_name} | awk -F '.zip' '{print $1}'`

#==========================
# 以下为可能需要修改的变量
#==========================

init_app_path="/app/webapps/releases"  
init_app="/app/webapps"  
# 获取项目名称

[[ -d ${zip_data} ]] || mkdir -p ${zip_data}
[[ -d ${zip_bak_path} ]] || mkdir -p ${zip_bak_path}
[[ -d ${TOMCAT_LOG_PATH} ]] || mkdir -p ${TOMCAT_LOG_PATH}
[[ -f ${zip_path}/${zip_all_name} ]] || echo -e "\n\n*****\t${zip_all_name}:   No such file or directory\t******\n\n"
[[ -f ${zip_path}/${zip_all_name} ]]  || exit

#再次声明旧文件备份目录
backup_dir=${zip_bak_path}
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
#==========================
#初始化版tomcat部署过程
#==========================

init_zip_backup () {
[ -d ${zip_bak_path} ] || mkdir -p ${zip_bak_path}
judge=`ls ${init_app_path}/${zip_name}*.zip | wc -l`
if [ ${judge} -gt 0 ];then
	old_zip_name=`cd ${init_app_path}; ls ${zip_name}*.zip | awk -F '.zip' '{print $1}'`
	cd ${init_app_path}; tar zcf ${old_zip_name}.bak${Date}.tgz   ./${old_zip_name}*
	if [ $? -eq 0 ]
	then 
		cd ${init_app_path};mv ${old_zip_name}.bak${Date}.tgz ${zip_bak_path};
		cd ${init_app_path};cd ../;rm -f current
		cd ${init_app_path}; rm -rf ./${old_zip_name}* && echo -e "\n\n---------->\t${Date}\t<-------\n\==::))\t${old_zip_name}备份成功...\t((::==";
	else 
		echo -e "\n\n\n******\t ${old_zip_name} is backup Failed.....\t****\n\n"
	fi
else
	cd ${init_app_path};cd ../;rm -f current
	echo -e "\n\n\n********\t\t${zip_name}相关版本zip包不存在,不再执行数据备份....\t\t*********\n\n\n";
fi
}

init_zip_deploy () {
	cd ${zip_path} ; cp ${zip_all_name} ${init_app_path};
	cd ${init_app_path}; unzip ${zip_all_name} -d ${zip_version} &>/dev/null && echo -e "\n\n\n unzip ${zip_all_name}:  [\tOK\t]\n\n";
	ln -s ${init_app_path}/${zip_version} ${init_app}/current
	ps -ef |grep tom | grep -v grep | awk '{print $2}' >  /usr/local/bin/pid
	sudo -u root cat /usr/local/bin/pid | sort | uniq > /usr/local/bin/kaleido.pid
 	while read kaleido_pid; do kill -9 ${kaleido_pid} && echo -e "\nkilled ${kaleido_pid}" ;done < /usr/local/bin/kaleido.pid
	chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_HOME}
	chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_LOG_PATH}
	chown -R ${tomcat_user}:${tomcat_user} ${init_app}
	read -t 3
	sudo -u ${tomcat_user} ${tomcat_start}
		ps -ef | grep tomcat  
}




#=== 回退变量====

mount_dir=${zip_data}
APP_BAK="${zip_bak_path}"
APP_NAME="${zip_name}"

#  健康检查
#===========

health_check () {
for i in `seq 1 6`
do
        read -t ${i}
        echo -e "\n\n====::))\tstarting health check for ${i}\t((::====\n\n"
        timeout 10s curl ${url} --head -s 
        if [ $? -eq 0 ];then
                echo -e "\n==\n====\n======\n\n------->\t${zip_version} deploy is Successfulled\t<--------\n\n\n" ;break 
        elif [ $? -ne 0 ];then
                if [ ${i} -eq 6 ];then
                        echo -e "\n\n\t---->\t${zip_all_name}应用发布失败,即将开始回滚...\t<----\n\n"
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
old_zip_name=`cd ${init_app_path}; ls ${zip_name}*.zip | awk -F '.zip' '{print $1}'`
#开始清理最新数据
        cd ${init_app_path};cd ../;rm -f current
        cd ${init_app_path}; rm -rf ./${old_zip_name}*
#开始恢复备份数据
        [[ -f $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1) ]] || echo -e "\n\n\t****\t备份文件不存在,回滚失败...\t****\n\n"
        [[ -f $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1) ]] || exit
backupfile_name=$(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1)
        echo -e "\n\n\t---->\t开始恢复备份文件: $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1)...\t<----\n\n"
#   局部 
        tar xf  ${backupfile_name} -C ${init_app_path}/  &>/dev/null && echo -e "\n\n\n 解压 ${backupfile_name}:  [\tOK\t]\n\n";
        ln -s ${init_app_path}/${zip_version} ${init_app}/current
        ps -ef |grep tom | grep -v grep | awk '{print $2}' >  /usr/local/bin/pid
        sudo -u root cat /usr/local/bin/pid | sort | uniq > /usr/local/bin/deploy.pid
        while read init_pid; do kill -9 ${init_pid} && echo -e "\nkilled ${init_pid}" ;done < /usr/local/bin/deploy.pid
        chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_HOME}
        chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_LOG_PATH}
        chown -R ${tomcat_user}:${tomcat_user} ${init_app}
        read -t 3
        sudo -u ${tomcat_user} ${tomcat_start}
                ps -ef | grep tomcat  
# ==== 再次进行健康检查 =====
        for i in `seq 1 6`
        do
                read -t ${i}
                echo -e "\n\n====::))\tstarting health check for ${i}\t((::====\n\n"
        timeout 10s curl ${url} --head -s 
        if [ $? -eq 0 ];then
                echo -e "\n==\n====\n======\n\n------->\t${zip_version} deploy is Successfulled\t<--------\n\n\n" ;break
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
        Clean_backups && init_zip_backup && init_zip_deploy && health_check && Post_steps
;;
rollback)
        Rollback ${Rollback_version}
        Post_steps
;;
*)
        echo -e "\n\n\t----> Usage: ${0} project_name War_name confirm:(update/rollback)  Rollback_version\n\n"
        sudo umount ${mount_dir}
;;
esac






