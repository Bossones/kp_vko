#!/bin/bash
#Радиус действия СПРО
declare r_distance
#Координаты цели (первой засечки / второй засечки)
declare x_c
declare y_c
#Координаты СПРО
declare x_st
declare y_st
declare -a targetsIds
declare currentId
declare status
declare ammo
tempTargetDirectory='./temp/targets/spro'
targetsDirectory='/tmp/GenTargets/Targets'
destroyTargetDirectory='/tmp/GenTargets/Destroy'
messagesDirectory='./messages'
declare -a hashIds

#Проверка сгенерированной цели на вхождение в сектор зоны действия СПРО
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
    if (( $# == 1 )); then
      local destroyProbability
      local destroyedTarget

      destroyProbability=$(echo | awk "{srand($(date +%N));res=rand()%100; print res}")
      destroyedTarget=$(echo | awk "{res=$destroyProbability<0.6; print res}")

      echo "$(date) SPRO: Цель ID: $1 осуществлен выстрел по цели Тип: Бал. ракета. Боезапас: $ammo" >> $messagesDirectory/"$1"SPROv
      if (( ammo != 0 )); then
        if (( destroyedTarget == "1" )); then
          echo "$(date) SPRO: Цель ID: $1 поражена Тип: Бал. ракета" > $messagesDirectory/"$1"SPRO
          echo "$(date) SPRO: Цель ID: $1 поражена Тип: Бал. ракета" > $destroyTargetDirectory/$1
        else
          echo "$(date) SPRO: Цель ID: $1 не поражена (промах) Тип: Бал. ракета" > $messagesDirectory/"$1"SPRO
        fi
      else
        echo "$(date) SPRO: Цель ID: $1 не поражена (отсутствует боезапас) Тип: Бал. ракета" > $messagesDirectory/"$1"SPRO
        echo "$(date) SPRO: Переход в режим обнаружения" > $messagesDirectory/"$1"SPROo
        status=0
      fi
      ammo=$(echo "$ammo-1" | bc)
    fi
}

#Определение засечек сгенерированных целей, отправка сообщений на КП
function checkTargetInZone() {
    if (( $# == 2 ))
    then
      if test -e $targetsDirectory/"$2"; then
        local data=$(cat $targetsDirectory/"$2" 2>/dev/null)
        local x_cc=${data:1:$(expr index "$data" ",")-2}
        local y_cc=${data:$(expr index "$data" ",")+1}
        local checkingSectorResult
        local timeFirstChecking
        local time

        x_c=$(echo "$x_cc" | bc)
        y_c=$(echo "$y_cc" | bc)

        #Каждая цель записывается во временный файл, который создается при попадании первой засечки в зону действия СПРО
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

              #Определение типа цели по второй засечке
              if (( checkingSectorResult == "0" )); then
                time=$(date +%s)
                timeFirstChecking=$(cut -d ',' -f 3 $tempTargetDirectory/$1);
                echo "$x_c,$y_c,$time" >> "$tempTargetDirectory/$1"
                local distanceBetweenCoord
                local targetSpeed
                if (( status == "1" )); then
                  distanceBetweenCoord=$(echo "sqrt(($x_cc - $x_c)^2 + ($y_cc - $y_c)^2)" | bc)
                  if (( time != timeFirstChecking )); then
                    targetSpeed=$(echo | awk "{res=$distanceBetweenCoord/($time-$timeFirstChecking); print res}")
                  fi
                  targetSpeed=${targetSpeed/\.*}
                  if (( targetSpeed >= 8000 && targetSpeed <= 10000 )); then
                    tryToDestroy "$1"
                  fi
                fi
              fi
            fi
          fi
        else
          checkingSectorResult=$(checkTarget)
          if (( checkingSectorResult == "0" )); then
            echo "$x_c,$y_c,$(date +%s)" > "$tempTargetDirectory/$1"
            echo "$(date) SPRO: Обнаружена цель ID:$1 с координатами $x_c $y_c" >> $messagesDirectory/"$1"SPROob
          fi
        fi
      fi
    fi
}

status=1
ammo=10
source "./SPRO.sh"
x_st=$(get_x_coord)000
y_st=$(get_y_coord)000
r_distance=$(get_r_distance)000

mkdir "$tempTargetDirectory" 2>/dev/null
while :
do
  GenTargets_pid=$(pgrep GenTargets.sh); gen_run=$?
  if (( gen_run !=0 )); then
    echo "Процесс GenTarget убит. Завершаю работу СПРО"
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

  ls $messagesDirectory | grep checkSPRO 2>/dev/null > /dev/null
  if (( $? == 0 )); then
    echo "Система СПРО работоспособна" > $messagesDirectory/"answerSPRO"
  fi

  ls $messagesDirectory | grep STOPALL 2>/dev/null > /dev/null
  if (( $? == 0 )); then
    echo "Завершаю работу системы СПРО"
    rm -rf "$tempTargetDirectory" 2>/dev/null
    exit 0
  fi
done

