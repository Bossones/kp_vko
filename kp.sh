#!/bin/bash

messagesDirectory='./messages'
commonLogFile='./logs/commonLog.txt'
rlsLogFile='./logs/rlsLog.txt'
zrdnLogFile='./logs/zrdnLog.txt'
sproLogFile='./logs/sproLog.txt'

rm $commonLogFile 2>/dev/null
rm $rlsLogFile 2>/dev/null
rm $zrdnLogFile 2>/dev/null
rm $sproLogFile 2>/dev/null

touch $commonLogFile
touch $rlsLogFile
touch $zrdnLogFile
touch $sproLogFile
mkdir "$messagesDirectory" 2>/dev/null

#$1 - наименование системы
function checkSystem() {
  if (( $# == 1 )); then
    echo "$(date) KP: Проверка работы системы $1" > $messagesDirectory/"check$1"
    echo "$(date) KP: Проверка работы системы $1" >> $commonLogFile
    sleep 2
    nameFile=$(ls $messagesDirectory | grep "answer$1" 2>/dev/null)
    if (( $? == 0 )); then
      echo "$(date) KP: Система $1 в норме" >> $commonLogFile
      rm $messagesDirectory/"$nameFile" 2>/dev/null
    else
      echo "$(date) KP: Система $1 не работоспособна" >> $commonLogFile
    fi
    rm $messagesDirectory/"check$1" 2>/dev/null
  fi
}

i=0
while :
do
  nameFile=$(ls -tr $messagesDirectory | head -n 1)
  echo "$nameFile" | grep RLS > /dev/null
  if (( $? == 0 )); then
    data=$(cat $messagesDirectory/"$nameFile")
    echo "$data" >> $commonLogFile
    echo "$data" >> $rlsLogFile
    rm $messagesDirectory/"$nameFile"
  fi

  echo "$nameFile" | grep ZRDN > /dev/null
  if (( $? == 0 )); then
    data=$(cat $messagesDirectory/"$nameFile")
    echo "$data" >> $commonLogFile
    echo "$data" >> $zrdnLogFile
    rm $messagesDirectory/"$nameFile"
  fi

  echo "$nameFile" | grep SPRO > /dev/null
  if (( $? == 0 )); then
    data=$(cat $messagesDirectory/"$nameFile")
    echo "$data" >> $commonLogFile
    echo "$data" >> $sproLogFile
    rm $messagesDirectory/"$nameFile"
  fi
  sleep 0.2

  ls $messagesDirectory | grep STOPALL 2>/dev/null 1>/dev/null
  if (( $? == 0 )); then
    echo "Завершаю работу системы КП"
    rm -rf "$messagesDirectory" 2>/dev/null
    exit 0
  fi

  ((i=i+1))
  if (( i == 1000 )); then
    checkSystem "RLS"
    checkSystem "ZRDN"
    checkSystem "SPRO"
  fi
done