#!/bin/bash
set -euo pipefail

# 记录任务开始时间
START_TIME=$(date +"%Y年%m月%d日 %H:%M:%S")
SECONDS=0
DATATIME=$(date +%Y%m%d)

# 清理函数：保留 N 天备份
cleanup_old_backups() {
    local dir=$1
    local days=$2
    echo "������ 清理 ${dir} 中超过 ${days} 天的旧备份..."
    find "$dir" -type f -name "*.img" -mtime +$days -exec rm -f {} \;
}

# 导出 RBD 镜像函数
export_rbd_images() {
    local pool=$1
    local out_dir=$2
    local dated_dir="${out_dir}/${DATATIME}"

    # 创建日期目录
    if ! mkdir -p "$dated_dir"; then
        echo "❌ 无法创建目录: $dated_dir，请检查挂载路径或权限！"
        return 1
    fi

    echo "������ 开始导出存储池中的 RBD 镜像: $pool"

    for image in $(rbd ls "$pool"); do
        #local filename="${image}-${DATATIME}.img"
        local filename="${image}.img"
        local fullpath="${dated_dir}/${filename}"

        echo "  ⏳ 正在导出镜像: $image -> $fullpath"
        if rbd export "${pool}/${image}" "$fullpath"; then
            echo "  ✅ 导出完成: $filename"
        else
            echo "  ❌ 导出失败: $image"
        fi
    done
}

echo "������ 备份任务开始时间：$START_TIME"

# 开始导出各个存储池的镜像
export_rbd_images "kubernetes-test" "/bak/ceph-rbd-test"
export_rbd_images "kubernetes" "/bak/ceph-rbd-prod"

# 清理旧备份（超过7天）
cleanup_old_backups "/bak/ceph-rbd-test" 7
cleanup_old_backups "/bak/ceph-rbd-prod" 7

# 输出总耗时
DURATION=$SECONDS
END_TIME=$(date +"%Y年%m月%d日 %H:%M:%S")
echo "✅ 备份任务结束时间：$END_TIME"
echo "⏱️ 总耗时：$((DURATION / 60)) 分 $((DURATION % 60)) 秒"
