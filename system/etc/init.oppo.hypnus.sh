#!/system/bin/sh
#
#ifdef VENDOR_EDIT
#jie.cheng@swdp.shanghai, 2015/11/09, add init.oppo.hypnus.sh
function log2kernel()
{
    echo "hypnus: "$1 > /dev/kmsg
}

function log2logcat()
{
    log "hypnus: "$1
}

loop_times=15

#wait data partition
if [ "$0" != "/data/hypnus/init.oppo.hypnus.sh" ]; then
    iter=0
    while [ iter -lt $loop_times ]; do
        #TODO: ext4 and f2fs
        if [ "`stat -f -c '%t' /data/`" == "ef53" -o "`stat -f -c '%t' /data/`" == "f2f52010" ]; then
            break
        fi
        log2kernel "wait for data partition, retry: iter=$iter"
        log2logcat "wait for data partition, retry: iter=$iter"
        iter=$(($iter+1));
        sleep 2
    done

    if [ iter -ge $loop_times ]; then
        log2kernel "data partition is not mounted, Installation maybe fail"
        log2logcat "data partition is not mounted, Installation maybe fail"
    fi

    if [ -f /data/hypnus/init.oppo.hypnus.sh ]; then
        /system/bin/sh /data/hypnus/init.oppo.hypnus.sh
        log2kernel "run /data/hypnus/init.oppo.hypnus.sh"
        log2logcat "run /data/hypnus/init.oppo.hypnus.sh"
        exit 0
    fi
else
        log2kernel "load sh from data partition"
fi

complete=`getprop sys.boot_completed`
enable=`getprop persist.sys.enable.hypnus`

if [ ! -n "$complete" ] ; then
     complete=0
fi

elsaenable=`getprop persist.sys.elsa.kernel_enable`
if [ "$elsaenable" == "1" ]; then
        elsaenable=1
else
        elsaenable=0
fi

case "$enable" in
    "1")
        log2kernel "module insmod beging!"
        #disable core_ctl
        echo 1 > /sys/devices/system/cpu/cpu0/core_ctl/disable
        echo 1 > /sys/devices/system/cpu/cpu4/core_ctl/disable
        n=0
        while [ n -lt 3 ]; do
            #load data folder module if it is exist
            if [ -f /data/hypnus/hypnus.ko ]; then
                insmod /data/hypnus/hypnus.ko -f boot_completed=$complete kneuron_enable=1 elsa_enable=$elsaenable
                log2logcat "running hypnus in data"
            else
                insmod /system/lib/modules/hypnus.ko -f boot_completed=$complete kneuron_enable=1 elsa_enable=$elsaenable
                log2logcat "running hypnus in system"
            fi
            if [ $? != 0 ];then
                n=$(($n+1));
                log2kernel "Error: insmod hypnus.ko failed, retry: n=$n"
                log2logcat "Error: insmod hypnus.ko failed, retry: n=$n"
            else
                log2kernel "module insmod succeed!"
                log2logcat "module insmod succeed!"
                break
            fi
        done

        if [ n -ge 3 ]; then
             log2kernel "Fail to insmod hypnus module!!"
             log2logcat "Fail to insmod hypnus module!!"
        fi

        chown system:system /dev/kneuron
        chown system:system /sys/kernel/hypnus/scene_info
        chown system:system /sys/kernel/hypnus/action_info
        chown system:system /sys/kernel/hypnus/view_info
        chown system:system /sys/kernel/hypnus/notification_info
        chown system:system /sys/kernel/hypnus/log_state
        chown system:system /sys/kernel/hypnus/perfmode
        chown root:system /sys/module/hypnus/parameters/cpuload_thresh
        chown root:system /sys/module/hypnus/parameters/io_thresh
        chown root:system /sys/module/hypnus/parameters/mem_thresh
        chown root:system /sys/module/hypnus/parameters/temperature_thresh
        chown root:system /sys/module/hypnus/parameters/trigger_time
        chown root:system /sys/module/hypnus/parameters/kneuron_work_enable
        chown root:system /sys/module/hypnus/parameters/elsa_enable_netlink
        chown root:system /sys/module/hypnus/parameters/elsa_socket_align_ms
        chmod 0664 /sys/kernel/hypnus/notification_info
        chown root:system /sys/module/hypnus/parameters/elsa_align_ms
        chcon u:object_r:sysfs_hypnus:s0 /sys/kernel/hypnus/view_info
        # 1 queuebuffer only; 2 queue and dequeuebuffer;
        setprop persist.report.tid 2
        chown system:system /data/hypnus
        log2kernel "module insmod end!"
        log2logcat "module insmod end!"
        ;;
    "0")
        rmmod hypnus
        log2kernel "Remove hypnus module"
        log2logcat "Remove hypnus module"
        # Bring up all cores online
        echo 1 > /sys/devices/system/cpu/cpu0/online
        echo 1 > /sys/devices/system/cpu/cpu1/online
        echo 1 > /sys/devices/system/cpu/cpu2/online
        echo 1 > /sys/devices/system/cpu/cpu3/online
        echo 1 > /sys/devices/system/cpu/cpu4/online
        echo 1 > /sys/devices/system/cpu/cpu5/online
        echo 1 > /sys/devices/system/cpu/cpu6/online
        echo 1 > /sys/devices/system/cpu/cpu7/online
        # Enable low power modes
        echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

        #governor settings
        echo 300000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        echo 1766400 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
        echo 825600 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
        echo 2649600 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq

        #enable core_ctl
        echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/disable
        echo 0 > /sys/devices/system/cpu/cpu4/core_ctl/disable
        ;;
esac
#endif /* VENDOR_EDIT */
