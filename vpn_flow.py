import math
import time
import os

# 指定要监控的进程ID
pid = 3310
proc_net_file = f'/proc/{pid}/net/dev'

def convert_size(size_bytes):
    # 定义转换的阈值
    size_name = ["Bytes", "KB", "MB", "GB"]
    if size_bytes == 0:
        return '0 Bytes'
    i = int(math.floor(math.log(size_bytes, 1024)))
    p = math.pow(1024, i)
    s = round(size_bytes / p, 2)
    return f"{s} {size_name[i]}"


# 检查进程是否存在
if not os.path.exists(proc_net_file):
    print(f"进程 {pid} 的网络信息文件不存在。")
    exit(1)

# 打开文件以写入数据
with open('/srv/info.txt', 'a') as file:
    while True:
        try:
            # 读取进程的网络设备信息
            with open(proc_net_file, 'r') as f:
                net_info = f.readlines()

            # 解析接收和发送的字节数
            recv_bytes, sent_bytes = 0, 0
            for line in net_info[2:]:  # 忽略前两行标题
                line_data = line.split()
                recv_bytes += int(line_data[1])
                sent_bytes += int(line_data[9])

            # 获取当前时间戳
            timestamp = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime())

            # 将数据写入文件
            file.write(f"{timestamp} - PID: {pid}, Sent: {convert_size(sent_bytes)}, Received: {convert_size(recv_bytes)}\n")

            # 每隔一秒刷新一次数据
            time.sleep(1)
        except FileNotFoundError:
            print(f"进程 {pid} 的网络信息文件已经不存在。")
            break
        except Exception as e:
            print(f"发生错误：{e}")
            break
