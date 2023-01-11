#!/usr/bin/env bash

string="你好"

#判断长度是否为 2
if [ ${#string} -eq 2 ]; then
  echo "string length is 2"
  string_arr=($(python -c "print('$string'.split())"))
  echo "first char: ${string_arr[0]}, second char: ${string_arr[1]}"
else
  echo "string length is not 2"
fi
