#!/bin/bash
declare fov
declare sector
declare a_direct
declare r_distance
declare x_c
declare y_c
declare x_st
declare y_st
declare -a targetsIds
declare currentId
targetsDirectory='/tmp/GenTargets/Targets'
declare -a hashIds=$(ls -t $targetsDirectory | head -n 30)

function abs() {
    if (( $1 < 0 )); then
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

function enterToSector() {
  checkSector
  local resultFov2
  local absolutely
  local value
  resultFov2=$(echo "$fov/2" | bc)

  if (( sector == "100" || $# != 1)); then
    echo "The error has occurred while checking the sector"
    return 1
  fi
  if (( sector == "1" )); then
    value=$(echo "$a_direct-$1" | bc)
    absolutely=$(abs $value)
    if (( absolutely <= resultFov2 )); then
      return 0;
    fi
  elif (( sector == "2" )); then
    value=$(echo "$a_direct-180+$1" | bc)
    absolutely=$(abs $value)
    if (( absolutely <= resultFov2 )); then
      return 0;
    fi
  elif (( sector == "3" )); then
    value=$(echo "$a_direct-180-$1" | bc)
    absolutely=$(abs $value)
    if (( absolutely <= resultFov2 )); then
      return 0;
    fi
  elif (( sector == "4" )); then
    value=$(echo "$a_direct-360+$1" | bc)
    absolutely=$(abs $value)
    if (( absolutely <= resultFov2 )); then
      return 0;
    fi
  else
    return 1;
  fi
}

function checkTarget() {
      local distanceBetweenTargetStation
      local angleBetweenTargetStation
      local x_local
      local y_local

      distanceBetweenTargetStation=$(echo "sqrt(($x_c - $x_st)^2 + ($y_c - $y_st)^2)" | bc)
      if (( distanceBetweenTargetStation > r_distance))
      then
        return 1;
      fi
      x_local=$(echo "$x_st-$x_c" | bc)
      y_local=$(echo "$y_st-$y_c" | bc)

      local res1
      local res2

      res1=$(abs $x_local)
      res2=$(abs $y_local)
      angleBetweenTargetStation=$(echo "a($res1/$res2)" | bc)
      enterToSector "$angleBetweenTargetStation"
}

function checkTargetInZone() {
    if (( $# == 2 ))
    then
      local data=$(cat $targetsDirectory/$2)
      local x_cc=${data:1:$(expr index "$data" ",")-2}
      local y_cc=${data:$(expr index "$data" ",")+1}
      x_c=$(echo "$x_cc/1000" | bc)
      y_c=$(echo "$y_cc/1000" | bc)

      for ((i=0; i < 3; i++))
      do
        source "./RLS$i.sh"
        x_st=$(get_x_coord)
        y_st=$(get_y_coord)
        fov=$(get_fov)
        a_direct=$(get_a_direct)
        r_distance=$(get_r_distance)
        checkTarget
      done
    fi
}
for hashId in $hashIds
do
  currentId="${hashId:12:6}"
  checkTargetInZone "$currentId" "$hashId"
done


