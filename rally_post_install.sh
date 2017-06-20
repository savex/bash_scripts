echo "alias env_rally='source /root/myrally/bin/activate'" >>~/.bashrc
source ~/.bashrc
env_rally
rally-manage db recreate