#!/bin/bash

# 获取指定名称的进程号
process_name="driver_test"
pid=$(pgrep $process_name)

if [ -z "$pid" ]; then
    echo "找不到进程: $process_name"
    exit 1
fi

# 终止进程
echo "正在终止进程: $process_name (PID: $pid)"
kill -9 $pid

echo "进程已终止"
