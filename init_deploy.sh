#! /bin/bash
Date=`date +%F_%H-%M-%S`
path=$(cd `dirname $0`; pwd)
cat /tmp/.jenkins/deploy.conf | grep -v ^'#' | sed -e '/^$/d' >  /tmp/.jenkins/deploy.config

while read i ;do
        export "$i" 
done < /tmp/.jenkins/deploy.config

if [ $? -eq 0 ];then rm -f /tmp/.jenkins/deploy.config;fi

#===============
#  nfs 挂载
#===============
for plugin in ${Soft};do
	rpm -qa | grep ${plugin} &>/dev/null
	if [ $? -ne 0 ];then
		yum install -y ${plugin}
	fi
done
if [ $? -eq 0 ];then mount -t nfs ${nfs_ip}:${nfs_dir} ${war_data};fi
#===========
# 自定义变量
CLASSPATH=/${JAVA_HOME}/lib
PATH=${JAVA_HOME}/bin:$PATH
tomcat_start="${TOMCAT_HOME}/bin/catalina.sh start"
tomcat_stop="${TOMCAT_HOME}/bin/catalina.sh stop"
url='http://localhost:8080' # 可能需要修改
#===============
# 重新定义变量
#===============
app_name=${war_name}
mount_dir=${war_data}
APP_BAK="${war_bak_path}"
APP_NAME="${war_name}"
#================================
war_path=$(ls -1t `find "${war_data}"/"${JOB_HOME}" -name '*.war' -exec echo -e "{}\t\c"  \;` | grep ${app_name} | head -n 1)
war_all_name=$(echo "${war_path}" | awk -F '/' '{print $NF}')
war_version=$(echo "${war_all_name}" | awk -F '.war' '{print $1}')

# global
#=============================
global_env () {
                #sed -i "/JAVA_HOME=/d;/TOMCAT_HOME=/d;/PATH=/d;/LOG_HOME=/d" ${TOMCAT_HOME}/bin/catalina.sh
	grep ${TOMCAT_HOME} ${TOMCAT_HOME}/bin/catalina.sh &>/dev/null
	if [ $? -ne 0 ];then
                sed -i "/source.*\/etc\/profile$/d" ${TOMCAT_HOME}/bin/catalina.sh
		sed -i "2i export PATH=${JAVA_HOME}/bin:\$PATH" ${TOMCAT_HOME}/bin/catalina.sh
                sed -i "2i export CLASSPATH=${JAVA_HOME}/lib" ${TOMCAT_HOME}/bin/catalina.sh
                sed -i "2i export JAVA_HOME=${JAVA_HOME}" ${TOMCAT_HOME}/bin/catalina.sh
                sed -i "2i export TOMCAT_HOME=${TOMCAT_HOME}" ${TOMCAT_HOME}/bin/catalina.sh
                sed -i "2i export LOG_HOME=${TOMCAT_LOG_PATH}" ${TOMCAT_HOME}/bin/catalina.sh
	fi
		
}
[[ -d ${war_data} ]] || mkdir -p ${war_data}
[[ -d ${war_bak_path} ]] || mkdir -p ${war_bak_path}
[[ -d ${TOMCAT_LOG_PATH} ]] || mkdir -p ${TOMCAT_LOG_PATH}
if [ -f ${war_path} ] ;then 
	echo AA >/dev/null
else
	echo -e "\n\n*****\t${war_all_name}:   No such file or directory\t******\n\n"
	exit
fi

#if [ $# -lt 4 ];then
#       echo -e "\n-------------------------------------------------\n\n\t-- Usage:  ${0} Job_name app_name action rollback_version flag\n\n  -$'1'\tJenkins项目名\n  -$'2'\t发布war包名称\n  -$'3'\t确认执行update or rollback\n  -$'4'\t确认回退版本号\t\n\n--------------------------------------------------\n\n" && exit
#fi

#再次声明旧文件备份目录
backup_dir=${war_bak_path}
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

init_war_backup () {
[ -d ${war_bak_path} ] || mkdir -p ${war_bak_path}
judge=`ls -ld ${init_app_path}/${war_name}* | wc -l`
if [ ${judge} -eq 2 ];then
	old_war_name=$(cd ${init_app_path};ls -1td ${war_name}* | grep -v '*.war'| head -n 1)
	cd ${init_app_path}; tar zcf ${old_war_name}.bak${Date}.tgz   ./${old_war_name}*
	if [ $? -eq 0 ]
	then 
		cd ${init_app_path};mv ${old_war_name}.bak${Date}.tgz ${war_bak_path};
		cd ${init_app} ;rm -f current
		cd ${init_app_path}; rm -rf ${old_war_name}*  && echo -e "\n\n---------->\t${Date}\t<-------\n==::))\t${old_war_name}备份成功...\t((::==";
	else 
		echo -e "\n\n\n******\t ${war_name} is backup Failed.....\t****\n\n";exit
	fi
elif [ ${judge} -gt 2 ];then
	echo -e "\n\n\n******\tWarnning:  项目目录${init_app_path}下存在老版本垃圾war包未清理,不再进行备份...\t******\n\n\n详情如下:\n"
	ls -ld ${init_app_path}/${war_name}*
elif [ ${judge} -eq 0 ];then
	cd ${init_app};rm -f current
	echo -e "\n\n\n********\t\t${war_name}相关版本war包不存在,不再执行数据备份....\t\t*********\n\n\n";
fi
}

init_war_deploy () {
	cp ${war_path}  ${init_app_path};
	cd ${init_app_path}; unzip ${war_all_name} -d ${war_version} &>/dev/null && echo -e "\n\n\n unzip ${war_all_name}:  [\tOK\t]\n\n";
	if [ -f ${init_app}/current ];then
		echo -e "\n\n\n*******\ttomcat初始化失败,请重试\t*********\n\n"; rm -f ${init_app}/current;exit
	else 
		ln -s ${init_app_path}/${war_version} ${init_app}/current
	fi
	ps -ef |grep tomcat | grep -v grep | awk '{print $2}' >  /usr/local/bin/pid
	sudo -u root cat /usr/local/bin/pid | sort | uniq > /usr/local/bin/app.pid
 	while read Pid; do kill -9 ${Pid} && echo -e "\nkilled ${Pid}" ;done < /usr/local/bin/app.pid
	rm -f /usr/local/bin/pid /usr/local/bin/app.pid
	chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_HOME}
	chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_LOG_PATH}
	chown -R ${tomcat_user}:${tomcat_user} ${init_app}
	read -t 3
	sudo -u ${tomcat_user} ${tomcat_start}
		ps -ef | grep tomcat  
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
                echo -e "\n==\n====\n======\n\n------->\t${war_version} deploy is Successfulled\t<--------\n\n\n" ;break 
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
numr=${Rollback_version}
old_war_name=`cd ${init_app_path}; ls -1td ${war_name}*.war | head -n 1| awk -F '.war' '{print $1}'`
#开始清理最新数据
	cd ${init_app};rm -f current
	cd ${init_app_path}; rm -rf ./${old_war_name}*
#开始恢复备份数据
	[[ -f $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1) ]] || echo -e "\n\n\t****\t备份文件不存在,回滚失败...\t****\n\n"
	[[ -f $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1) ]] || exit
backupfile_name=$(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1)
	echo -e "\n\n\t---->\t开始恢复备份文件: $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1)...\t<----\n\n"
#   局部 
	tar xf  ${backupfile_name} -C ${init_app_path}/  &>/dev/null && echo -e "\n\n\n 解压 ${backupfile_name}:  [\tOK\t]\n\n";
	if [ -f ${init_app}/current ];then
                echo -e "\n\n\n*******\ttomcat初始化软连接失败,请重试\t*********\n\n"; rm -f ${init_app}/current;exit
        else
		app_rollback_version=$(cd /app/webapps/releases;ls -1t ${war_name}*war | awk -F '.war' '{print $1}')
		ln -s ${init_app_path}/${app_rollback_version} ${init_app}/current
		echo -e "\n\n\t 当前回退版本为: \n\t$(ls -ld ${init_app}/current)\n"
        fi
	ps -ef |grep tomcat | grep -v grep | awk '{print $2}' >  /usr/local/bin/pid
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
                echo -e "\n==\n====\n======\n\n------->\t${backupfile_name} rollback is Successfulled\t<--------\n\n\n" ;break
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
	global_env && Clean_backups && init_war_backup && init_war_deploy && health_check && Post_steps
;;
rollback)
	global_env && Rollback ${Rollback_version}
	Post_steps
;;
*)
	echo -e "\n\n\t----> Usage: ${0} project_name War_name confirm:(update/rollback)  Rollback_version\n\n"
	sudo umount ${mount_dir}
;;
esac






