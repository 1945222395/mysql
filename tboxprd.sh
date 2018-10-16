#! /bin/bash

Url=${1}
jar_name=${2}
save_dir=${3}
group=${4}
[[ -d ${save_dir} ]]  || mkdir -p ${save_dir}
if [ $# -lt 4 ];then echo -e "\n\nUsage:\t$0 http://xxx xxx.jar bigDir/project\n\n  -$'1':\tftp网址\n  -$'2':\tjar包包名\n  -$'3':\tjar包本地保存目录\n  -$'4':\t主机组\n\n";exit;fi
rm -f ${save_dir}/${jar_name}
[[ -d ${save_dir} ]]  || mkdir -p ${save_dir}
chown appuser:appuser ${save_dir} -R
wget-proxy.sh -ftp "${Url} -P ${save_dir}"

fenfa-prd () {
	echo -e "\n\n正在分发jar包:\t${jar_name}"
        sudo -u  appuser ansible ${group} -m copy -a "src=${save_dir}/${jar_name} dest=/opt/cloudera/parcels/SPARK2/lib/spark2/jars/ mode=644" -u appuser --sudo
        if [ $? -eq 0 ];then
        echo -e "\njar包:\t${jar_name}分发成功\n\n"
        else
        echo -e "\njar包:\t${jar_name}分发失败\n\n"
        fi
}


fenfa-dev () {
for  i in `seq 104 111`
do
	echo -e "\n正在分发jar包:\t${jar_name} ----> 到主机10.32.47.$i\n\n"
	scp -P 17585 ${save_dir}/${jar_name} root@10.32.47.$i:/opt/cloudera/parcels/SPARK2/lib/spark2/jars/ && echo -e "\njar包:\t${jar_name}-->分发成功\n\n" || echo -e "\njar包:\t${jar_name}\t*******\t分发失败\t*********\n\n"
done
for  i in `seq 201 208`
do
	echo -e "\n正在分发jar包:\t${jar_name} ----> 到主机10.32.47.$i\n\n"
	scp -P 17585 ${save_dir}/${jar_name} root@10.32.47.$i:/opt/cloudera/parcels/SPARK2/lib/spark2/jars/ && echo -e "\njar包:\t${jar_name}-->分发成功\n\n" || echo -e "\njar包:\t${jar_name}\t*******\t分发失败\t*********\n\n"
done
}

fenfa-prd
