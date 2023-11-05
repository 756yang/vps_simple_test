#!/bin/bash

read -p "please input you server address:port ? " myserver
read -p "please input you server username? " username
mysshport=${myserver##*:}
myserver=${myserver%:*}
logmyserver="ssh $username@$myserver -p $mysshport"

checkcmd_install='
	while [ $# -gt 0 ]; do
		if ! which $1 >/dev/null 2>&1; then
			if ! ls /usr/sbin/$1 >/dev/null 2>&1; then
				if [[ "$(cat /proc/version)" =~ Debian ]]; then
					sudo apt install $1
				else
					echo "You have not install pkg: $1"
					exit 1
				fi
			fi
		fi
		shift
	done
'

# 检查本地运行需要的软件包
bash -c "$checkcmd_install" @ curl grep awk
[ $? -ne 0 ] && exit 1

# 检查远程服务器需要的软件包
IFS='' read -r -d '' SSH_COMMAND <<EOT
function checkcmd_install {$checkcmd_install}
checkcmd_install grep openssl bc wget
EOT
$logmyserver -t "$SSH_COMMAND"
[ $? -ne 0 ] && exit 1

function deal_unit ()
{
	awk '{
		for(i=1;i<=NF;i++){
			val=$i+0;
			where=match($i,"[^0-9.]");
			if(where!=0){
				unit=substr($i,where,1);
				if(unit ~ "[Kk]")val*=1024;
				if(unit ~ "[Mm]")val*=1024*1024;
				if(unit ~ "[Gg]")val*=1024*1024*1024;
			}
			printf("%f\n",val);
		}
	}'
}

# 综合测试服务器的性能并输出评分
# muticpu*cbrt(onecpu)*y(centermem)*y(diskseq)*q(netdelay)
# y=(x/m)^mk,x<=m;;2-(m/x)^mk,x>m
# q=2-(x/m)^mk,x<=m;;(m/x)^mk,x<=2m;;(m/x)^((x-m)/m),x>2m
# 丢包率p，延迟t，那么平均响应T=t*(5/(1-p)-4)


echo "--------------------- Linux VPS simple benchmark ---------------------"

# 测试单核CPU性能，处理数据越多性能越强
single_cpu=$($logmyserver openssl speed -bytes 16384 md5 | grep "^md5")
echo "Single CPU: $single_cpu"
single_cpu=$(echo "$single_cpu" | awk '{print $2}' | deal_unit)

# 测试多核CPU性能，数字越大性能越强
IFS='' read -r -d '' SSH_COMMAND <<'EOT'
(threads=$(cat /proc/cpuinfo | grep "processor"| wc -l)
for((i=0;i<$threads;i++)); do
	time -p (echo "scale=5000; 4*a(1)" | bc -l >/dev/null) 2>> calc_pi &
done;wait)
cat calc_pi | grep real | awk '{a+=1/$2}END{printf("%f\n",a*100)}' && rm calc_pi
EOT
multi_cpu=$($logmyserver "$SSH_COMMAND")
echo "Multiple CPU: bc_pi $multi_cpu"


read -p "MEM_EAT must test on the new machine to avoid anomalies!
Do you need to perform this test? (N|y) " ans
if [ "$ans" = y -o "$ans" = Y ]; then
	# 测试能够获取到多少真实内存，请在初始系统下测试
	IFS='' read -r -d '' SSH_COMMAND <<'EOT'
	(function mem_bin_search {
		j=$[($1+$2)/2]
		[ $1 = $j ] && {
			echo "you could eat ${i}M memory!"
			return
		}
		if dd if=/dev/zero of=/dev/null bs=${j}M count=1 2>/dev/null; then
			mem_bin_search $j $2
		else
			mem_bin_search $1 $j
		fi
	}
	sudo swapoff -a
	for ((i=64;;i+=i)); do
		dd if=/dev/zero of=/dev/null bs=${i}M count=1 2>/dev/null || break
	done
	mem_bin_search $[$i/2] $i
	sudo swapon -a)
EOT
	$logmyserver -t "$SSH_COMMAND"
fi

# 测试内存读写性能，真实读或写性能是此数值的两倍多点
speed_mem=$($logmyserver dd if=/dev/zero of=/dev/zero bs=128M count=500 2>&1 | grep copied)
echo "Speed MEM: $speed_mem"
speed_mem=$(echo "$speed_mem" | awk '{print $(NF-1) $NF}' | deal_unit)


# 测试CPU、内存、管道，综合性能
echo -n "Compose CPU,MEM,pipe: "
$logmyserver "dd if=/dev/zero bs=128M count=100 | md5sum" 2>&1 | grep copied


# 测试硬盘连续写入性能
disk_write=$($logmyserver dd if=/dev/zero of=test.iso bs=1M count=2048 conv=fdatasync 2>&1 | grep copied)
echo "Disk write: $disk_write"
disk_write=$(echo "$disk_write" | awk '{print $(NF-1) $NF}' | deal_unit)
# 测试硬盘连续读取性能
disk_read=$($logmyserver "dd if=test.iso of=/dev/zero bs=1M count=2048 iflag=direct && rm test.iso" 2>&1 | grep copied)
echo "Disk read: $disk_read"
disk_read=$(echo "$disk_read" | awk '{print $(NF-1) $NF}' | deal_unit)


# 测试服务器延迟和丢包率，$myserver是目的地公网IP地址
ping_cmd='ping $@'
cat /proc/version | grep -E "MINGW|MSYS" && {
	# 在MSYS环境中使用ping3命令代替
	if ! ls /usr/bin/ping3 >/dev/null 2>&1; then
		pacman -S --needed python python-pip
		python3 -m pip install ping3
	fi
	pacman -S --needed expect # 提供unbuffer以取消管道缓存
	IFS='' read -r -d '' ping_cmd <<'EOT'
eval addr=\${$#}
unbuffer ping3 $@ | awk -v addr=$addr 'BEGIN{time=systime();rtt_min=2147483647;rtt_max=0} {
	print $0;
	if(index($0,"Timeout")!=0)loss++;
	else{
		reach++;
		cur_rtt=$NF+0;
		if(cur_rtt<rtt_min)rtt_min=cur_rtt;
		if(cur_rtt>rtt_max)rtt_max=cur_rtt;
		sum_rtt+=cur_rtt;
		sum_rttsqr+=cur_rtt*cur_rtt;
	}
	count++;
} END{
	time=(systime()-time)*1000;
	loss=loss/count*100;
	rtt_avg=sum_rtt/reach;
	rtt_mdev=sum_rttsqr/reach;
	rtt_mdev=sqrt(rtt_mdev-rtt_avg*rtt_avg);
	printf("\n--- %s ping statistics ---\n",addr);
	printf("%d packets transmitted, %d received, %.2f%% packet loss, time %dms\n",count,reach,loss,time);
	printf("rtt min/avg/max/mdev = %d/%.2f/%d/%.2f ms\n",rtt_min,rtt_avg,rtt_max,rtt_mdev);
}'
EOT
}
ping_delay=$(bash -c "$ping_cmd" @ -c 100 -i 0.01 $myserver | tail -n 3)
echo "Ping echo: $ping_delay"
ping_loss=$(echo "$ping_delay" | grep loss | awk -F , '{print $3+0}')
ping_delay=$(echo "$ping_delay" | grep rtt | awk -F / '{print $5}')


read -p "Backtrace route test will download executable from Internet!
Do you need to perform this test? (N|y) " ans
if [ "$ans" = y -o "$ans" = Y ]; then
	# 获取本地公网IP
	#public_ip=$(curl cip.cc 2>/dev/null | grep IP | awk '{print $3}')
	public_ip=$(curl ifconfig.me)
	# 三网回程路由测试
	IFS='' read -r -d '' SSH_COMMAND <<EOT
bash -c "\$(wget -qO- https://github.com/756yang/besttrace_shell/raw/master/autoBestTrace.sh)" @ $public_ip
EOT
	$logmyserver -t "$SSH_COMMAND"
fi



# 开始进行评分计算
# single_cpu, multi_cpu, speed_mem, disk_write, disk_read, ping_delay, ping_loss

# 计算CPU评分的贡献值
cpu_score=$(awk -v m=$[834*1024*1024] -v k=3 -v sc=$single_cpu -v mc=$multi_cpu 'BEGIN{printf("%f\n",mc*exp(log(sc/m)/k));exit}')

# 计算内存评分的贡献值
mem_score=$(awk -v m=$[108*1024*1024] -v k=2 -v cpu=$cpu_score -v mem=$speed_mem 'BEGIN{
	m*=cpu;
	if(mem<=m)score=exp(k*log(mem/m));
	else score=2-exp(k*log(m/mem));
	printf("%f\n",score);
exit}')

# 计算磁盘评分的贡献值
disk_score=$(awk -v dread=$disk_read -v dwrite=$disk_write 'BEGIN{printf("%f\n",2*dread+dwrite);exit}')
disk_score=$(awk -v m=$[300*1024*1024] -v k=2 -v score=$disk_score 'BEGIN{
	if(score<=m)score=exp(k*log(score/m));
	else score=2-exp(k*log(m/score));
	printf("%f\n",score);
exit}')

# 计算网络评分的贡献值
ping_delay=$(awk -v rtt=$ping_delay -v loss=$ping_loss 'BEGIN{printf("%f\n",rtt*(5/(1-loss/100)-4));exit}')
net_score=$(awk -v m=100 -v k=1 -v rtt=$ping_delay 'BEGIN{
	if(rtt<=m)score=2-exp(k*log(rtt/m));
	else if(rtt<=2*m)score=exp(k*log(m/rtt));
	else score=exp((x-m)/m*log(m/rtt));
	printf("%f\n",score);
exit}')

# 输出总评分
echo "----------------------------------------------------------------------"
echo -n "You remote machine scores is: "
awk -v cpu=$cpu_score -v mem=$mem_score -v disk=$disk_score -v net=$net_score 'BEGIN{print cpu*mem*disk*net;exit}'

