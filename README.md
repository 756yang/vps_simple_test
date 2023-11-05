
# vps_simple_test

通过简单的命令测试VPS的性能，不影响VPS，仅使用coreutils

## 测试命令

请在本地Shell环境运行命令以执行测试：

	bash -c "$(wget -qO- https://github.com/756yang/vps_simple_test/raw/main/vpscore_test.sh)"

或者：

	bash -c "$(wget -qO- https://gitee.com/yang98586/vps_simple_test/raw/main/vpscore_test.sh)"

若要自动化测试(无需交互)，请设置SSH密钥以免密登录，执行以下命令：

	bash -c "$(wget -qO- https://gitee.com/yang98586/vps_simple_test/raw/main/vpscore_test.sh)" @ -n $USER@$vps_ip:$vps_port

此命令通过ssh执行远程命令进行测试，**请勿使用网络代理以免错误**，**请勿在服务器上执行以上命令**。


## 跑分说明

这个跑分主要以CPU多核性能为主，单核、内存、磁盘、网络性能计算为一个因数最终影响\
综合评分，标准的现代PC平台进行这项跑分，成绩大概是核心数乘超线程效率乘以20，\
大部分VPS使用较老平台，导致单核配置的VPS跑分只有10，由于超售等原因可能更低。

1.  CPU评分，将单核性能与标准性能相比之後开立方，此值乘以多核性能得之，标准的每核\
    CPU评分应是7，此评分与CPU核心数呈线性关系。
2.  MEM评分，根据CPU评分计算应该达到的参考内存性能，然後将内存性能量化到0~2之间的\
    数值并保证参考内存性能量化到1，此项会受物理机其他核心占用内存带宽影响。
3.  DISK评分，鉴于工具限制仅评价连续读写性能，读取性能的权值是写入性能的一倍，以\
    读写性能100M为标准将磁盘性能量化到0~2之间，量化算法和MEM评分一致。
4.  NET评分，通过本地ping服务器IP测试丢包率和延迟并大致计算平均响应时间，以延迟\
    100ms为标准将网络性能量化到0~2之间，延迟小与200ms时量化算法和MEM评分一致，\
    延迟大于200ms时，量化算法采用下降更快的方式以更快降低评分。
5.  综合评分，是四项评分的乘积，大概能衡量服务器的综合价值。

设计评分计算算法的时候是考虑到了不同机器的差异，应该可以在不同Linux机器上比较。

注意，网络性能是以延迟来计算，所以此跑分会因测试地区有较大变化，内存性能评分标准\
有利于核心数少的平台，这在VPS内存带宽竞争不严重时是没问题的。
