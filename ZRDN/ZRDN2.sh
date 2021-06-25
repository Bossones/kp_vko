#!/bin/bash
name=zrdn2
x_coord=2950
y_coord=3450
r_distance=550
fov=360
bp=20
status=1

function get_r_distance() {
  echo $r_distance
}

function get_x_coord() {
  echo $x_coord
}

function get_y_coord() {
  echo $y_coord
}

function get_fov() {
  echo $fov
}

function get_bp() {
    echo $bp
}

function get_status() {
    echo $status
}

function change_status() {
    status=0
}

function minus_bp() {
    bp=$(echo "$bp-1" | bc)
}
