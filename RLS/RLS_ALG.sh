#!/bin/bash
declare fov
declare sector
declare a_direct
declare r_distance
declare x_c
declare y_c
declare x_st
declare y_st
declare currentId
tempTargetDirectory='../temp/targets/rls'
targetsDirectory='/tmp/GenTargets/Targets'
messagesDirectory='../messages'
declare -a hashIds

#Функция модуля
function abs() {
    if (( $1 < 0 ))
    then
      echo "-($1)" | bc
    else
      echo "$1"
    fi
}

function checkSector() {
  if (( x_c - x_st >= 0 && y_c - y_st >= 0 )); then
    sector="1"
  elif (( x_c - x_st < 0 && y_c - y_st >= 0 )); then
    sector="2"
  elif (( x_c - x_st < 0 && y_c - y_st < 0 )); then
    sector="3"
  elif (( x_c - x_st >= 0 && y_c - y_st < 0 )); then
    sector="4"
  else
    sector="100"
  fi
}

#Определение попадания в сектор цели относительно координат РЛС
function enterToSector() {
  checkSector
  local resultFov2
  local absolutely
  local value
  resultFov2=$(echo "$fov/2" | bc)

  if (( "$sector" == "100" || $# != 1)); then
    echo "The error has occurred while checking the sector"
    return 1
  fi
  if (( "$sector" == "1" )); then
    value=$(echo "$a_direct-$1" | bc)
    absolutely=$(abs "$value")
    if (( absolutely <= resultFov2 )); then
      echo 0;
    fi
  elif (( "$sector" == "2" )); then
    value=$(echo "$a_direct-180+$1" | bc)
    absolutely=$(abs "$value")
    if (( absolutely <= resultFov2 )); then
      echo 0;
    fi
  elif (( "$sector" == "3" )); then
    value=$(echo "$a_direct-180-$1" | bc)
    absolutely=$(abs "$value")
    if (( absolutely <= resultFov2 )); then
      echo 0;
    fi
  elif (( "$sector" == "4" )); then
    value=$(echo "$a_direct-360+$1" | bc)
    absolutely=$(abs "$value")
    if (( absolutely <= resultFov2 )); then
      echo 0;
    fi
  else
    return 1;
  fi
}

#Проверка сгенерированной цели на вхождение в сектор зоны действия РЛС
function checkTarget() {
      local distanceBetweenTargetStation
      local angleBetweenTargetStation
      local x_local
      local y_local

      distanceBetweenTargetStation=$(echo "sqrt(($x_c - $x_st)^2 + ($y_c - $y_st)^2)" | bc)
      distanceBetweenTargetStation=${distanceBetweenTargetStation/\.*}
      if (( distanceBetweenTargetStation > r_distance))
      then
        echo 2
        return 1;
      fi

      x_local=$(echo "$x_st-$x_c" | bc)
      y_local=$(echo "$y_st-$y_c" | bc)

      local res1
      local res2

      res1=$(abs "$x_local")
      res2=$(abs "$y_local")
      angleBetweenTargetStation=$(echo | awk "{x=atan2($res1,$res2)*180/3.14; print x}")
      angleBetweenTargetStation=${angleBetweenTargetStation/\.*}

      echo $(enterToSector "$angleBetweenTargetStation")
}

#Определение направления на СПРО
#Проверка направления цели на СПРО разрешается путем решения системы из двух уравнений.
#Общее уравнение системы будет представлять из себя обыкновенное квадратическое уравнение
#Если дискриминант данного уравнения будет больше или равен 0, значит цель движется в направлении сектора действия СПРО
#$1 = k, $2 = b
function checkDirectionToSpro {
  if (( $# == 2 )); then
    local discriminant
    discriminant=$(echo | awk "{res=4*($1*($2-$y_st)-$x_st)^2-4*($1^2+1)*($x_st^2+($2-$y_st)^2-$r_distance^2); print res}")
    discriminant=$(echo | awk "{res=$discriminant; print res}")
    if (( discriminant >= 0 )); then
      echo "1"
    else
      echo "0"
    fi
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

        for ((i=0; i < 3; i++))
        do
          source "./RLS$i.sh"
          x_st=$(get_x_coord)000
          y_st=$(get_y_coord)000
          fov=$(get_fov)
          a_direct=$(get_a_direct)
          r_distance=$(get_r_distance)000

          if test -e "$tempTargetDirectory/$1"; then
            local checkNumberStrings
            checkNumberStrings=$(wc -l $tempTargetDirectory/$1 | cut -d ' ' -f 1)
            if (( checkNumberStrings == 1 )); then
              x_cc=$(cut -d ',' -f 1 "$tempTargetDirectory/$1");
              y_cc=$(cut -d ',' -f 2 "$tempTargetDirectory/$1");
              if (( x_cc!=x_c || y_cc!=y_c)); then
                checkingSectorResult=$(checkTarget)

                #Определение направления на СПРО по двум засечкам
                if (( checkingSectorResult == "0" )); then
                  time=$(date +%s)
                  echo "$x_c,$y_c,$time" >> "$tempTargetDirectory/$1"
                  source "../SPRO.sh"
                  x_st=$(get_x_coord)000
                  y_st=$(get_y_coord)000
                  r_distance=$(get_r_distance)000

                  #Определение сектора второй засечки цели относительно координат СПРО
                  local sectorSecondChecking
                  checkSector
                  sectorSecondChecking=$sector
                  local x_buf
                  x_buf=$x_c
                  local y_buf
                  y_buf=$y_c
                  x_c=$x_cc
                  y_c=$y_cc

                  #Определение сектора первой засечки цели относительно координат СПРО
                  local sectorFirstChecking
                  checkSector
                  sectorFirstChecking=$sector
                  x_c=$x_buf
                  y_c=$y_buf
                  local checkDirectionToSpro

                  #k, b - параметры прямой, проходящей через две засечки
                  #x_c, y_c - кооординаты второй засечки
                  #x_cc, y_cc - координаты первой засечки
                  #Для того, чтобы определить направление движения цели на СПРО, нужно рассмотреть возможное направление
                  #на СПРО: движется ли цель на СПРО, или не движется
                  #Далее, если цель возможно движется на СПРО, решаем систему из двух уравнений,
                  #состоящее из уравнения прямой, по которой движется цель и уравнения окружности,
                  #описывающее зону действия СПРО.
                  #Подробнее описано в комментарии к функции checkDirectionToSpro
                  local k
                  local b
                    k=$(echo | awk "{res=($y_c-$y_cc)/($x_c-$x_cc); print res}")
                    b=$(echo | awk "{res=$y_c-($k*$x_c); print res}")
                  if (( sectorSecondChecking != sectorFirstChecking )); then
                    checkDirectionToSpro=$(checkDirectionToSpro "$k" "$b")
                    if (( checkDirectionToSpro == "1" )); then
                      echo "$(date) RLS $i Цель ID:$1 движется в направлении СПРО" > $messagesDirectory/"$1"RLSToSpro
                    fi
                  elif (( sectorFirstChecking == sectorSecondChecking )); then
                    if (( sectorFirstChecking == "1" )); then
                      if (( x_c <= x_cc && y_c <= y_cc )); then
                        checkDirectionToSpro=$(checkDirectionToSpro "$k" "$b")
                        if (( checkDirectionToSpro == "1" )); then
                            echo "$(date) RLS $i Цель ID:$1 движется в направлении СПРО" > $messagesDirectory/"$1"RLSToSpro
                        fi
                      fi
                    elif (( sectorFirstChecking == "2" )); then
                      if (( x_c >= x_cc && y_c <= y_cc )); then
                        checkDirectionToSpro=$(checkDirectionToSpro "$k" "$b")
                        if (( checkDirectionToSpro == "1" )); then
                          echo "$(date) RLS $i Цель ID:$1 движется в направлении СПРО" > $messagesDirectory/"$1"RLSToSpro
                        fi
                      fi
                    elif (( sectorFirstChecking == "3" )); then
                      if (( x_c >= x_cc && y_c >= y_cc )); then
                        checkDirectionToSpro=$(checkDirectionToSpro "$k" "$b")
                        if (( checkDirectionToSpro == "1" )); then
                          echo "$(date) RLS $i Цель ID:$1 движется в направлении СПРО" > $messagesDirectory/"$1"RLSToSpro
                        fi
                      fi
                    elif (( sectorFirstChecking == "4")); then
                      if (( x_c <= x_cc && y_c >= y_cc )); then
                        checkDirectionToSpro=$(checkDirectionToSpro "$k" "$b")
                        if (( checkDirectionToSpro == "1" )); then
                          echo "$(date) RLS $i Цель ID:$1 движется в направлении СПРО" > $messagesDirectory/"$1"RLSToSpro
                        fi
                      fi
                    fi
                  fi
                fi
              fi
            fi
          else
            checkingSectorResult=$(checkTarget)
            if (( checkingSectorResult == "0" )); then
              echo "$x_c,$y_c,$(date +%s)" > "$tempTargetDirectory/$1"
              echo "$(date) RLS $i Обнаружена цель ID:$1 с координатами $x_c $y_c" > $messagesDirectory/"$1"RLS
              break
            fi
          fi
        done
      fi
    fi
}

mkdir "$tempTargetDirectory" 2>/dev/null
while :
do
  GenTargets_pid=$(pgrep GenTargets.sh); gen_run=$?
  if (( gen_run !=0 )); then
    echo "Процесс GenTarget убит. Завершаю работу системы РЛС"
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
  ls $messagesDirectory | grep checkRLS 2>/dev/null > /dev/null
  if (( $? == 0 )); then
    echo "Система РЛС работоспособна" > $messagesDirectory/"answerRLS"
  fi
  ls $messagesDirectory | grep STOPALL 2>/dev/null > /dev/null
  if (( $? == 0 )); then
    echo "Завершаю работу системы РЛС"
    rm -rf "$tempTargetDirectory" 2>/dev/null
    exit 0
  fi
done

