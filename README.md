
# vps_simple_test

通过简单的命令测试VPS的性能，不影响VPS，仅使用coreutils

请在本地Shell环境运行命令以执行测试：

	bash -c "$(wget -qO- https://github.com/756yang/vps_simple_test/raw/main/vpscore_test.sh)"

或者：

	bash -c "$(wget -qO- https://gitee.com/yang98586/vps_simple_test/raw/main/vpscore_test.sh)"

此命令通过ssh执行远程命令进行测试，**请勿使用网络代理以免错误**，**请勿在服务器上执行以上命令**。

建议设置好远程密钥登录SSH以免测试过程频繁输入密码。
