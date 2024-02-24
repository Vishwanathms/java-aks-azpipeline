#!/bin/bash
ssh-keygen -t rsa -q -f "$HOME/.ssh/id_rsa" -N "" -f 
cat $HOME/.ssh/id_rsa >> $HOME/.ssh/authorized_keys
sudo apt install unzip -y 
touch inventory
echo "localhost" > inventory
#sshpass -p $1 ssh -o StrictHostKeychecking=no localhost
ssh-keyscan -t rsa localhost >> .ssh/known_hosts
exit
echo `ansible localhost -m ping` 

