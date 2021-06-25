#!/bin/bash

bash ./kp.sh &
sleep 1

cd ./RLS
bash ./RLS_ALG.sh &
sleep 1

cd ../ZRDN
bash ./ZRDN_ALG.sh &
sleep 1

cd ../
bash ./SPRO_ALG.sh &
sleep 1

echo "Система запущена"

exit 0