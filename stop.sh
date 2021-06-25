#!/bin/bash

echo "STOP ALL" > './messages/STOPALL'

sleep 5

echo "Система остановлена."
rm -rf ./messages 2>/dev/null
exit 0