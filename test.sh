#! /bin/bash
a1=0
path=$(cd `dirname ${0}`; pwd)
for i in `cd ${path};ls -1t`
do
	a1=$(( ${a1} + 1 ))
	echo ${a1}
done
