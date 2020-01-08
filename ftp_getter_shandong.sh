#!/bin/sh
source ~/.bash_profile

#################################################################################
# vsersion V0.0.1
#############

#################################################################################
# 文件处理路径
# CYSDIR          彩印业务脚本主目录（cy=caiyin s=shell cys=caiyinshell）
# DOWNLOAD_DIR    对应的本地服务器下载目录 (可调整)           
# LOGDIR          日志目录 /home/cys/log/txcy/ (调整为微服务日志路径一致)
# LOGFILE         日志文件 /home/cys/txcy/log/txcy_log.20180118
# FLUME_ZP_DIR    flume 诈骗文件处理路径
# FLUME_BJ_DIR    flume 标记文件处理路径
################################

CYSDIR=$HOME/cys

DOWNLOAD_DIR=$CYSDIR/txcy/downLoad

LOGDIR=$CYSDIR/log/txcy
LOGFILE=${LOGDIR}/txcy_log.$(date +%Y%m%d)

FLUME_ZP_DIR=$HOME/zp
FLUME_BJ_DIR=$HOME/bj

#######################################################
#预处理，无日志目录创建日志目录
#重定向标准输出、错误输出到日志文件
##############
mkdir -p $CYSDIR
mkdir -p $DOWNLOAD_DIR
mkdir -p $LOGDIR

mkdir -p $FLUME_ZP_DIR
mkdir -p $FLUME_BJ_DIR

exec 1>>$LOGFILE
exec 2>>$LOGFILE

############################################
# 分区文件上传SFTP 服务器信息
# FTP_Protocol      文件传输协议
# IP                经分系统SFTP服务器地址
# PORT              SFTP端口号
# USER              SFTP用户名
# PWD               SFTP用户密码
# REMOTE_DIR        远程文件SFTP服务器目录
# RemoveSourceFlag  是否删除远程文件 --Remove-source-files:删除
# FILENAME          需要下载文件名 支持模糊匹配   默认格式：syncFuncBill*
##############
FTP_Protocol="sftp"
IP="10.1.62.220"
PORT="19222"
USER="ismp"
PWD="1qaz@WSX"
REMOTE_DIR=/home/ismp/mme
RemoveSourceFlag=""
FILENAME="syncFuncBill*"

############################################
# 补救文件下载
# NEWERTHAN     下载指定文件之后更新文件  默认为空 格式：--newer-than=20191218
##############
NEWERTHAN=""


############################################
#lftp 文件下载
#若配置FILENAME 则使用文件名模糊下载，否则使用 与远程文件比较，不存在则下载
#GETFILE存储下载文件名
#TXTLINE=1000000 单个文件行数 不能为空
###############
GETINFO=$CYSDIR/.1.log
GETFILE=$CYSDIR/.2.log
TXTLINE=1000000

:>$GETINFO
:>$GETFILE

echo "`date "+%Y-%m-%d %H:%M:%S"` start!"
echo "`date "+%Y-%m-%d %H:%M:%S"` FTP_Protocol:$FTP_Protocol"
echo "`date "+%Y-%m-%d %H:%M:%S"` IP:$IP"
echo "`date "+%Y-%m-%d %H:%M:%S"` PORT:$PORT"
echo "`date "+%Y-%m-%d %H:%M:%S"` USER:$USER"
echo "`date "+%Y-%m-%d %H:%M:%S"` PWD:$PWD"
echo "`date "+%Y-%m-%d %H:%M:%S"` REMOTE_DIR:$REMOTE_DIR"
echo "`date "+%Y-%m-%d %H:%M:%S"` RemoveSourceFlag:$RemoveSourceFlag"
echo "`date "+%Y-%m-%d %H:%M:%S"` DOWNLOAD_DIR:$DOWNLOAD_DIR"
echo "`date "+%Y-%m-%d %H:%M:%S"` FLUME_DIR:$FLUME_DIR"
echo "`date "+%Y-%m-%d %H:%M:%S"` FILENAME:$FILENAME"


if [ x"$NEWERTHAN" = x ]; then

lftp -p $PORT -u "$USER,$PWD"  -e "set net:timeout 10;set net:max-retries 5;set net:reconnect-interval-base 10;set net:reconnect-interval-multiplier 2;set net:reconnect-interval-max 90" $FTP_Protocol://$IP 1>>$GETINFO   <<FTPEOF 
#mirror -r -I $FILENAME $NEWERTHAN $REMOTE_DIR $DOWNLOAD_DIR  $RemoveSourceFlag
mirror  -r -I $FILENAME --only-newer --verbose $REMOTE_DIR $DOWNLOAD_DIR $RemoveSourceFlag
bye
FTPEOF

FTPresult=$?

else

lftp -p $PORT -u "$USER,$PWD"  -e "set net:timeout 10;set net:max-retries 5;set net:reconnect-interval-base 10;set net:reconnect-interval-multiplier 2;set net:reconnect-interval-max 90" $FTP_Protocol://$IP 1>>$GETINFO   <<FTPEOF
mirror -r -I $FILENAME $NEWERTHAN $REMOTE_DIR $DOWNLOAD_DIR  $RemoveSourceFlag
#mirror  -r -I $FILENAME --only-newer --verbose $REMOTE_DIR $DOWNLOAD_DIR $RemoveSourceFlag
bye
FTPEOF

FTPresult=$?

fi

if [ ! $FTPresult -eq 0 ]; then
   echo "FTPresult=$FTPresult" 
   exit $FTPresult
fi 
#下载文件处理
############################################
#1、获取文件名
###############
echo "`date "+%Y-%m-%d %H:%M:%S"` get file over!"

awk -F "\`" '{print $2}' $GETINFO|awk -F "'" '{print $1}' >>$GETFILE

cat $GETFILE|sed '/^$/d' 

############################################
#2、判断文件行数 
#若超过 拆分文件
###############

echo "`date "+%Y-%m-%d %H:%M:%S"` getfile :`wc -l GETFILE`"

for a in `cat $GETFILE`;
do

	linenum=`awk 'END{print NR}' $DOWNLOAD_DIR/$a  `
	echo "`date "+%Y-%m-%d %H:%M:%S"` file [$a] line:[$linenum]"
	if [[ $linenum -gt $TXTLINE ]] &&  [[ $a == "ZP" ]]; then
	 	split -l $TXTLINE $DOWNLOAD_DIR/$a -d -a 4 $FLUME_ZP_DIR"/$(date +%s%N)_"
	else if [[ $linenum -gt $TXTLINE ]] &&  [[ $a == "SR" ]]; then
		split -l $TXTLINE $DOWNLOAD_DIR/$a -d -a 4 $FLUME_BJ_DIR"/$(date +%s%N)_"
	else if [[ $a == "ZP" ]]; then
	 	cp $DOWNLOAD_DIR/$a $FLUME_ZP_DIR"/$(date +%s%N)_0000"
	else
		cp $DOWNLOAD_DIR/$a $FLUME_BJ_DIR"/$(date +%s%N)_0000"
	 	
	fi
done



