#!/bin/bash
declare r_distance
declare x_c
declare y_c
declare x_st
declare y_st
declare currentId
declare -a statuses
declare -a ammos
tempTargetDirectory='../temp/targets/zrdn'
targetsDirectory='/tmp/GenTargets/Targets'
destroyTargetDirectory='/tmp/GenTargets/Destroy'
messagesDirectory='../messages'
declare -a hashIds

#Проверка сгенерированной цели на вхождение в сектор зоны действия ЗРДН
function checkTarget() {
      local distanceBetweenTargetStation

      distanceBetweenTargetStation=$(echo "sqrt(($x_c - $x_st)^2 + ($y_c - $y_st)^2)" | bc)
      distanceBetweenTargetStation=${distanceBetweenTargetStation/\.*}

      if (( distanceBetweenTargetStation > r_distance))
      then
        echo "1"
      else
        echo "0"
      fi
}

function tryToDestroy() {
    if (( $# == 3 )); then
      local destroyProbability
      local destroyedTarget
      local boezap

      boezap=${ammos[$2]}
      destroyProbability=$(echo | awk "{srand($(date +%N));res=rand()%100; print res}")
      destroyedTarget=$(echo | awk "{res=$destroyProbability<0.8; print res}")

      echo "$(date) ZRDN $2: Цель ID: $1 осуществлен выстрел по цели тип: $3. Боезапас: $boezap" > $messagesDirectory/"$1"ZRDNV
      if (( boezap != 0 )); then
        if (( destroyedTarget == "1" )); then
          echo "$(date) ZRDN $2: Цель ID: $1 поражена тип: $3" > $messagesDirectory/"$1"ZRDN
          echo "$(date) ZRDN $2: Цель ID: $1 поражена тип: $3" > $destroyTargetDirectory/$1
        else
          echo "$(date) ZRDN $2: Цель ID: $1 не поражена (промах) тип: $3" > $messagesDirectory/"$1"ZRDN
        fi
      else
        echo "$(date) ZRDN $2: Цель ID: $1 не поражена (отсутствует боезапас) тип: $3" > $messagesDirectory/"$1"ZRDN
        echo "$(date) ZRDN $2: Переход в режим обнаружения" > $messagesDirectory/"$1"ZRDNO
        statuses[$2]=0
      fi
      ammos[$2]=$(echo "${ammos[$2]}-1" | bc)
    fi
}

#Определение засечек сгенерированных целей, передача сообщений на КП
function checkTargetInZone() {
    if (( $# == 2 ))
    then
      if test -e $targetsDirectory/"$2"; then
        local data=$(cat $targetsDirectory/"$2")
        local x_cc=${data:1:$(expr index "$data" ",")-2}
        local y_cc=${data:$(expr index "$data" ",")+1}
        local checkingSectorResult
        local timeFirstChecking
        local time

        x_c=$(echo "$x_cc" | bc)
        y_c=$(echo "$y_cc" | bc)

        for ((i=0; i < 3; i++))
        do
          source "./ZRDN$i.sh"
          x_st=$(get_x_coord)000
          y_st=$(get_y_coord)000
          r_distance=$(get_r_distance)000
          status=${statuses[$i]}

          #Каждая цель записывается во временный файл, который создается при попадании первой засечки в зону действия ЗРДН
          #Цель определяется своим идентификатором
          #Каждая засечка записывается в соответствующий файл со своим идентификатором цели
          if test -e "$tempTargetDirectory/$1"; then
            local checkNumberStrings
            checkNumberStrings=$(wc -l $tempTargetDirectory/$1 | cut -d ' ' -f 1)
            if (( checkNumberStrings == 1 )); then
              x_cc=$(cut -d ',' -f 1 "$tempTargetDirectory/$1");
              y_cc=$(cut -d ',' -f 2 "$tempTargetDirectory/$1");
              if (( x_cc!=x_c || y_cc!=y_c)); then
                checkingSectorResult=$(checkTarget)

                #Определение типа цели по двум засечкам
                if (( checkingSectorResult == "0" )); then
                  time=$(date +%s)
                  timeFirstChecking=$(cut -d ',' -f 3 $tempTargetDirectory/$1);
                  echo "$x_c,$y_c,$time" >> "$tempTargetDirectory/$1"
                  local distanceBetweenCoord
                  local targetSpeed
                  local typeOfTarget

                  if (( status == "1" )); then
                    distanceBetweenCoord=$(echo "sqrt(($x_cc - $x_c)^2 + ($y_cc - $y_c)^2)" | bc)
                    if (( time != timeFirstChecking )); then
                      targetSpeed=$(echo | awk "{res=$distanceBetweenCoord/($time-$timeFirstChecking); print res}")
                    fi
                    targetSpeed=${targetSpeed/\.*}
                    if (( targetSpeed >= 50 && targetSpeed <= 250 )); then
                      typeOfTarget="Самолет"
                      tryToDestroy "$1" "$i" "$typeOfTarget"
                    elif (( targetSpeed > 250 && targetSpeed <= 1000 )); then
                      typeOfTarget="Крылатая ракета"
                      tryToDestroy "$1" "$i" "$typeOfTarget"
                    fi
                  fi
                fi
              fi
            fi
          else
            checkingSectorResult=$(checkTarget)
            if (( checkingSectorResult == "0" )); then
              echo "$x_c,$y_c,$(date +%s)" > "$tempTargetDirectory/$1"
              echo "$(date) ZRDN $i: Обнаружена цель ID:$1 с координатами $x_c $y_c" > $messagesDirectory/"$1"ZRDNOb
              break
            fi
          fi
        done
      fi
    fi
}

for ((i=0; i<3; i++))
do
  statuses[$i]=1;
  ammos[$i]=20;
done

mkdir "$tempTargetDirectory"
while :
do
  GenTargets_pid=$(pgrep GenTargets.sh); gen_run=$?
  if (( gen_run !=0 )); then
    echo "Процесс GenTarget убит. Завершаю работу системы ЗРДН"
    rm -rf "$tempTargetDirectory" 2>/dev/null
    exit 0
  fi
  hashIds=$(ls -t $targetsDirectory | head -n 30)
  for hashId in $hashIds
  do
    currentId="${hashId:12:6}"
    checkTargetInZone "$currentId" "$hashId"
  done
  sleep 1

  ls $messagesDirectory | grep checkZRDN 2>/dev/null
  if (( $? == 0 )); then
    echo "Система ЗРДН работоспособна" > $messagesDirectory/"answerZRDN"
  fi

  ls $messagesDirectory | grep STOPALL 2>/dev/null
  if (( $? == 0 )); then
    echo "Завершаю работу системы ЗРДН"
    rm -rf "$tempTargetDirectory" 2>/dev/null
    exit 0
  fi
done

