#! /system/bin/sh

DATE=`date +%F-%H`
CURTIME=`date +%F-%H-%M-%S`
ROOT_AUTOTRIGGER_PATH=/sdcard/oppo_log
ANR_BINDER_PATH=/data/oppo_log/anr_binder_info
ROOT_TRIGGER_PATH=/sdcard/oppo_log/trigger
DATA_LOG_PATH=/data/oppo_log
CACHE_PATH=/cache/admin
config="$1"
paramP1="$1"
paramP2="$2"

#Haoran.Zhang@PSW.AD.BuildConfig.StandaloneUserdata.1143522, 2017/09/13, Add for set prop sys.build.display.full_id

function set_new_prop()
{
   if [ $1 ] ; then
     hash_str="_$1";
   else
     hash_str=""
   fi
   setprop "sys.build.display.id" `getprop ro.build.display.id`"$hash_str"
   is_mtk=`getprop ro.mediatek.version.release`
   if [ $is_mtk ] ; then
   #mtk only
     setprop sys.mediatek.version.release `getprop ro.mediatek.version.release`"$hash_str"
   else
     setprop sys.build.display.full_id `getprop ro.build.display.full_id`"$hash_str"
   fi
}

function userdatarefresh(){
   #if [ "$(df /data | grep tmpfs)" ] ; then
   if [ ! `getprop vold.decrypt`  ] ; then
     if [ ! "$(df /data | grep tmpfs)" ] ; then
        mount /dev/block/bootdevice/by-name/userdata /data
     else
       return 0
     fi
   fi
   mkdir /data/engineermode
   info_file="/data/engineermode/data_version"
   #info_file is not empty
   if [ -s $info_file ] ;then
       data_ver=`cat $info_file | head -1 | xargs echo -n`
       set_new_prop $data_ver
   else
          if [ ! -f $info_file ] ;then
            if [ ! -f /data/engineermode/.sd.txt ]; then
              cp  /system/media/.sd.txt  /data/engineermode/.sd.txt
            fi
            cp /system/engineermode/*  /data/engineermode/
            #create an empty file
            rm $info_file
            touch $info_file
            chmod 0644 /data/engineermode/.sd.txt
            chmod 0644 /data/engineermode/persist*
          fi
       set_new_prop "00000000"
   fi
   #tmp patch for sendtest version
   if [ `getprop ro.build.fix_data_hash` ]; then
      set_new_prop ""
   fi
   #end
   chmod 0750 /data/engineermode
   chmod 0740 /data/engineermode/default_workspace_device*.xml
   chown system:launcher /data/engineermode
   chown system:launcher /data/engineermode/default_workspace_device*.xml
}
#end



function Preprocess(){
    mkdir -p $ROOT_AUTOTRIGGER_PATH
    mkdir -p  $ROOT_TRIGGER_PATH
}

function log_observer(){
    autostop=`getprop persist.sys.autostoplog`
    if [ x"${autostop}" = x"1" ]; then
        boot_completed=`getprop sys.boot_completed`
        sleep 10
        while [ x${boot_completed} != x"1" ];do
            sleep 10
            boot_completed=`getprop sys.boot_completed`
        done

        space_full=false
            echo "start observer"
        while [ ${space_full} == false ];do
            echo "start observer in loop"
            sleep 60
            echo "start observer sleep end"
            full_date=`date +%F-%H-%M`
            FreeSize=`df /data | grep /data | $XKIT awk '{print $4}'`
            isM=`echo ${FreeSize} | $XKIT awk '{ print index($1,"M")}'`
            echo " free size = ${FreeSize} "
            if [ ${FreeSize} -ge 1524000 ]; then
                echo "${full_date} left space ${FreeSize} more than 1.5G"
            else
                leftsize=`echo ${FreeSize} | $XKIT awk '{printf("%d",$1)}'`
                if [ $leftsize -le 1000000 ];then
                    space_full=true
                    echo "${full_date} leftspace $FreeSize is less than 1000M,stop log" >> ${DATA_LOG_PATH}/log_history.txt
                    setprop sys.oppo.logkit.full true
                    # setprop persist.sys.assert.panic false
                    setprop ctl.stop logcatsdcard
                    setprop ctl.stop logcatradio
                    setprop ctl.stop logcatevent
                    setprop ctl.stop logcatkernel
                    setprop ctl.stop tcpdumplog
                    setprop ctl.stop fingerprintlog
                    setprop ctl.stop fplogqess
                fi
            fi
        done
    fi
}

function backup_unboot_log(){
    i=1
    while [ true ];do
        if [ ! -d /cache/unboot_$i ];then
            is_folder_empty=`ls $CACHE_PATH/*`
            if [ "$is_folder_empty" = "" ];then
                echo "folder is empty"
            else
                echo "mv /cache/admin /cache/unboot_"
                mv /cache/admin /cache/unboot_$i
            fi
            break
        else
            i=`$XKIT expr $i + 1`
        fi
        if [ $i -gt 5 ];then
            break
        fi
    done
}

function initcache(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    boot_completed=`getprop sys.boot_completed`
    if [ x"${panicenable}" = x"true" ] || [ x"${camerapanic}" = x"true" ] && [ x"${boot_completed}" != x"1" ]; then
        if [ ! -d /dev/log ];then
            mkdir -p /dev/log
            chmod -R 755 /dev/log
        fi
        is_admin_empty=`ls $CACHE_PATH | wc -l`
        if [ "$is_admin_empty" != "0" ];then
            echo "backup_unboot_log"
            backup_unboot_log
        fi
        echo "mkdir /cache/admin"
        mkdir -p ${CACHE_PATH}
        mkdir -p ${CACHE_PATH}/apps
        mkdir -p ${CACHE_PATH}/kernel
        mkdir -p ${CACHE_PATH}/netlog
        mkdir -p ${CACHE_PATH}/fingerprint
        setprop sys.oppo.collectcache.start true
    fi
}

function logcatcache(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
    /system/bin/logcat -f ${CACHE_PATH}/apps/android_boot.txt -r10240 -n 5 -v threadtime
    fi
}
function radiocache(){
    radioenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    if [ "${radioenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
    /system/bin/logcat -b radio -f ${CACHE_PATH}/apps/radio_boot.txt -r4096 -n 3 -v threadtime
    fi
}
function eventcache(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
    /system/bin/logcat -b events -f ${CACHE_PATH}/apps/events_boot.txt -r4096 -n 10 -v threadtime
    fi
}
function kernelcache(){
  panicenable=`getprop persist.sys.assert.panic`
  camerapanic=`getprop persist.camera.assert.panic`
  argtrue='true'
  if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
  dmesg > ${CACHE_PATH}/kernel/kinfo_boot.txt
  /system/xbin/klogd -f ${CACHE_PATH}/kernel/kinfo_boot0.txt -n -x -l 7
  fi
}

#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OppoPowerMonitor get dmesg at O
function kernelcacheforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  dmesg > ${opmlogpath}dmesg.txt
  chown system:system ${opmlogpath}dmesg.txt
}
function tcpdumpcache(){
    tcpdmpenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    if [ "${tcpdmpenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
        system/xbin/tcpdump -i any -p -s 0 -W 2 -C 10 -w ${CACHE_PATH}/netlog/tcpdump_boot -Z root
    fi
}

function fingerprintcache(){
    platform=`getprop ro.board.platform`
    if [ "${platform}" = "sdm845" ]
    then
        state=`cat /proc/oppo_secure_common/secureSNBound`
    else
        state=`cat /proc/oppo_fp_common/secureSNBound`
    fi
    if [ ${state} != "0" ]
    then
        cat /sys/kernel/debug/tzdbg/log > ${CACHE_PATH}/fingerprint/fingerprint_boot.txt
    fi

}

function fplogcache(){
    platform=`getprop ro.board.platform`
    if [ "${platform}" = "sdm845" ]
    then
        state=`cat /proc/oppo_secure_common/secureSNBound`
    else
        state=`cat /proc/oppo_fp_common/secureSNBound`
    fi
    if [ ${state} != "0" ]
    then
        cat /sys/kernel/debug/tzdbg/qsee_log > ${CACHE_PATH}/fingerprint/qsee_boot.txt
    fi

}

function PreprocessLog(){
    if [ ! -d /dev/log ];then
        mkdir -p /dev/log
        chmod -R 755 /dev/log
    fi
    echo "enter PreprocessLog"
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
        boot_completed=`getprop sys.boot_completed`
        decrypt_delay=0
        while [ x${boot_completed} != x"1" ];do
            sleep 1
            decrypt_delay=`expr $decrypt_delay + 1`
            boot_completed=`getprop sys.boot_completed`
        done

        echo "start mkdir"
        LOGTIME=`date +%F-%H-%M-%S`
        ROOT_SDCARD_LOG_PATH=${DATA_LOG_PATH}/${LOGTIME}
        echo $ROOT_SDCARD_LOG_PATH
        ROOT_SDCARD_apps_LOG_PATH=${ROOT_SDCARD_LOG_PATH}/apps
        ROOT_SDCARD_kernel_LOG_PATH=${ROOT_SDCARD_LOG_PATH}/kernel
        ROOT_SDCARD_netlog_LOG_PATH=${ROOT_SDCARD_LOG_PATH}/netlog
        ROOT_SDCARD_FINGERPRINTERLOG_PATH=${ROOT_SDCARD_LOG_PATH}/fingerprint
        ASSERT_PATH=${ROOT_SDCARD_LOG_PATH}/oppo_assert
        TOMBSTONE_PATH=${ROOT_SDCARD_LOG_PATH}/tombstone
        ANR_PATH=${ROOT_SDCARD_LOG_PATH}/anr
        mkdir -p  ${ROOT_SDCARD_LOG_PATH}
        mkdir -p  ${ROOT_SDCARD_apps_LOG_PATH}
        mkdir -p  ${ROOT_SDCARD_kernel_LOG_PATH}
        mkdir -p  ${ROOT_SDCARD_netlog_LOG_PATH}
        mkdir -p  ${ROOT_SDCARD_FINGERPRINTERLOG_PATH}
        mkdir -p  ${ASSERT_PATH}
        mkdir -p  ${TOMBSTONE_PATH}
        mkdir -p  ${ANR_PATH}
        mkdir -p  ${ANR_BINDER_PATH}
        chmod -R 777 ${ANR_BINDER_PATH}
        chown system:system ${ANR_BINDER_PATH}
        chmod -R 777 ${ROOT_SDCARD_LOG_PATH}
        echo ${LOGTIME} >> /data/oppo_log/log_history.txt
        echo ${LOGTIME} >> /data/oppo_log/transfer_list.txt
        #TODO:wenzhen android O
        #decrypt=`getprop com.oppo.decrypt`
        decrypt='false'
        if [ x"${decrypt}" != x"true" ]; then
            setprop ctl.stop logcatcache
            setprop ctl.stop radiocache
            setprop ctl.stop eventcache
            setprop ctl.stop kernelcache
            setprop ctl.stop fingerprintcache
            setprop ctl.stop fplogcache
            setprop ctl.stop tcpdumpcache
            mv ${CACHE_PATH}/* ${ROOT_SDCARD_LOG_PATH}/
            mv /cache/unboot_* ${ROOT_SDCARD_LOG_PATH}/
            setprop com.oppo.decrypt true
        fi
        setprop persist.sys.com.oppo.debug.time ${LOGTIME}
    fi

    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
        setprop sys.oppo.logkit.appslog ${ROOT_SDCARD_apps_LOG_PATH}
        setprop sys.oppo.logkit.kernellog ${ROOT_SDCARD_kernel_LOG_PATH}
        setprop sys.oppo.logkit.netlog ${ROOT_SDCARD_netlog_LOG_PATH}
        setprop sys.oppo.logkit.assertlog ${ASSERT_PATH}
        setprop sys.oppo.logkit.anrlog ${ANR_PATH}
        setprop sys.oppo.logkit.tombstonelog ${TOMBSTONE_PATH}
        setprop sys.oppo.logkit.fingerprintlog ${ROOT_SDCARD_FINGERPRINTERLOG_PATH}
        setprop sys.oppo.collectlog.start true

        systemSatus="SI_start"
        getSystemSatus;
    fi
}

function initLogPath(){
    FreeSize=`df /data | grep /data | $XKIT awk '{print $4}'`
    GSIZE=`echo | $XKIT awk '{printf("%d",2*1024*1024)}'`
if [ ${FreeSize} -ge ${GSIZE} ]; then
    androidSize=51200
    androidCount=`echo ${FreeSize} 30 50 ${androidSize} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
    if [ ${androidCount} -ge 180 ]; then
        androidCount=180
    fi
    radioSize=20480
    radioCount=`echo ${FreeSize} 1 50 ${radioSize} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
    if [ ${radioCount} -ge 25 ]; then
        radioCount=25
    fi
    eventSize=20480
    eventCount=`echo ${FreeSize} 1 50 ${eventSize} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
    if [ ${eventCount} -ge 25 ]; then
        eventCount=25
    fi
    tcpdumpSize=100
    tcpdumpSizeKb=100*1024
    tcpdumpCount=`echo ${FreeSize} 10 50 ${tcpdumpSizeKb} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
    if [ ${tcpdumpCount} -ge 50 ]; then
        tcpdumpCount=50
    fi
else
    androidSize=20480
    androidCount=`echo ${FreeSize} 30 50 ${androidSize} | $XKIT awk '{printf("%d",$1*$2*1024/$3/$4)}'`
    if [ ${androidCount} -ge 10 ]; then
        androidCount=10
    fi
    radioSize=10240
    radioCount=`echo ${FreeSize} 1 50 ${radioSize} | $XKIT awk '{printf("%d",$1*$2*1024/$3/$4)}'`
    if [ ${radioCount} -ge 4 ]; then
        radioCount=4
    fi
    eventSize=10240
    eventCount=`echo ${FreeSize} 1 50 ${eventSize} | $XKIT awk '{printf("%d",$1*$2*1024/$3/$4)}'`
    if [ ${eventCount} -ge 4 ]; then
        eventCount=4
    fi
    tcpdumpSize=50
    tcpdumpCount=`echo ${FreeSize} 10 50 ${tcpdumpSize} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
    if [ ${tcpdumpCount} -ge 2 ]; then
        tcpdumpCount=2
    fi
fi
    ROOT_SDCARD_apps_LOG_PATH=`getprop sys.oppo.logkit.appslog`
    ROOT_SDCARD_kernel_LOG_PATH=`getprop sys.oppo.logkit.kernellog`
    ROOT_SDCARD_netlog_LOG_PATH=`getprop sys.oppo.logkit.netlog`
    ASSERT_PATH=`getprop sys.oppo.logkit.assertlog`
    TOMBSTONE_PATH=`getprop sys.oppo.logkit.tombstonelog`
    ANR_PATH=`getprop sys.oppo.logkit.anrlog`
    ROOT_SDCARD_FINGERPRINTERLOG_PATH=`getprop sys.oppo.logkit.fingerprintlog`
}

function PreprocessOther(){
    mkdir -p  $ROOT_TRIGGER_PATH/${CURTIME}
    GRAB_PATH=$ROOT_TRIGGER_PATH/${CURTIME}
}

function Logcat(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]
    then
    /system/bin/logcat -f ${ROOT_SDCARD_apps_LOG_PATH}/android.txt -r${androidSize} -n ${androidCount}  -v threadtime  -A
    /system/bin/logcat -c
    else
    setprop ctl.stop logcatsdcard
    fi
}
function LogcatRadio(){
    radioenable=`getprop persist.sys.assert.panic`
    argtrue='true'
    if [ "${radioenable}" = "${argtrue}" ]
    then
    /system/bin/logcat -b radio -f ${ROOT_SDCARD_apps_LOG_PATH}/radio.txt -r${radioSize} -n ${radioCount}  -v threadtime -A
    else
    setprop ctl.stop logcatradio
    fi
}
function LogcatEvent(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]
    then
    /system/bin/logcat -b events -f ${ROOT_SDCARD_apps_LOG_PATH}/events.txt -r${eventSize} -n ${eventCount}  -v threadtime -A
    else
    setprop ctl.stop logcatevent
    fi
}
function LogcatKernel(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]
    then
    cat proc/cmdline > ${ROOT_SDCARD_kernel_LOG_PATH}/cmdline.txt
    /system/xbin/klogd -f - -n -x -l 7 | $XKIT tee - ${ROOT_SDCARD_kernel_LOG_PATH}/kinfo0.txt | $XKIT awk 'NR%400==0'
    fi
}
function tcpdumpLog(){
    tcpdmpenable=`getprop persist.sys.assert.panic`
    argtrue='true'
    if [ "${tcpdmpenable}" = "${argtrue}" ]; then
        system/xbin/tcpdump -i any -p -s 0 -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${ROOT_SDCARD_netlog_LOG_PATH}/tcpdump.pcap -Z root
    fi
}
function grabNetlog(){

    /system/xbin/tcpdump -i any -p -s 0 -W 5 -C 10 -w /cache/admin/netlog/tcpdump.pcap -Z root

}

function LogcatFingerprint(){
    countfp=1
    platform=`getprop ro.board.platform`
    if [ "${platform}" = "sdm845" ]
    then
        state=`cat /proc/oppo_secure_common/secureSNBound`
    else
        state=`cat /proc/oppo_fp_common/secureSNBound`
    fi

    echo "LogcatFingerprint state = ${state}"
    if [ ${state} != "0" ]
    then
    echo "LogcatFingerprint in loop"
        while true
        do
            cat /sys/kernel/debug/tzdbg/log > ${ROOT_SDCARD_FINGERPRINTERLOG_PATH}/fingerprint_log${countfp}.txt
            if [ ! -s ${ROOT_SDCARD_FINGERPRINTERLOG_PATH}/fingerprint_log${countfp}.txt ];then
            rm ${ROOT_SDCARD_FINGERPRINTERLOG_PATH}/fingerprint_log${countfp}.txt;
            fi
            ((countfp++))
            sleep 1
        done
    fi
}

function LogcatFingerprintQsee(){
    countqsee=1
    platform=`getprop ro.board.platform`
    if [ "${platform}" = "sdm845" ]
    then
        state=`cat /proc/oppo_secure_common/secureSNBound`
    else
        state=`cat /proc/oppo_fp_common/secureSNBound`
    fi
    echo "LogcatFingerprintQsee state = ${state}"
    if [ ${state} != "0" ]
    then
        echo "LogcatFingerprintQsee in loop"
        while true
        do
            cat /sys/kernel/debug/tzdbg/qsee_log > ${ROOT_SDCARD_FINGERPRINTERLOG_PATH}/qsee_log${countqsee}.txt
            if [ ! -s ${ROOT_SDCARD_FINGERPRINTERLOG_PATH}/qsee_log${countqsee}.txt ];then
            rm ${ROOT_SDCARD_FINGERPRINTERLOG_PATH}/qsee_log${countqsee}.txt;
            fi
            ((countqsee++))
            sleep 1
        done
    fi
}

function screen_record(){
    ROOT_SDCARD_RECORD_LOG_PATH=${ROOT_AUTOTRIGGER_PATH}/screen_record
    mkdir -p  ${ROOT_SDCARD_RECORD_LOG_PATH}
    /system/bin/screenrecord  --time-limit 1800 --bit-rate 8000000 --size 540x1140 --verbose  ${ROOT_SDCARD_RECORD_LOG_PATH}/screen_record.mp4
}

function screen_record_backup(){
    backupFile="/data/media/0/oppo_log/screen_record/screen_record_old.mp4"
    if [ -f "$backupFile" ]; then
         rm $backupFile
    fi

    curFile="/data/media/0/oppo_log/screen_record/screen_record.mp4"
    if [ -f "$curFile" ]; then
         mv $curFile $backupFile
    fi
}

function Dmesg(){
    mkdir -p  $ROOT_TRIGGER_PATH/${CURTIME}
    dmesg > $ROOT_TRIGGER_PATH/${CURTIME}/dmesg.txt;
}
function Dumpsys(){
    mkdir -p  $ROOT_TRIGGER_PATH/${CURTIME}_dumpsys
    dumpsys > $ROOT_TRIGGER_PATH/${CURTIME}_dumpsys/dumpsys.txt;
}
function Dumpstate(){
    mkdir -p  $ROOT_TRIGGER_PATH/${CURTIME}_dumpstate
    dumpstate > $ROOT_TRIGGER_PATH/${CURTIME}_dumpstate/dumpstate.txt
}
function Top(){
    mkdir -p  $ROOT_TRIGGER_PATH/${CURTIME}_top
    top -n 1 > $ROOT_TRIGGER_PATH/${CURTIME}_top/top.txt;
}
function Ps(){
    mkdir -p  $ROOT_TRIGGER_PATH/${CURTIME}_ps
    ps > $ROOT_TRIGGER_PATH/${CURTIME}_ps/ps.txt;
}

function Server(){
    mkdir -p  $ROOT_TRIGGER_PATH/${CURTIME}_servelist
    service list  > $ROOT_TRIGGER_PATH/${CURTIME}_servelist/serviceList.txt;
}

function DumpEnvironment(){
    rm  -rf /cache/environment
    umask 000
    mkdir -p /cache/environment
    chmod 777 /data/misc/gpu/gpusnapshot/*
    ls -l /data/misc/gpu/gpusnapshot/ > /cache/environment/snapshotlist.txt
    cp -rf /data/misc/gpu/gpusnapshot/* /cache/environment/
    chmod 777 /cache/environment/dump*
    rm -rf /data/misc/gpu/gpusnapshot/*
    #ps -A > /cache/environment/ps.txt &
    ps -AT > /cache/environment/ps_thread.txt &
    mount > /cache/environment/mount.txt &
    extra_log="/data/system/dropbox/extra_log"
    if [ -d  ${extra_log} ];
    then
        all_logs=`ls ${extra_log}`
        for i in ${all_logs};do
            echo ${i}
            cp /data/system/dropbox/extra_log/${i}  /cache/environment/extra_log_${i}
        done
        chmod 777 /cache/environment/extra_log*
    fi
    getprop > /cache/environment/prop.txt &
    #dumpsys SurfaceFlinger > /cache/environment/sf.txt &
    /system/bin/dmesg > /cache/environment/dmesg.txt &
    /system/bin/logcat -d -v threadtime > /cache/environment/android.txt &
    /system/bin/logcat -b radio -d -v threadtime > /cache/environment/radio.txt &
    /system/bin/logcat -b events -d -v threadtime > /cache/environment/events.txt &
    i=`ps -A | grep system_server | $XKIT awk '{printf $2}'`
    ls /proc/$i/fd -al > /cache/environment/system_server_fd.txt &
    ps -A -T | grep $i > /cache/environment/system_server_thread.txt &
    cp -rf /data/system/packages.xml /cache/environment/packages.xml
    chmod +r /cache/environment/packages.xml
    cat /sys/kernel/debug/binder/state > /cache/environment/binder_info.txt &
    cat /proc/meminfo > /cache/environment/proc_meminfo.txt &
    cat /d/ion/heaps/system > /cache/environment/iom_system_heaps.txt &
    df -k > /cache/environment/df.txt &
    ls -l /data/anr > /cache/environment/anr_ls.txt &
    du -h -a /data/system/dropbox > /cache/environment/dropbox_du.txt &
    wait
    setprop sys.dumpenvironment.finished 1
    umask 077
}

function CleanAll(){
    rm -rf /cache/admin
    rm -rf /data/core/*
    # rm -rf /data/oppo_log/*
    oppo_log="/data/oppo_log"
    if [ -d  ${oppo_log} ];
    then
        all_logs=`ls ${oppo_log} |grep -v junk_logs`
        for i in ${all_logs};do
        echo ${i}
        if [ -d ${oppo_log}/${i} ] || [ -f ${oppo_log}/${i} ]
        then
        echo "rm -rf ===>"${i}
        rm -rf ${oppo_log}/${i}
        fi
        done
    fi
    oppo_log="/sdcard/oppo_log"
    if [ -d  ${oppo_log} ];
    then
        all_logs=`ls ${oppo_log} |grep -v junk_logs`
        for i in ${all_logs};do
        echo ${i}
        #delete all folder or files in sdcard/oppo_log,except these files and folders
        if [ -d ${oppo_log}/${i} ] || [ -f ${oppo_log}/${i} ] && [ ${i} != "diag_logs" ] && [ ${i} != "diag_pid" ] && [ ${i} != "btsnoop_hci" ]
        then
        echo "rm -rf ===>"${i}
        rm -rf ${oppo_log}/${i}
        fi
        done
    fi
    rm /data/oppo_log/junk_logs/kernel/*
    rm /data/oppo_log/junk_logs/ftrace/*


    is_europe=`getprop ro.oppo.regionmark`
    if [ x"${is_europe}" != x"EUEX" ]; then
        rm /sdcard/oppo_log/junk_logs/kernel/*
        rm /sdcard/oppo_log/junk_logs/ftrace/*
    else
        rm /data/oppo/log/DCS/junk_logs_tmp/kernel/*
        rm /data/oppo/log/DCS/junk_logs_tmp/ftrace/*
    fi

    rm -rf /data/anr/*
    rm -rf /data/tombstones/*
    rm -rf /data/system/dropbox/*
    setprop sys.clear.finished 1
}

function tranfer(){
    mkdir -p /sdcard/oppo_log
    mkdir -p /sdcard/oppo_log/compress_log
    chmod -R 777 /data/oppo_log/*
    cat /data/oppo_log/log_history.txt >> /sdcard/oppo_log/log_history.txt
    mv /data/oppo_log/transfer_list.txt  /sdcard/oppo_log/transfer_list.txt
    rm -rf /data/oppo_log/log_history.txt
    mkdir -p sdcard/oppo_log/dropbox
    cp -rf data/system/dropbox/* sdcard/oppo_log/dropbox/
    chmod  -R  /data/core/*
    mkdir -p /sdcard/oppo_log/core
    mv /data/core/* /data/media/0/oppo_log/core
    # mv /data/oppo_log/* /data/media/0/oppo_log/
    oppo_log="/data/oppo_log"
    if [ -d  ${oppo_log} ];
    then
        all_logs=`ls ${oppo_log} |grep -v junk_logs`
        for i in ${all_logs};do
        echo ${i}
        if [ -d ${oppo_log}/${i} ] || [ -f ${oppo_log}/${i} ]
        then
        echo " mv ===>"${i}
        mv ${oppo_log}/${i} /data/media/0/oppo_log/
        fi
        done
    fi

    if [ -f "/sys/kernel/hypnus/log_state"] && [ -d "/data/oppo_log/junk_logs"]
    then
        mkdir -p sdcard/oppo_log/junk_logs/kernel
        mkdir -p sdcard/oppo_log/junk_logs/ftrace
        echo "has /sys/kernel/hypnus/log_state"
        cp /data/oppo_log/junk_logs/kernel/* sdcard/oppo_log/junk_logs/kernel
        cp /data/oppo_log/junk_logs/ftrace/* sdcard/oppo_log/junk_logs/ftrace
        kernel_state=1

        while [ $kernel_state -lt 6 ]
        do
            ((kernel_state++))
            echo $kernel_state
            state=`cat /sys/kernel/hypnus/log_state`
            echo " cat /sys/kernel/hypnus/log_state ${state} "
            if [ "${state}" == "0" ]
            then
            rm -rf data/oppo_log/junk_logs/kernel/*
            rm -rf data/oppo_log/junk_logs/ftrace/*
            break
            fi
            sleep 1
            echo " sleep 1"
        done
    fi

    mkdir -p sdcard/oppo_log/xlog
    mkdir -p sdcard/oppo_log/sub_xlog
    cp  /sdcard/tencent/MicroMsg/xlog/* /sdcard/oppo_log/xlog/
    cp  /storage/emulated/999/tencent/MicroMsg/xlog/* /sdcard/oppo_log/sub_xlog

    chcon -R u:object_r:media_rw_data_file:s0 /data/media/0/oppo_log/
    chown -R media_rw:media_rw /data/media/0/oppo_log/
    setprop sys.tranfer.finished 1

}

##add for log kit 2 begin
function tranfer2(){
    stoptime=`getprop sys.oppo.log.stoptime`;
    newpath="/sdcard/oppo_log/log@stop@${stoptime}"
    medianewpath="/data/media/0/oppo_log/log@stop@${stoptime}"
    echo "new path ${stoptime}"
    echo "new path ${newpath}"
    echo "new media path ${medianewpath}"
    mkdir -p ${newpath}
    chmod -R 777 /data/oppo_log/*
    cat /data/oppo_log/log_history.txt >> ${newpath}/log_history.txt
    mv /data/oppo_log/transfer_list.txt  ${newpath}/transfer_list.txt
    rm -rf /data/oppo_log/log_history.txt
    mkdir -p ${newpath}/dropbox
    cp -rf data/system/dropbox/* ${newpath}/dropbox/
    cp -rf data/oppo/log ${newpath}/
    mkdir -p ${newpath}/bluetooth_ramdump
    chmod 666 -R data/vendor/ramdump/bluetooth/*
    cp -rf data/vendor/ramdump/bluetooth ${newpath}/bluetooth_ramdump/
    chmod  -R 777  /data/core/*
    mkdir -p ${newpath}/core
    mv /data/core/* ${medianewpath}/core
    mv /sdcard/oppo_log/pcm_dump ${newpath}/
    cp -rf /sdcard/oppo_log/btsnoop_hci/ ${newpath}/
    # before mv /data/oppo_log, wait for dumpmeminfo done
    count=0
    timeSub=`getprop persist.sys.com.oppo.debug.time`

    outputPathStop="${DATA_LOG_PATH}/${timeSub}/SI_stop/"
    touch /sdcard/oppo_log/test
    echo ${outputPathStop} >> /sdcard/oppo_log/test
    while [ $count -le 30 ] && [ ! -f ${outputPathStop}/wechat/finish_weixin ];do
        echo "hello" >> /sdcard/oppo_log/test
        echo $outputPathStop >> /sdcard/oppo_log/test
        echo $count >> /sdcard/oppo_log/test
        count=$((count + 1))
        sleep 1
    done
    rm -f /sdcard/oppo_log/test
    # mv /data/oppo_log/* /data/media/0/oppo_log/
    oppo_log="/data/oppo_log"
    if [ -d  ${oppo_log} ];
    then
        all_logs=`ls ${oppo_log} |grep -v junk_logs`
        for i in ${all_logs};do
        echo ${i}
        if [ -d ${oppo_log}/${i} ] || [ -f ${oppo_log}/${i} ]
        then
        echo " mv ===>"${i}
        mv ${oppo_log}/${i} ${medianewpath}/
        fi
        done
    fi

    if [ -f "/sys/kernel/hypnus/log_state" ] && [ -d "/data/oppo_log/junk_logs" ]
    then
        mkdir -p ${newpath}/junk_logs/kernel
        mkdir -p ${newpath}/junk_logs/ftrace
        echo "has /sys/kernel/hypnus/log_state"
        cp /data/oppo_log/junk_logs/kernel/* ${newpath}/junk_logs/kernel
        cp /data/oppo_log/junk_logs/ftrace/* ${newpath}/junk_logs/ftrace
        kernel_state=1

        while [ $kernel_state -lt 6 ]
        do
            ((kernel_state++))
            echo $kernel_state
            state=`cat /sys/kernel/hypnus/log_state`
            echo " cat /sys/kernel/hypnus/log_state ${state} "
            if [ "${state}" == "0" ]
            then
            rm -rf data/oppo_log/junk_logs/kernel/*
            rm -rf data/oppo_log/junk_logs/ftrace/*
            break
            fi
            sleep 1
            echo " sleep 1"
        done
    fi

    # mkdir -p ${newpath}/xlog
    # mkdir -p ${newpath}/sub_xlog
    XLOG_MAX_NUM=8
    XLOG_IDX=0
    if [ -d "/sdcard/tencent/MicroMsg/xlog" ]; then
        mkdir -p ${newpath}/xlog
        ALL_FILE=`ls -t /sdcard/tencent/MicroMsg/xlog`
        for i in $ALL_FILE;
        do
            echo "now we have Xlog file $i"
            let XLOG_IDX=$XLOG_IDX+1;
            echo ========file num is $XLOG_IDX===========
            if [ "$XLOG_IDX" -lt $XLOG_MAX_NUM ] ; then
               echo  $i\!;
                cp  /sdcard/tencent/MicroMsg/xlog/$i ${newpath}/xlog/
            fi
        done
    fi

    XLOG_IDX=0
    if [ -d "/storage/emulated/999/tencent/MicroMsg/xlog" ]; then
        mkdir -p ${newpath}/sub_xlog
        ALL_FILE=`ls -t /storage/emulated/999/tencent/MicroMsg/xlog`
        for i in $ALL_FILE;
        do
            echo "now we have subXlog file $i"
            let XLOG_IDX=$XLOG_IDX+1;
            echo ========file num is $XLOG_IDX===========
            if [ "$XLOG_IDX" -lt $XLOG_MAX_NUM ] ; then
               echo  $i\!;
                cp  /storage/emulated/999/tencent/MicroMsg/xlog/$i ${newpath}/sub_xlog
            fi
        done
    fi

    mv /data/oppo/log/modem_log/config/ sdcard/oppo_log/diag_logs/
    mv sdcard/oppo_log/diag_logs ${newpath}/
    mkdir -p ${medianewpath}/faceunlock
    mv /data/system/users/0/faceunlock/* ${medianewpath}/faceunlock
    mv /sdcard/oppo_log/storage/ ${medianewpath}/
    mv /sdcard/oppo_log/trigger ${medianewpath}/
    mkdir -p ${medianewpath}/colorOS_TraceLog
    cp /storage/emulated/0/ColorOS/TraceLog/trace_*.csv ${medianewpath}/colorOS_TraceLog/
    mv /sdcard/oppo_log/recovery_log ${medianewpath}/
    mv ${ROOT_AUTOTRIGGER_PATH}/LayerDump/ ${newpath}/
    chcon -R u:object_r:media_rw_data_file:s0 /data/media/0/oppo_log/
    chown -R media_rw:media_rw /data/media/0/oppo_log/

    curFile="/data/media/0/oppo_log/screen_record/"
    if [ -d "$curFile" ]; then
         mv $curFile "${medianewpath}/"
    fi
    #mv /sdcard/.oppologkit/temp_log_config.xml ${newpath}/
    cp /data/oppo/log/temp_log_config.xml ${newpath}/
    screen_shot="/sdcard/DCIM/Screenshots/"
    mkdir -p ${newpath}/tombstones/
    cp /data/tombstones/tombstone* ${newpath}/tombstones/
    MAX_NUM=5
    IDX=0

    is_release=`getprop ro.build.release_type`
    if [ x"${is_release}" != x"true" ]; then
        if [ -d "$screen_shot" ]; then
            mkdir -p ${newpath}/Screenshots
            touch ${newpath}/Screenshots/.nomedia
            ALL_FILE=`ls -t $screen_shot`
            for i in $ALL_FILE;
            do
                echo "now we have file $i"
                let IDX=$IDX+1;
                echo ========file num is $IDX===========
                if [ "$IDX" -lt $MAX_NUM ] ; then
                   echo  $i\!;
                   cp $screen_shot/$i ${newpath}/Screenshots/
                fi
            done
        fi
    fi

    pmlog=data/system/powermonitor_backup/
    if [ -d "$pmlog" ]; then
        mkdir -p ${newpath}/powermonitor_backup
        cp -r data/system/powermonitor_backup/* ${newpath}/powermonitor_backup/
    fi
    systrace=/sdcard/oppo_log/systrace
    if [ -d "$systrace" ]; then
        mv ${systrace} ${newpath}/
    fi
    #get proc/dellog
    cat proc/dellog > ${newpath}/proc_dellog.txt

    mkdir -p ${newpath}/Browser
    cp -rf sdcard/Coloros/Browser/.log/xlog/* ${newpath}/Browser/

    setprop sys.tranfer.finished 1

}

function calculateLogSize(){
    LogSize1=0
    LogSize2=0
    if [ -d "${DATA_LOG_PATH}" ]; then
        LogSize1=`du -s -k ${DATA_LOG_PATH} | $XKIT awk '{print $1}'`
    fi

    if [ -d /sdcard/oppo_log/diag_logs ]; then
        LogSize2=`du -s -k /sdcard/oppo_log/diag_logs | $XKIT awk '{print $1}'`
    fi
    LogSize3=`expr $LogSize1 + $LogSize2`
    echo "data : ${LogSize1}"
    echo "diag : ${LogSize2}"
    setprop sys.calcute.logsize ${LogSize3}
    setprop sys.calcute.finished 1
}

function calculateFolderSize() {
    folderSize=0
    folder=`getprop sys.oppo.log.folder`
    if [ -d "${folder}" ]; then
        folderSize=`du -s -k ${folder} | $XKIT awk '{print $1}'`
    fi
    echo "${folder} : ${folderSize}"
    setprop sys.oppo.log.foldersize ${folderSize}
}

function deleteFolder() {
    title=`getprop sys.oppo.log.deletepath.title`;
    logstoptime=`getprop sys.oppo.log.deletepath.stoptime`;
    newpath="sdcard/oppo_log/${title}@stop@${logstoptime}";
    echo ${newpath}
    rm -rf ${newpath}
    setprop sys.clear.finished 1
}

function deleteOrigin() {
    stoptime=`getprop sys.oppo.log.stoptime`;
    newpath="/sdcard/oppo_log/log@stop@${stoptime}"
    rm -rf ${newpath}
    setprop sys.oppo.log.deleted 1
}

function initLogPath2() {
    FreeSize=`df /data | grep /data | $XKIT awk '{print $4}'`
    echo 'df /data'
    echo "FreeSize is ${FreeSize}"
    GSIZE=`echo | $XKIT awk '{printf("%d",2*1024*1024)}'`
    tmpMain=`getprop persist.sys.log.main`
    tmpRadio=`getprop persist.sys.log.radio`
    tmpEvent=`getprop persist.sys.log.event`
    tmpKernel=`getprop persist.sys.log.kernel`
    tmpTcpdump=`getprop persist.sys.log.tcpdump`
    echo "getprop persist.sys.log.main ${tmpMain}"
    echo "getprop persist.sys.log.radio ${tmpRadio}"
    echo "getprop persist.sys.log.event ${tmpEvent}"
    echo "getprop persist.sys.log.kernel ${tmpKernel}"
    echo "getprop persist.sys.log.tcpdump ${tmpTcpdump}"
    if [ ${FreeSize} -ge ${GSIZE} ]; then
        if [ "${tmpMain}" != "" ]; then
            #get the config size main
            tmpAndroidSize=`set -f;array=(${tmpMain//|/ });echo "${array[0]}"`
            tmpAdnroidCount=`set -f;array=(${tmpMain//|/ });echo "${array[1]}"`
            androidSize=`echo ${tmpAndroidSize} | $XKIT awk '{printf("%d",$1*1024)}'`
            androidCount=`echo ${FreeSize} 30 50 ${androidSize} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
            echo "tmpAndroidSize=${tmpAndroidSize}; tmpAdnroidCount=${tmpAdnroidCount} androidSize=${androidSize} androidCount=${androidCount}"
            if [ ${androidCount} -ge ${tmpAdnroidCount} ]; then
                androidCount=${tmpAdnroidCount}
            fi
            echo "last androidCount=${androidCount}"
        fi

        if [ "${tmpRadio}" != "" ]; then
            #get the config size radio
            tmpRadioSize=`set -f;array=(${tmpRadio//|/ });echo "${array[0]}"`
            tmpRadioCount=`set -f;array=(${tmpRadio//|/ });echo "${array[1]}"`
            radioSize=`echo ${tmpRadioSize} | $XKIT awk '{printf("%d",$1*1024)}'`
            radioCount=`echo ${FreeSize} 1 50 ${radioSize} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
            echo "tmpRadioSize=${tmpRadioSize}; tmpRadioCount=${tmpRadioCount} radioSize=${radioSize} radioCount=${radioCount}"
            if [ ${radioCount} -ge ${tmpRadioCount} ]; then
                radioCount=${tmpRadioCount}
            fi
            echo "last radioCount=${radioCount}"
        fi

        if [ "${tmpEvent}" != "" ]; then
            #get the config size event
            tmpEventSize=`set -f;array=(${tmpEvent//|/ });echo "${array[0]}"`
            tmpEventCount=`set -f;array=(${tmpEvent//|/ });echo "${array[1]}"`
            eventSize=`echo ${tmpEventSize} | $XKIT awk '{printf("%d",$1*1024)}'`
            eventCount=`echo ${FreeSize} 1 50 ${eventSize} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
            echo "tmpEventSize=${tmpEventSize}; tmpEventCount=${tmpEventCount} eventSize=${eventSize} eventCount=${eventCount}"
            if [ ${eventCount} -ge ${tmpEventCount} ]; then
                eventCount=${tmpEventCount}
            fi
            echo "last eventCount=${eventCount}"
        fi

        if [ "${tmpTcpdump}" != "" ]; then
            tmpTcpdumpSize=`set -f;array=(${tmpTcpdump//|/ });echo "${array[0]}"`
            tmpTcpdumpCount=`set -f;array=(${tmpTcpdump//|/ });echo "${array[1]}"`
            tcpdumpSize=`echo ${tmpTcpdumpSize} | $XKIT awk '{printf("%d",$1*1024)}'`
            tcpdumpCount=`echo ${FreeSize} 10 50 ${tcpdumpSize} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
            echo "tmpTcpdumpSize=${tmpTcpdumpCount}; tmpEventCount=${tmpEventCount} tcpdumpSize=${tcpdumpSize} tcpdumpCount=${tcpdumpCount}"
            ##tcpdump use MB in the order
            tcpdumpSize=${tmpTcpdumpSize}
            if [ ${tcpdumpCount} -ge ${tmpTcpdumpCount} ]; then
                tcpdumpCount=${tmpTcpdumpCount}
            fi
            echo "last tcpdumpCount=${tcpdumpCount}"
        else
            echo "tmpTcpdump is empty"
        fi
    else
        echo "free size is less than 2G"
        androidSize=20480
        androidCount=`echo ${FreeSize} 30 50 ${androidSize} | $XKIT awk '{printf("%d",$1*$2*1024/$3/$4)}'`
        if [ ${androidCount} -ge 10 ]; then
            androidCount=10
        fi
        radioSize=10240
        radioCount=`echo ${FreeSize} 1 50 ${radioSize} | $XKIT awk '{printf("%d",$1*$2*1024/$3/$4)}'`
        if [ ${radioCount} -ge 4 ]; then
            radioCount=4
        fi
        eventSize=10240
        eventCount=`echo ${FreeSize} 1 50 ${eventSize} | $XKIT awk '{printf("%d",$1*$2*1024/$3/$4)}'`
        if [ ${eventCount} -ge 4 ]; then
            eventCount=4
        fi
        tcpdumpSize=50
        tcpdumpCount=`echo ${FreeSize} 10 50 ${tcpdumpSize} | $XKIT awk '{printf("%d",$1*$2/$3/$4)}'`
        if [ ${tcpdumpCount} -ge 2 ]; then
            tcpdumpCount=2
        fi
    fi
    ROOT_SDCARD_apps_LOG_PATH=`getprop sys.oppo.logkit.appslog`
    ROOT_SDCARD_kernel_LOG_PATH=`getprop sys.oppo.logkit.kernellog`
    ROOT_SDCARD_netlog_LOG_PATH=`getprop sys.oppo.logkit.netlog`
    ASSERT_PATH=`getprop sys.oppo.logkit.assertlog`
    TOMBSTONE_PATH=`getprop sys.oppo.logkit.tombstonelog`
    ANR_PATH=`getprop sys.oppo.logkit.anrlog`
    ROOT_SDCARD_FINGERPRINTERLOG_PATH=`getprop sys.oppo.logkit.fingerprintlog`
}

function Logcat2(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    echo "logcat2 panicenable=${panicenable} tmpMain=${tmpMain}"
    echo "logcat2 androidSize=${androidSize} androidCount=${androidCount}"
    echo "logcat 2 ${ROOT_SDCARD_apps_LOG_PATH}"
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ] && [ "${tmpMain}" != "" ]
    then
    /system/bin/logcat -G 5M
    /system/bin/logcat -f ${ROOT_SDCARD_apps_LOG_PATH}/android.txt -r${androidSize} -n ${androidCount}  -v threadtime -A
    else
    setprop ctl.stop logcatsdcard
    fi
}

function LogcatRadio2(){
    radioenable=`getprop persist.sys.assert.panic`
    argtrue='true'
    echo "LogcatRadio2 radioenable=${radioenable} tmpRadio=${tmpRadio}"
    echo "LogcatRadio2 radioSize=${radioSize} radioSize=${radioSize}"
    if [ "${radioenable}" = "${argtrue}" ] && [ "${tmpRadio}" != "" ]
    then
    /system/bin/logcat -b radio -f ${ROOT_SDCARD_apps_LOG_PATH}/radio.txt -r${radioSize} -n ${radioCount}  -v threadtime -A
    else
    setprop ctl.stop logcatradio
    fi
}
function LogcatEvent2(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    echo "LogcatEvent2 panicenable=${panicenable} tmpEvent=${tmpEvent}"
    echo "LogcatEvent2 eventSize=${eventSize} eventCount=${eventCount}"
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ] && [ "${tmpEvent}" != "" ]
    then
    /system/bin/logcat -b events -f ${ROOT_SDCARD_apps_LOG_PATH}/events.txt -r${eventSize} -n ${eventCount}  -v threadtime -A
    else
    setprop ctl.stop logcatevent
    fi
}
function LogcatKernel2(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    echo "LogcatKernel2 panicenable=${panicenable} tmpKernel=${tmpKernel}"
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ] && [ "${tmpKernel}" != "" ]
    then
    #TODO:wenzhen android O
    #cat proc/cmdline > ${ROOT_SDCARD_kernel_LOG_PATH}/cmdline.txt
    /system/xbin/klogd -f - -n -x -l 7 | $XKIT tee - ${ROOT_SDCARD_kernel_LOG_PATH}/kinfo0.txt | $XKIT awk 'NR%400==0'
    fi
}
function tcpdumpLog2(){
    tcpdmpenable=`getprop persist.sys.assert.panic`
    argtrue='true'
    echo "tcpdumpLog2 tcpdmpenable=${tcpdmpenable} tmpTcpdump=${tmpTcpdump}"
    echo "tcpdumpLog2 tcpdumpSize=${tcpdumpSize} tcpdumpCount=${tcpdumpCount}"
    if [ "${tcpdmpenable}" = "${argtrue}" ] && [ "${tmpTcpdump}" != "" ]
    then
        system/xbin/tcpdump -i any -p -s 0 -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${ROOT_SDCARD_netlog_LOG_PATH}/tcpdump -Z root
    fi
}

##add for log kit 2 end
function clearCurrentLog(){
    filelist=`cat /sdcard/oppo_log/transfer_list.txt | $XKIT awk '{print $1}'`
    for i in $filelist;do
    echo "${i}"
        rm -rf /sdcard/oppo_log/$i
    done
    rm -rf /sdcard/oppo_log/screenshot
    rm -rf /sdcard/oppo_log/diag_logs/*_*
    rm -rf /sdcard/oppo_log/transfer_list.txt
    rm -rf /sdcard/oppo_log/description.txt
    rm -rf /sdcard/oppo_log/xlog
    rm -rf /sdcard/oppo_log/powerlog
    rm -rf /sdcard/oppo_log/systrace
}

function moveScreenRecord(){
    fileName=`getprop sys.screenrecord.name`
    zip=.zip
    mp4=.mp4
    mv -f "/data/media/0/oppo_log/${fileName}${zip}" "/data/media/0/oppo_log/compress_log/${fileName}${zip}"
    mv -f "/data/media/0/oppo_log/screen_record/screen_record.mp4" "/data/media/0/oppo_log/compress_log/${fileName}${mp4}"
}

function clearDataOppoLog(){
    rm -rf /data/oppo_log/*
    # rm -rf /sdcard/oppo_log/diag_logs/*_*
    setprop sys.clear.finished 1
}

function tranferTombstone() {
    srcpath=`getprop sys.tombstone.file`
    subPath=`getprop persist.sys.com.oppo.debug.time`
    TOMBSTONE_TIME=`date +%F-%H-%M-%S`
    cp ${srcpath} /data/oppo_log/${subPath}/tombstone/tomb_${TOMBSTONE_TIME}
}

function tranferAnr() {
    srcpath=`getprop sys.anr.srcfile`
    subPath=`getprop persist.sys.com.oppo.debug.time`
    destfile=`getprop sys.anr.destfile`

    cp ${srcpath} /data/oppo_log/${subPath}/anr/${destfile}
    cp -rf ${ANR_BINDER_PATH} /data/oppo_log/${subPath}/anr/
}

function cppstore() {
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    argtrue='true'
    srcpstore=`ls /sys/fs/pstore`
    subPath=`getprop persist.sys.com.oppo.debug.time`

    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then

        if [ "${srcpstore}" != "" ]; then
        cp -r /sys/fs/pstore /data/oppo_log/${subPath}/pstore
        fi
    fi
}
function enabletcpdump(){
        mount -o rw,remount,barrier=1 /system
        chmod 6755 /system/xbin/tcpdump
        mount -o ro,remount,barrier=1 /system
}


#ifdef VENDOR_EDIT
#Deliang.Peng@PSW.MultiMedia.Display.Service.Log, 2017/3/31,add for dump sf back trace
function sfdump() {
    LOGTIME=`date +%F-%H-%M-%S`
    SWTPID=`getprop debug.swt.pid`
    JUNKLOGSFBACKPATH=/data/oppo_log/sf/${LOGTIME}
    mkdir -p ${JUNKLOGSFBACKPATH}
    cat proc/stat > ${JUNKLOGSFBACKPATH}/proc_stat.txt &
    cat proc/${SWTPID}/stat > ${JUNKLOGSFBACKPATH}/swt_stat.txt &
    cat proc/${SWTPID}/stack > ${JUNKLOGSFBACKPATH}/swt_proc_stack.txt &
    cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_0_.txt &
    cat /sys/devices/system/cpu/cpu1/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_1.txt &
    cat /sys/devices/system/cpu/cpu2/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_2.txt &
    cat /sys/devices/system/cpu/cpu3/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_3.txt &
    cat /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_4.txt &
    cat /sys/devices/system/cpu/cpu5/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_5.txt &
    cat /sys/devices/system/cpu/cpu6/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_6.txt &
    cat /sys/devices/system/cpu/cpu7/cpufreq/cpuinfo_cur_freq > ${JUNKLOGSFBACKPATH}/cpu_freq_7.txt &
    cat /sys/devices/system/cpu/cpu0/online > ${JUNKLOGSFBACKPATH}/cpu_online_0_.txt &
    cat /sys/devices/system/cpu/cpu1/online > ${JUNKLOGSFBACKPATH}/cpu_online_1_.txt &
    cat /sys/devices/system/cpu/cpu2/online > ${JUNKLOGSFBACKPATH}/cpu_online_2_.txt &
    cat /sys/devices/system/cpu/cpu3/online > ${JUNKLOGSFBACKPATH}/cpu_online_3_.txt &
    cat /sys/devices/system/cpu/cpu4/online > ${JUNKLOGSFBACKPATH}/cpu_online_4_.txt &
    cat /sys/devices/system/cpu/cpu5/online > ${JUNKLOGSFBACKPATH}/cpu_online_5_.txt &
    cat /sys/devices/system/cpu/cpu6/online > ${JUNKLOGSFBACKPATH}/cpu_online_6_.txt &
    cat /sys/devices/system/cpu/cpu7/online > ${JUNKLOGSFBACKPATH}/cpu_online_7_.txt &
    cat /sys/class/kgsl/kgsl-3d0/gpuclk > ${JUNKLOGSFBACKPATH}/gpuclk.txt &
    ps -t > ${JUNKLOGSFBACKPATH}/ps.txt
    top -n 1 -m 5 > ${JUNKLOGSFBACKPATH}/top.txt  &
    cp -R /data/sf ${JUNKLOGSFBACKPATH}/user_backtrace
    rm -rf /data/sf/*
}

function sfsystrace(){
    systrace_duration=`10`
    LOGTIME=`date +%F-%H-%M-%S`
    JUNKLOGSSFSYSPATH=/data/oppo_log/sf/trace/${LOGTIME}
    mkdir -p ${JUNKLOGSSFSYSPATH}
    CATEGORIES=`atrace --list_categories | $XKIT awk '{printf "%s ", $1}'`
    echo ${CATEGORIES} > ${JUNKLOGSSFSYSPATH}/categories.txt
    atrace -z -b 4096 -t ${systrace_duration} ${CATEGORIES} > ${JUNKLOGSSFSYSPATH}/atrace_raw
    /system/bin/ps -T -A  > ${SYSTRACE_DIR}/ps.txt
    /system/bin/printf "%s\n" /proc/[0-9]*/task/[0-9]* > ${SYSTRACE_DIR}/task.txt
}

#endif

#ifdef VENDOR_EDIT
#Yanzhen.Feng@Swdp.Android.OppoDebug.LayerDump, 2015/12/09, Add for SurfaceFlinger Layer dump
function layerdump(){
    mkdir -p ${ROOT_AUTOTRIGGER_PATH}/LayerDump
    LOGTIME=`date +%F-%H-%M-%S`
    ROOT_SDCARD_LAYERDUMP_PATH=${ROOT_AUTOTRIGGER_PATH}/LayerDump/LayerDump_${LOGTIME}
    cp -R /data/oppo/log/layerdump ${ROOT_SDCARD_LAYERDUMP_PATH}
    rm -rf /data/oppo/log/layerdump
    cp -R /data/log ${ROOT_SDCARD_LAYERDUMP_PATH}
    rm -rf /data/log
}
#endif /* VENDOR_EDIT */
#ifdef VENDOR_EDIT
#Yanzhen.Feng@Swdp.Android.OppoDebug, 2017/03/20, Add for systrace on phone
function cont_systrace(){
    mkdir -p ${ROOT_AUTOTRIGGER_PATH}/systrace
    CATEGORIES=`atrace --list_categories | $XKIT awk '{printf "%s ", $1}'`
    echo ${CATEGORIES} > ${ROOT_AUTOTRIGGER_PATH}/systrace/categories.txt
    while true
    do
        systrace_duration=`getprop debug.oppo.systrace.duration`
        if [ "$systrace_duration" != "" ]
        then
            LOGTIME=`date +%F-%H-%M-%S`
            SYSTRACE_DIR=${ROOT_AUTOTRIGGER_PATH}/systrace/systrace_${LOGTIME}
            mkdir -p ${SYSTRACE_DIR}
            ((sytrace_buffer=$systrace_duration*1536))
            atrace -z -b ${sytrace_buffer} -t ${systrace_duration} ${CATEGORIES} > ${SYSTRACE_DIR}/atrace_raw
            /system/bin/ps -AT -o USER,TID,PID,VSIZE,RSS,WCHAN,ADDR,CMD > ${SYSTRACE_DIR}/ps.txt
            /system/bin/printf "%s\n" /proc/[0-9]*/task/[0-9]* > ${SYSTRACE_DIR}/task.txt

            systrace_status=`getprop debug.oppo.cont_systrace`
            if [ "$systrace_status" == "false" ]; then
                break
            fi
        fi
    done
}
#endif /* VENDOR_EDIT */

#ifdef VENDOR_EDIT
#fangpan@Swdp.shanghai, 2017/06/05, Add for systrace snapshot mode
function systrace_trigger_start(){
    setprop debug.oppo.snaptrace true
    mkdir -p ${ROOT_AUTOTRIGGER_PATH}/systrace
    CATEGORIES=`atrace --list_categories | $XKIT awk '{printf "%s ", $1}'`
    echo ${CATEGORIES} > ${ROOT_AUTOTRIGGER_PATH}/systrace/categories.txt
    atrace -b 4096 --async_start ${CATEGORIES}
}
function systrace_trigger_stop(){
    atrace --async_stop
    setprop debug.oppo.snaptrace false
}
function systrace_snapshot(){
    LOGTIME=`date +%F-%H-%M-%S`
    SYSTRACE=${ROOT_AUTOTRIGGER_PATH}/systrace/systrace_${LOGTIME}.log
    echo 1 > /d/tracing/snapshot
    cat /d/tracing/snapshot > ${SYSTRACE}
}
#endif /* VENDOR_EDIT */

#RunSheng.Pei@PSW.AD.OppoDebug.1463805, 2018/07/02, Add for systrace config, begin {
function systrace_config() {
    cur_config_name_to_set=`getprop sys.oppo.logkit.tracename`
    echo "$paramP1"
    echo "$paramP2"
    echo "$cur_config_name_to_set"

    if [ "on" = "$paramP2" ] ; then
        echo "branch if"
        setValue="1"
        setprop sys.oppo.logkit.tr${cur_config_name_to_set} true
    else
        echo "branch else"
        setValue="0"
        setprop sys.oppo.logkit.tr${cur_config_name_to_set} false
    fi

    if [ ${cur_config_name_to_set} = "cpu" ] ; then
        echo ${setValue} > /d/tracing/events/sched/sched_enq_deq_task/enable
        echo ${setValue} > /d/tracing/events/sched/sched_migrate_task/enable
        echo ${setValue} > /d/tracing/events/sched/sched_wakeup/enable
        echo ${setValue} > /d/tracing/events/sched/sched_wakeup_new/enable
        echo ${setValue} > /d/tracing/events/sched/sched_waking/enable
        echo ${setValue} > /d/tracing/events/msm_low_power/enable
        echo ${setValue} > /d/tracing/events/sched/sched_set_boost/enable
        echo ${setValue} > /d/tracing/events/sched/sched_set_preferred_cluster/enable
        echo ${setValue} > /d/tracing/events/sched/sched_cpu_load_lb/enable
        echo ${setValue} > /d/tracing/events/sched/sched_energy_diff/enable
        echo ${setValue} > /d/tracing/events/sched/sched_energy_diff_packing/enable
        echo ${setValue} > /d/tracing/events/sched/sched_migrate_task/enable
        echo ${setValue} > /d/tracing/events/sched/sched_task_util_bias_to_waker/enable
        echo ${setValue} > /d/tracing/events/sched/sched_task_util_boosted/enable
        echo ${setValue} > /d/tracing/events/sched/sched_task_util_colocated/enable
        echo ${setValue} > /d/tracing/events/sched/sched_task_util_energy_aware/enable
        echo ${setValue} > /d/tracing/events/sched/sched_task_util_energy_diff/enable
        echo ${setValue} > /d/tracing/events/sched/sched_task_util_imbalance/enable
        echo ${setValue} > /d/tracing/events/sched/sched_task_util_need_idle/enable
        echo ${setValue} > /d/tracing/events/sched/sched_task_util_overutilzed/enable
        echo ${setValue} > /d/tracing/events/power/pm_qos_update_request/enable
        echo ${setValue} > /d/tracing/events/power/pm_qos_update_target/enable
        echo ${setValue} > /d/tracing/events/clk/clk_set_rate/enable
        echo ${setValue} > /d/tracing/events/sde/enable
    else
        #branch for other systrace configs.
        echo "else branch"
    fi
}
#end }

function junklogcat() {
    # echo 1 > sdcard/0.txt
    is_europe=`getprop ro.oppo.regionmark`
    if [ x"${is_europe}" != x"EUEX" ]; then
        JUNKLOGPATH=/sdcard/oppo_log/junk_logs
    else
        JUNKLOGPATH=/data/oppo/log/DCS/junk_logs_tmp
    fi
    mkdir -p ${JUNKLOGPATH}
    # echo 1 > sdcard/1.txt
    # echo 1 > ${JUNKLOGPATH}/1.txt
    system/bin/logcat -f ${JUNKLOGPATH}/junklogcat.txt -v threadtime *:V
}
function junkdmesg() {
    is_europe=`getprop ro.oppo.regionmark`
    if [ x"${is_europe}" != x"EUEX" ]; then
        JUNKLOGPATH=/sdcard/oppo_log/junk_logs
    else
        JUNKLOGPATH=/data/oppo/log/DCS/junk_logs_tmp
    fi
    mkdir -p ${JUNKLOGPATH}
    system/bin/dmesg > ${JUNKLOGPATH}/junkdmesg.txt
}
function junksystrace_start() {
    is_europe=`getprop ro.oppo.regionmark`
    if [ x"${is_europe}" != x"EUEX" ]; then
        JUNKLOGPATH=/sdcard/oppo_log/junk_logs
    else
        JUNKLOGPATH=/data/oppo/log/DCS/junk_logs_tmp
    fi
    mkdir -p ${JUNKLOGPATH}
    # echo s_start > sdcard/s_start1.txt
    #setup
    setprop debug.atrace.tags.enableflags 0x86E
    # stop;start
    adb shell "echo 16384 > /sys/kernel/debug/tracing/buffer_size_kb"

    echo nop > /sys/kernel/debug/tracing/current_tracer
    echo 'sched_switch sched_wakeup sched_wakeup_new sched_migrate_task binder workqueue irq cpu_frequency mtk_events' > /sys/kernel/debug/tracing/set_event
#just in case tracing_enabled is disabled by user or other debugging tool
    echo 1 > /sys/kernel/debug/tracing/tracing_enabled >nul 2>&1
    echo 0 > /sys/kernel/debug/tracing/tracing_on
#erase previous recorded trace
    echo > /sys/kernel/debug/tracing/trace
    echo press any key to start capturing...
    echo 1 > /sys/kernel/debug/tracing/tracing_on
    echo "Start recordng ftrace data"
    echo s_start > sdcard/s_start2.txt
}
function junksystrace_stop() {
    is_europe=`getprop ro.oppo.regionmark`
    if [ x"${is_europe}" != x"EUEX" ]; then
        JUNKLOGPATH=/sdcard/oppo_log/junk_logs
    else
        JUNKLOGPATH=/data/oppo/log/DCS/junk_logs_tmp
    fi
    mkdir -p ${JUNKLOGPATH}
    echo s_stop > sdcard/s_stop.txt
    echo 0 > /sys/kernel/debug/tracing/tracing_on
    echo "Recording stopped..."
    cp /sys/kernel/debug/tracing/trace ${JUNKLOGPATH}/junksystrace
    echo 1 > /sys/kernel/debug/tracing/tracing_on

}

#ifdef VENDOR_EDIT
#Zhihao.Li@MultiMedia.AudioServer.FrameWork, 2016/10/19, Add for clean pcm dump file.
function cleanpcmdump() {
    rm -rf /sdcard/oppo_log/pcm_dump/*
}
#endif /* VENDOR_EDIT */

#ifdef VENDOR_EDIT
#Jianping.Zheng@Swdp.Android.Stability.Crash, 2016/08/09, Add for logd memory leak workaround
function check_logd_memleak() {
    logd_mem=`ps  | grep -i /system/bin/logd | $XKIT awk '{print $5}'`
    #echo "logd_mem:"$logd_mem
    if [ "$logd_mem" != "" ]; then
        upper_limit=300000;
        if [ $logd_mem -gt $upper_limit ]; then
            #echo "logd_mem great than $upper_limit, restart logd"
            setprop persist.sys.assert.panic false
            setprop ctl.stop logcatsdcard
            setprop ctl.stop logcatradio
            setprop ctl.stop logcatevent
            setprop ctl.stop logcatkernel
            setprop ctl.stop tcpdumplog
            setprop ctl.stop fingerprintlog
            setprop ctl.stop fplogqess
            sleep 2
            setprop ctl.restart logd
            sleep 2
            setprop persist.sys.assert.panic true
        fi
    fi
}
#endif /* VENDOR_EDIT */

function gettpinfo() {
    tplogflag=`getprop persist.sys.oppodebug.tpcatcher`
    # tplogflag=511
    # echo "$tplogflag"
    if [ "$tplogflag" == "" ]
    then
        echo "tplogflag == error"
    else

        echo "tplogflag == $tplogflag"
        # tplogflag=`echo $tplogflag | $XKIT awk '{print lshift($0, 1)}'`
        tpstate=0
        tpstate=`echo $tplogflag | $XKIT awk '{print and($1, 1)}'`
        echo "switch tpstate = $tpstate"
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off"
        else
            echo "switch tpstate on"
            ROOT_SDCARD_kernel_LOG_PATH=`getprop sys.oppo.logkit.kernellog`
            kernellogpath=${ROOT_SDCARD_kernel_LOG_PATH}/tp_debug_info
            subcur=`date +%F-%H-%M-%S`
            subpath=$kernellogpath/$subcur.txt
            mkdir -p $kernellogpath
            # mFlagMainRegister = 1 << 1
            subflag=`echo | $XKIT awk '{print lshift(1, 1)}'`
            echo "1 << 1 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 1 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 1 $tpstate"
                echo /proc/touchpanel/debug_info/main_register  >> $subpath
                cat /proc/touchpanel/debug_info/main_register  >> $subpath
            fi
            # mFlagSelfDelta = 1 << 2;
            subflag=`echo | $XKIT awk '{print lshift(1, 2)}'`
            echo " 1<<2 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 2 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 2 $tpstate"
                echo /proc/touchpanel/debug_info/self_delta  >> $subpath
                cat /proc/touchpanel/debug_info/self_delta  >> $subpath
            fi
            # mFlagDetal = 1 << 3;
            subflag=`echo | $XKIT awk '{print lshift(1, 3)}'`
            echo "1 << 3 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 3 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 3 $tpstate"
                echo /proc/touchpanel/debug_info/delta  >> $subpath
                cat /proc/touchpanel/debug_info/delta  >> $subpath
            fi
            # mFlatSelfRaw = 1 << 4;
            subflag=`echo | $XKIT awk '{print lshift(1, 4)}'`
            echo "1 << 4 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 4 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 4 $tpstate"
                echo /proc/touchpanel/debug_info/self_raw  >> $subpath
                cat /proc/touchpanel/debug_info/self_raw  >> $subpath
            fi
            # mFlagBaseLine = 1 << 5;
            subflag=`echo | $XKIT awk '{print lshift(1, 5)}'`
            echo "1 << 5 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 5 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 5 $tpstate"
                echo /proc/touchpanel/debug_info/baseline  >> $subpath
                cat /proc/touchpanel/debug_info/baseline  >> $subpath
            fi
            # mFlagDataLimit = 1 << 6;
            subflag=`echo | $XKIT awk '{print lshift(1, 6)}'`
            echo "1 << 6 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 6 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 6 $tpstate"
                echo /proc/touchpanel/debug_info/data_limit  >> $subpath
                cat /proc/touchpanel/debug_info/data_limit  >> $subpath
            fi
            # mFlagReserve = 1 << 7;
            subflag=`echo | $XKIT awk '{print lshift(1, 7)}'`
            echo "1 << 7 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 7 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 7 $tpstate"
                echo /proc/touchpanel/debug_info/reserve  >> $subpath
                cat /proc/touchpanel/debug_info/reserve  >> $subpath
            fi
            # mFlagTpinfo = 1 << 8;
            subflag=`echo | $XKIT awk '{print lshift(1, 8)}'`
            echo "1 << 8 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 8 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 8 $tpstate"
            fi

            echo $tplogflag " end else"
        fi
    fi

}
function inittpdebug(){
    panicstate=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    tplogflag=`getprop persist.sys.oppodebug.tpcatcher`
    if [ "$tplogflag" != "" ]
    then
        echo "inittpdebug not empty panicstate = $panicstate tplogflag = $tplogflag"
        if [ "$panicstate" == "true" ] || [ x"${camerapanic}" = x"true" ]
        then
            tplogflag=`echo $tplogflag , | $XKIT awk '{print or($1, 1)}'`
        else
            tplogflag=`echo $tplogflag , | $XKIT awk '{print and($1, 510)}'`
        fi
        setprop persist.sys.oppodebug.tpcatcher $tplogflag
    fi
}
function settplevel(){
    tplevel=`getprop persist.sys.oppodebug.tplevel`
    if [ "$tplevel" == "0" ]
    then
        echo 0 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "1" ]
    then
        echo 1 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "2" ]
    then
        echo 2 > /proc/touchpanel/debug_level
    fi
}
#ifdef VENDOR_EDIT
#Canjie.Zheng@Swdp.Android.OppoDebug.LogKit,2017/01/21,add for ftm
function logcatftm(){
    /system/bin/logcat  -f /persist/ftm_admin/apps/android.txt -r1024 -n 6  -v threadtime *:V
}

function klogdftm(){
    /system/xbin/klogd -f /persist/ftm_admin/kernel/kinfox.txt -n -x -l 8
}
#Canjie.Zheng@Swdp.Android.OppoDebug.LogKit,2017/03/09, add for Sensor.logger
function resetlogpath(){
    systemSatus="SI_stop"
    getSystemSatus;
    setprop sys.oppo.logkit.appslog ""
    setprop sys.oppo.logkit.kernellog ""
    setprop sys.oppo.logkit.netlog ""
    setprop sys.oppo.logkit.assertlog ""
    setprop sys.oppo.logkit.anrlog ""
    setprop sys.oppo.logkit.tombstonelog ""
    setprop sys.oppo.logkit.fingerprintlog ""
}

function pwkdumpon(){
    platform=`getprop ro.board.platform`

    if [ "${platform}" = "msm8953" ]
    then
        echo "8953"
        echo 0x843 > /d/spmi/spmi-0/address
        echo 0x80 > /d/spmi/spmi-0/data
        echo 0x842 > /d/spmi/spmi-0/address
        echo 0x01 > /d/spmi/spmi-0/data
        echo 0x840 > /d/spmi/spmi-0/address
        echo 0x0F > /d/spmi/spmi-0/data
        echo 0x841 > /d/spmi/spmi-0/address
        echo 0x05 > /d/spmi/spmi-0/data
    elif [ "${platform}" = "sdm660" ] || [ "${platform}" = "sdm845" ]
    then
        echo "sdm660 845"
        echo 0x843 > /d/regmap/spmi0-00/address
        echo 0x80 > /d/regmap/spmi0-00/data
        echo 0x842 > /d/regmap/spmi0-00/address
        echo 0x01 > /d/regmap/spmi0-00/data
        echo 0x840 > /d/regmap/spmi0-00/address
        echo 0x0F > /d/regmap/spmi0-00/data
        echo 0x841 > /d/regmap/spmi0-00/address
        echo 0x07 > /d/regmap/spmi0-00/data
    fi
}

function pwkdumpoff(){
    platform=`getprop ro.board.platform`

    if [ "${platform}" = "msm8953" ]
    then
        echo "8953"
        echo 0x843 > /d/spmi/spmi-0/address
        echo 0x00 > /d/spmi/spmi-0/data
        echo 0x842 > /d/spmi/spmi-0/address
        echo 0x07 > /d/spmi/spmi-0/data

    elif [ "${platform}" = "sdm660" ]  || [ "${platform}" = "sdm845" ]
    then
        echo "sdm660 845"
        echo 0x843 > /d/regmap/spmi0-00/address
        echo 0x00 > /d/regmap/spmi0-00/data
        echo 0x842 > /d/regmap/spmi0-00/address
        echo 0x07 > /d/regmap/spmi0-00/data
    fi
}

function dumpon(){
    platform=`getprop ro.board.platform`

    if [ "${platform}" = "msm8953" ]
    then
        echo 1 > /sys/module/msm_poweroff/parameters/download_mode
    elif [ "${platform}" = "sdm660" ]  || [ "${platform}" = "sdm845" ]
    then
        echo full > /sys/kernel/dload/dload_mode
        echo 0 > /sys/kernel/dload/emmc_dload
#ifdef VENDOR_EDIT
#Haitao.Zhou@BSP.Kernel.Stability, 2017/06/27, add for mini dump and full dump swicth
#Ziqing.Guo@BSP.Kernel.Stability, 2018/01/13, add for mini dump and full dump swicth
        boot_completed=`getprop sys.boot_completed`
        if [ x${boot_completed} == x"1" ]; then
            dd if=/vendor/firmware/dpAP_full.mbn of=/dev/block/bootdevice/by-name/apdp
            sync
        fi
#endif
    fi

#a506_zap
    echo system > /sys/bus/msm_subsys/devices/subsys0/restart_level
#venus
    echo system > /sys/bus/msm_subsys/devices/subsys1/restart_level
#adsp
    echo system > /sys/bus/msm_subsys/devices/subsys2/restart_level
#wcnss
    echo system > /sys/bus/msm_subsys/devices/subsys3/restart_level
#ifdef VENDOR_EDIT
#modem
#zhaokai@Network.modem,2016/08/01,add for modem subsystem
    echo system > /sys/bus/msm_subsys/devices/subsys4/restart_level
#endif
     if [ "${platform}" = "sdm845" ]
     then
        echo system > /sys/bus/msm_subsys/devices/subsys5/restart_level
        echo system > /sys/bus/msm_subsys/devices/subsys6/restart_level
        echo system > /sys/bus/msm_subsys/devices/subsys7/restart_level
     fi
}

function dumpoff(){
    platform=`getprop ro.board.platform`

    if [ "${platform}" = "msm8953" ]
    then
        echo 0 > /sys/module/msm_poweroff/parameters/download_mode
    elif [ "${platform}" = "sdm660" ]  || [ "${platform}" = "sdm845" ]
    then
        echo mini > /sys/kernel/dload/dload_mode
        echo 1 > /sys/kernel/dload/emmc_dload
#ifdef VENDOR_EDIT
#Haitao.Zhou@BSP.Kernel.Stability, 2017/06/27, add for mini dump and full dump swicth
#Ziqing.Guo@BSP.Kernel.Stability, 2018/01/13, add for mini dump and full dump swicth
        boot_completed=`getprop sys.boot_completed`
        if [ x${boot_completed} == x"1" ]; then
            dd if=/vendor/firmware/dpAP_mini.mbn of=/dev/block/bootdevice/by-name/apdp
            sync
        fi
#endif
    fi

#a506_zap
    echo related > /sys/bus/msm_subsys/devices/subsys0/restart_level
#venus
    echo related > /sys/bus/msm_subsys/devices/subsys1/restart_level
#adsp
    echo related > /sys/bus/msm_subsys/devices/subsys2/restart_level
#wcnss
    echo related > /sys/bus/msm_subsys/devices/subsys3/restart_level
#ifdef VENDOR_EDIT
#modem
#zhaokai@Network.modem,2016/08/01,add for modem subsystem
    echo related > /sys/bus/msm_subsys/devices/subsys4/restart_level
#endif
     if [ "${platform}" = "sdm845" ]
     then
        echo related > /sys/bus/msm_subsys/devices/subsys5/restart_level
        echo related > /sys/bus/msm_subsys/devices/subsys6/restart_level
        echo related > /sys/bus/msm_subsys/devices/subsys7/restart_level
     fi
}

function test(){
    panicenable=`getprop persist.sys.assert.panic`
    mkdir -p /data/test_log_kit
    touch /data/oppo_log/test_log_kit/debug.txt
    echo ${panicenable} > /data/oppo_log/test_log_kit/debug.txt
    /system/bin/logcat -f /data/oppo_log/android_winston.txt -r102400 -n 100  -v threadtime -A
}

function rmminidump(){
    rm -rf /data/system/dropbox/minidump.bin
}

function readdump(){
    echo "begin readdump"
    platform=`getprop ro.board.platform`
    if [ "${platform}" = "sdm660" ]  || [ "${platform}" = "sdm845" ]
    then
        system/bin/minidumpreader
        echo "dump end"

        echo "chown end"
    fi
}
function packupminidump() {

    timestamp=`getprop sys.oppo.minidump.ts`
    echo time ${timestamp}
    packupname=/data/oppo/log/DCS/SYSTEM_LAST_KMSG@${timestamp}
    echo name ${packupname}
    #read device info begin
    #"/proc/oppoVersion/serialID",
    #"/proc/devinfo/ddr",
    #"/proc/devinfo/emmc",
    #"proc/devinfo/emmc_version"};
    model=`getprop ro.product.model`
    version=`getprop ro.build.version.ota`
    echo "model:${model}" > /data/oppo/log/DCS/minidump/device.info
    echo "version:${version}" >> /data/oppo/log/DCS/minidump/device.info
    echo "/proc/oppoVersion/serialID" >> /data/oppo/log/DCS/minidump/device.info
    cat /proc/oppoVersion/serialID >> /data/oppo/log/DCS/minidump/device.info
    echo "\n/proc/devinfo/ddr" >> /data/oppo/log/DCS/minidump/device.info
    cat /proc/devinfo/ddr >> /data/oppo/log/DCS/minidump/device.info
    echo "/proc/devinfo/emmc" >> /data/oppo/log/DCS/minidump/device.info
    cat /proc/devinfo/emmc >> /data/oppo/log/DCS/minidump/device.info
    echo "/proc/devinfo/emmc_version" >> /data/oppo/log/DCS/minidump/device.info
    cat /proc/devinfo/emmc_version >> /data/oppo/log/DCS/minidump/device.info
    echo "/proc/oppoVersion/ocp" >> /data/oppo/log/DCS/minidump/device.info
    cat /proc/oppoVersion/ocp >> /data/oppo/log/DCS/minidump/device.info
    echo "tar -czvf ${packupname} -C /data/oppo/log/DCS/minidump ."
    $XKIT tar -czvf ${packupname}.dat.gz.tmp -C /data/oppo/log/DCS/minidump .
    chown system:system ${packupname}*
    mv ${packupname}.dat.gz.tmp ${packupname}.dat.gz
    chown system:system ${packupname}*
    echo "-rf /data/oppo/log/DCS/minidump"
    rm -rf /data/oppo/log/DCS/minidump
}

#ifdef VENDOR_EDIT
#Junhao.Liang@PSW.AD.OppoDebug.LogKit.1378575, 2018/06/05, Add for recording information of ocp
function packupocp() {
    platform=`getprop ro.board.platform`
    ocpinfo=`cat /proc/oppoVersion/ocp`
    if [ "${platform}" = "sdm845" ] && [ x"${ocpinfo}" != x"ocp: 0 0 0 0" ]
    then
        timestamp_ns=`date +%s%N`
        echo time_ns ${timestamp_ns}
        timestamp=`expr ${timestamp_ns} / 1000000`
        echo time_ms ${timestamp}
        packupname=/data/oppo/log/DCS/SYSTEM_LAST_KMSG@${timestamp}
        echo name ${packupname}
        model=`getprop ro.product.model`
        version=`getprop ro.build.version.ota`
        mkdir /data/oppo/log/DCS/ocp
        echo "model:${model}" > /data/oppo/log/DCS/ocp/device.info
        echo "version:${version}" >> /data/oppo/log/DCS/ocp/device.info
        echo "/proc/oppoVersion/serialID" >> /data/oppo/log/DCS/ocp/device.info
        cat /proc/oppoVersion/serialID >> /data/oppo/log/DCS/ocp/device.info
        echo "\n/proc/devinfo/ddr" >> /data/oppo/log/DCS/ocp/device.info
        cat /proc/devinfo/ddr >> /data/oppo/log/DCS/ocp/device.info
        echo "/proc/devinfo/emmc" >> /data/oppo/log/DCS/ocp/device.info
        cat /proc/devinfo/emmc >> /data/oppo/log/DCS/ocp/device.info
        echo "/proc/devinfo/emmc_version" >> /data/oppo/log/DCS/ocp/device.info
        cat /proc/devinfo/emmc_version >> /data/oppo/log/DCS/ocp/device.info
        echo "/proc/oppoVersion/ocp" >> /data/oppo/log/DCS/ocp/device.info
        cat /proc/oppoVersion/ocp >> /data/oppo/log/DCS/ocp/device.info
        echo "tar -czvf ${packupname} -C /data/oppo/log/DCS/ocp ."
        $XKIT tar -czvf ${packupname}.tar.gz.tmp -C /data/oppo/log/DCS/ocp .
        chown system:system ${packupname}*
        mv ${packupname}.tar.gz.tmp ${packupname}.tar.gz
        chown system:system ${packupname}*
        echo "-rf /data/oppo/log/DCS/ocp"
        rm -rf /data/oppo/log/DCS/ocp
    fi
}
#endif VENDOR_EDIT

function junk_log_monitor(){
    is_europe=`getprop ro.oppo.regionmark`
    if [ x"${is_europe}" != x"EUEX" ]; then
        DIR=/sdcard/oppo_log/junk_logs/DCS
    else
        DIR=/data/oppo/log/DCS/de/junk_logs
    fi
    MAX_NUM=10
    IDX=0
    if [ -d "$DIR" ]; then
        ALL_FILE=`ls -t $DIR`
        for i in $ALL_FILE;
        do
            echo "now we have file $i"
            let IDX=$IDX+1;
            echo ========file num is $IDX===========
            if [ "$IDX" -gt $MAX_NUM ] ; then
               echo rm file $i\!;
            rm -rf $DIR/$i
            fi
        done
    fi
}

#endif VENDOR_EDIT

#Jianping.Zheng@PSW.Android.Stability.Crash,2017/06/12,add for record d status thread stack
function record_d_threads_stack() {
    record_path=$1
    echo "\ndate->" `date` >> ${record_path}
    ignore_threads="kworker/u16:1|mdss_dsi_event|mmc-cmdqd/0|msm-core:sampli|kworker/10:0|mdss_fb0"
    d_status_tids=`ps -t | grep " D " | grep -iEv "$ignore_threads" | $XKIT awk '{print $2}'`;
    if [ x"${d_status_tids}" != x"" ]
    then
        sleep 5
        d_status_tids_again=`ps -t | grep " D " | grep -iEv "$ignore_threads" | $XKIT awk '{print $2}'`;
        for tid in ${d_status_tids}
        do
            for tid_2 in ${d_status_tids_again}
            do
                if [ x"${tid}" == x"${tid_2}" ]
                then
                    thread_stat=`cat /proc/${tid}/stat | grep " D "`
                    if [ x"${thread_stat}" != x"" ]
                    then
                        echo "tid:"${tid} "comm:"`cat /proc/${tid}/comm` "cmdline:"`cat /proc/${tid}/cmdline`  >> ${record_path}
                        echo "stack:" >> ${record_path}
                        cat /proc/${tid}/stack >> ${record_path}
                    fi
                    break
                fi
            done
        done
    fi
}

#Jianping.Zheng@Swdp.Android.Stability.Crash,2017/04/04,add for record performance
function perf_record() {
    check_interval=`getprop persist.sys.oppo.perfinteval`
    if [ x"${check_interval}" = x"" ]; then
        check_interval=60
    fi
    perf_record_path=/data/oppo_log/perf_record_logs
    while [ true ];do
        if [ ! -d ${perf_record_path} ];then
            mkdir -p ${perf_record_path}
        fi

        echo "\ndate->" `date` >> ${perf_record_path}/cpu.txt
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq >> ${perf_record_path}/cpu.txt

        echo "\ndate->" `date` >> ${perf_record_path}/mem.txt
        cat /proc/meminfo >> ${perf_record_path}/mem.txt

        echo "\ndate->" `date` >> ${perf_record_path}/buddyinfo.txt
        cat /proc/buddyinfo >> ${perf_record_path}/buddyinfo.txt

        echo "\ndate->" `date` >> ${perf_record_path}/top.txt
        top -n 1 >> ${perf_record_path}/top.txt

        #record_d_threads_stack "${perf_record_path}/d_status.txt"

        sleep "$check_interval"
    done
}

#ifdef VENDOR_EDIT
#Qianyou.Chen@PSW.Android.OppoDebug.LogKit,2017/04/12, Add for wifi packet log
function prepacketlog(){
    panicstate=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    packetlogstate=`getprop persist.sys.wifipacketlog.state`
    packetlogbuffsize=`getprop persist.sys.wifipktlog.buffsize`
    timeout=0

    if [ "${panicstate}" = "true" ] || [ x"${camerapanic}" = x"true" ] && [ "${packetlogstate}" = "true" ];then
        echo Disable it before we set the size...
        iwpriv wlan0 pktlog 0
        while [ $? -ne "0" ];do
            echo wait util the file system is built.
            sleep 2
            if [ $timeout -gt 30 ];then
                echo less than the numbers  we want...
                echo can not finish prepacketlog... > ${DATA_LOG_PATH}/pktlog_error.txt
                iwpriv wlan0 pktlog 0 >> ${DATA_LOG_PATH}/pktlog_error.txt
                exit
            fi
            let timeout+=1;
            iwpriv wlan0 pktlog 0
        done
        if [ "${packetlogbuffsize}" = "1" ];then
            echo Set the pktlog buffer size to 100MB...
            pktlogconf -s 100000000 -a cld
        else
            echo Set the pktlog buffer size to 20MB...
            pktlogconf -s 20000000 -a cld
            setprop persist.sys.wifipktlog.buffersize 0
        fi

        echo Enable the pktlog...
        iwpriv wlan0 pktlog 1
    fi
}
function wifipktlogtransf(){
    LOGTIME=`getprop persist.sys.com.oppo.debug.time`
    ROOT_SDCARD_LOG_PATH=${DATA_LOG_PATH}/${LOGTIME}
    packetlogstate=`getprop persist.sys.wifipacketlog.state`

    boot_completed=`getprop sys.boot_completed`
    while [ x${boot_completed} != x"1" ];do
        echo sleep 5s...
        sleep 5
        boot_completed=`getprop sys.boot_completed`
    done

    iwpriv wlan0 pktlog 0
    while [ $? -ne "0" ];do
        echo wait util the file system is built.
        sleep 2
        if [ $timeout -gt 30 ];then
            echo less than the numbers  we want...
            echo can not finish prepacketlog... > ${DATA_LOG_PATH}/pktlog_error.txt
            iwpriv wlan0 pktlog 0 >> ${DATA_LOG_PATH}/pktlog_error.txt
            exit
        fi
        let timeout+=1;
        iwpriv wlan0 pktlog 0
    done
    if [ "${packetlogstate}" = "true" ];then
        echo transfer start...
        if [ ! -d ${ROOT_SDCARD_LOG_PATH}/wlan_logs ];then
            mkdir -p ${ROOT_SDCARD_LOG_PATH}/wlan_logs
        fi
        cat /proc/ath_pktlog/cld > ${ROOT_SDCARD_LOG_PATH}/wlan_logs/pktlog.dat
        iwpriv wlan0 pktlog 4
        echo transfer end...
    fi

    pktlogconf -s 10000000 -a cld
    iwpriv wlan0 pktlog 1
}

function pktcheck(){
    pktlogenable=`cat /persist/WCNSS_qcom_cfg.ini | grep gEnablePacketLog`
    savedenable=`getprop persist.sys.wifipktlog.enable`
    boot_completed=`getprop sys.boot_completed`

    echo avoid checking too early before WCNSS_qcom_cfg.ini is prepared...
    while [ x${boot_completed} != x"1" ];do
        echo sleep 5s...
        sleep 5
        boot_completed=`getprop sys.boot_completed`
    done

    echo wifipktlogfunccheck starts...
    if [ -z ${savedenable} ];then
        if [ "${pktlogenable#*=}" = "1" ];then
            echo set persist.sys.wifipktlog.enable true...
            setprop persist.sys.wifipktlog.enable true
        else
            echo set persist.sys.wifipktlog.enable false...
            setprop persist.sys.wifipktlog.enable false
            setprop persist.sys.wifipacketlog.state false
        fi
    fi
}
#endif VENDOR_EDIT

#Jianping.Zheng@PSW.Android..Stability.Crash, 2017/06/20, Add for collect futexwait block log
function collect_futexwait_log() {
    collect_path=/data/system/dropbox/extra_log
    if [ ! -d ${collect_path} ]
    then
        mkdir -p ${collect_path}
        chmod 700 ${collect_path}
        chown system:system ${collect_path}
    fi

    #time
    echo `date` > ${collect_path}/futexwait.time.txt

    #ps -t info
    ps -t > $collect_path/ps.txt

    #D status to dmesg
    echo w > /proc/sysrq-trigger

    #systemserver trace
    system_server_pid=`ps |grep system_server | $XKIT awk '{print $2}'`
    kill -3 ${system_server_pid}
    sleep 10
    cp /data/anr/traces.txt $collect_path/

    #systemserver native backtrace
    debuggerd64 -b ${system_server_pid} > $collect_path/systemserver.backtrace.txt
}

#Jianping.Zheng@PSW.Android.Stability.Crash,2017/05/08,add for systemserver futex_wait block check
function check_systemserver_futexwait_block() {
    futexblock_interval=`getprop persist.sys.futexblock.interval`
    if [ x"${futexblock_interval}" = x"" ]; then
        futexblock_interval=180
    fi

    exception_max=`getprop persist.sys.futexblock.max`
    if [ x"${exception_max}" = x"" ]; then
        exception_max=60
    fi

    while [ true ];do
        system_server_pid=`ps -A |grep system_server | $XKIT awk '{print $2}'`
        if [ x"${system_server_pid}" != x"" ]; then
            exception_count=0
            while [ $exception_count -lt $exception_max ] ;do
                systemserver_stack_status=`ps -A | grep system_server | $XKIT awk '{print $6}'`
                if [ x"${systemserver_stack_status}" != x"futex_wait_queue_me" ]; then
                    break
                fi

                inputreader_stack_status=`ps -A -T | grep InputReader  | $XKIT awk '{print $7}'`
                if [ x"${inputreader_stack_status}" == x"futex_wait_queue_me" ]; then
                    exception_count=`expr $exception_count + 1`
                    if [ x"${exception_count}" = x"${exception_max}" ]; then
                        echo "Systemserver,FutexwaitBlocked-"`date` > "/proc/sys/kernel/hung_task_oppo_kill"
                        setprop sys.oppo.futexwaitblocked "`date`"
                        collect_futexwait_log
                        kill -9 $system_server_pid
                        sleep 60
                        break
                    fi
                    sleep 1
                else
                    break
                fi
            done
        fi
        sleep "$futexblock_interval"
    done
}
#end, add for systemserver futex_wait block check

function getSystemSatus() {
    boot_completed=`getprop sys.boot_completed`
    if [ x${boot_completed} == x"1" ]
    then
        timeSub=`getprop persist.sys.com.oppo.debug.time`
        outputPath="${DATA_LOG_PATH}/${timeSub}/${systemSatus}"
        echo "SI path: ${outputPath}"
        mkdir -p ${outputPath}
        rm -f ${outputPath}/finish1
        if [ ! -d "${outputPath}" ];then
            mkdir -p ${outputPath}
        else
            setprop ctl.start dump_sysinfo
            sleep 1
        fi
        ps -T -A > ${outputPath}/ps.txt
        top -n 1 -s 10 > ${outputPath}/top.txt
        cat /proc/meminfo > ${outputPath}/proc_meminfo.txt
        cat /proc/interrupts > ${outputPath}/interrupts.txt
        cat /sys/kernel/debug/wakeup_sources > ${outputPath}/wakeup_sources.log
        getprop > ${outputPath}/prop.txt
        df > ${outputPath}/df.txt
        mount > ${outputPath}/mount.txt
        cat data/system/packages.xml  > ${outputPath}/packages.txt
        touch ${outputPath}/finish1
        echo "getSystemSatus done"
    fi
}

function DumpSysMeminfo() {
    timeSub=`getprop persist.sys.com.oppo.debug.time`
    outputPathStop="${DATA_LOG_PATH}/${timeSub}/SI_stop"
    outputPath="${DATA_LOG_PATH}/${timeSub}/SI_start"
    if [ ! -d "${outputPathStop}" ];then
        outputPath="${DATA_LOG_PATH}/${timeSub}/SI_start/wechat"
    else
        outputPath="${DATA_LOG_PATH}/${timeSub}/SI_stop/wechat"
    fi
    mkdir -p ${outputPath}
    rm -f ${outputPath}/finish_weixin
    touch /sdcard/oppo_log/test
    echo "===============" >> /sdcard/oppo_log/test
    echo ${outputPath} >> /sdcard/oppo_log/test
    dumpsys meminfo --package system > ${outputPath}/system_meminfo.txt
    dumpsys meminfo --package com.tencent.mm > ${outputPath}/weixin_meminfo.txt
    CURTIME=`date +%F-%H-%M-%S`
    ps -A | grep "tencent.mm" > ${outputPath}/weixin_${CURTIME}_ps.txt
    wechat_exdevice=`pgrep -f com.tencent.mm`
    echo "$wechat_exdevice" >> /sdcard/oppo_log/test
    if  [ ! -n "$wechat_exdevice" ] ;then
        touch ${outputPath}/finish_weixin
    else
        echo "$wechat_exdevice" | while read line
        do
        cat /proc/${line}/smaps > ${outputPath}/weixin_${line}.txt
        done
    fi
    dumpsys package > ${outputPath}/dumpsysy_package.txt
    touch ${outputPath}/finish_weixin
    echo "DumpMeminfo done" >> /sdcard/oppo_log/test
}

function DumpWechatMeminfo() {
    CURTIME=`date +%F-%H-%M-%S`
    outputPath="${ROOT_AUTOTRIGGER_PATH}/trigger/wechat_${CURTIME}"
    mkdir -p ${outputPath}
    rm -f ${outputPath}/finish_weixin
    touch /sdcard/oppo_log/test
    echo "===============" >> /sdcard/oppo_log/test
    echo ${outputPath} >> /sdcard/oppo_log/test
    dumpsys meminfo --package system > ${outputPath}/system_meminfo.txt
    dumpsys meminfo --package com.tencent.mm > ${outputPath}/weixin_meminfo.txt
    CURTIME=`date +%F-%H-%M-%S`
    ps -A | grep "tencent.mm" > ${outputPath}/weixin_${CURTIME}_ps.txt
    wechat_exdevice=`pgrep -f com.tencent.mm`
    echo "$wechat_exdevice" >> /sdcard/oppo_log/test
    if  [ ! -n "$wechat_exdevice" ] ;then
        touch ${outputPath}/finish_weixin
    else
        echo "$wechat_exdevice" | while read line
        do
        cat /proc/${line}/smaps > ${outputPath}/weixin_${line}.txt
        done
    fi
    dumpsys package > ${outputPath}/dumpsysy_package.txt
    touch ${outputPath}/finish_weixin
    echo "DumpMeminfo done" >> /sdcard/oppo_log/test
    rm -f /sdcard/oppo_log/test
}

function DumpStorage() {
    rm -rf ${ROOT_AUTOTRIGGER_PATH}/storage
    mkdir -p ${ROOT_AUTOTRIGGER_PATH}/storage
    mount > /sdcard/oppo_log/storage/mount.txt
    dumpsys devicestoragemonitor > /sdcard/oppo_log/storage/mount_device_storage_monitor.txt
    dumpsys mount > /sdcard/oppo_log/storage/mount_service.txt
    dumpsys diskstats > /sdcard/oppo_log/storage/diskstats.txt
    du -H /data > /sdcard/oppo_log/storage/diskUsage.txt
    echo "DumpStorage done"
}
#Fei.Mo@PSW.BSP.Sensor, 2017/09/05 ,Add for power monitor top info
function thermalTop(){
   top -m 3 -n 1 > /data/system/dropbox/thermalmonitor/top
   chown system:system /data/system/dropbox/thermalmonitor/top
}
#end, Add for power monitor top info

#Jianping.Zheng@PSW.AD.Stability.Crash.1354723, 2018/04/19, Add for collect fs info through DCS
function collectfsinfo() {
    cp /proc/fs/f2fs/dm-0/segment_bits /data/system/dropbox/segment_bits
    sed -i '1,2d' /data/system/dropbox/segment_bits
    cut -d '|' -f 2 /data/system/dropbox/segment_bits >/data/system/dropbox/segment_block_info
    valid_section=0
    total_section=0
    dirty_section=0
    free_section=0
    total_invalid_blkcnt=0
    total_valid_blkcnt=0
    while read LINE
    do
    #   echo "total_section:"$total_section:$LINE
        total_section=$(($total_section+1))
        if [ $LINE -eq 0 ]
        then
            free_section=$(($free_section+1))
        elif [ $LINE -eq 512 ]
        then
            valid_section=$(($valid_section+1))
        else
            dirty_section=$(($dirty_section+1))
            total_valid_blkcnt=$(($total_valid_blkcnt+$LINE))
            total_invalid_blkcnt=$(($total_invalid_blkcnt+512-$LINE))
        fi
    done < /data/system/dropbox/segment_block_info
    #echo "valid_section:"$valid_section
    echo "total_section:"$total_section > /data/system/dropbox/f2fs_segmentation_data.txt
    echo "dirty_section:"$dirty_section >> /data/system/dropbox/f2fs_segmentation_data.txt
    echo "free_section:"$free_section >> /data/system/dropbox/f2fs_segmentation_data.txt
    echo "total_invalid_blkcnt:"$total_invalid_blkcnt >> /data/system/dropbox/f2fs_segmentation_data.txt
    echo "total_valid_blkcnt:"$total_valid_blkcnt >> /data/system/dropbox/f2fs_segmentation_data.txt
    chown system:system /data/system/dropbox/f2fs_segmentation_data.txt
}

#Canjie.Zheng@PSW.AD.OppoDebug.LogKit.1078692, 2017/11/20, Add for iotop
function getiotop() {
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.camera.assert.panic`
    if [ x"${panicenable}" = x"true" ] || [ x"${camerapanic}" = x"true" ]; then
        APPS_LOG_PATH=`getprop sys.oppo.logkit.appslog`
        iotop=${APPS_LOG_PATH}/iotop.txt
        timestamp=`date +"%m-%d %H:%M:%S"\(timestamp\)`
        echo ${timestamp} >> ${iotop}
        iotop -m 5 -n 5 -P >> ${iotop}
    fi
}

#Weitao.Chen@PSW.AD.Stability.Crash.1295294, 2018/03/01, Add for trying to recover from sysetm hang
function recover_hang()
{
 #recover_hang_path="/data/system/dropbox/recover_hang"
 #persist.sys.oppo.scanstage is true recovery_hang service is started
 #sleep 40s for scan system to finish
 sleep 40
 scan_system_status=`getprop persist.sys.oppo.scanstage`
 if [ x"${scan_system_status}" == x"true" ]; then
    #after 20s, scan system has not finished, use debuggerd to catch system_server native trace
    system_server_pid=`ps -A | grep system_server | $XKIT awk '{print $2}'`
    debuggerd -b ${system_server_pid} > /data/system/dropbox/recover_hang_${system_server_pid}_$(date +%F-%H-%M-%S)_40;
 fi
 #sleep 60s for scan data to finish
 sleep 60
 if [ x"${scan_system_status}" == x"1" ]; then
    system_server_pid=`ps -A | grep system_server | $XKIT awk '{print $2}'`
    #use debuggerd to catch system_server native trace
    debuggerd -b ${system_server_pid} > /data/system/dropbox/recover_hang_${system_server_pid}_$(date +%F-%H-%M-%S)_60;
 fi
 boot_completed=`getprop sys.oppo.boot_completed`
 if [ x${boot_completed} != x"1" ]; then
    system_server_pid=`ps -A | grep system_server | $XKIT awk '{print $2}'`
    #use debuggerd to catch system_server native trace
    debuggerd -b ${system_server_pid} > /dev/null;
 fi
}

function logcusmain() {
    echo "logcusmain begin"
    path=/data/oppo_log/customer/apps
    mkdir -p ${path}
    /system/bin/logcat  -f ${path}/android.txt -r10240 -v threadtime *:V
    echo "logcusmain end"
}

function logcusevent() {
    echo "logcusevent begin"
    path=/data/oppo_log/customer/apps
    mkdir -p ${path}
    /system/bin/logcat -b events -f ${path}/event.txt -r10240 -v threadtime *:V
    echo "logcusevent end"
}

function logcusradio() {
    echo "logcusradio begin"
    path=/data/oppo_log/customer/apps
    mkdir -p ${path}
    /system/bin/logcat -b radio -f ${path}/radio.txt -r10240 -v threadtime *:V
    echo "logcusradio end"
}

function logcuskernel() {
    echo "logcuskernel begin"
    path=/data/oppo_log/customer/kernel
    mkdir -p ${path}
    /system/xbin/klogd -f - -n -x -l 7 | $XKIT tee - ${path}/kinfo0.txt | $XKIT awk 'NR%400==0'
    echo "logcuskernel end"
}

function logcustcp() {
    echo "logcustcp begin"
    path=/data/oppo_log/customer/tcpdump
    mkdir -p ${path}
    system/xbin/tcpdump -i any -p -s 0 -W 1 -C 50 -w ${path}/tcpdump.pcap  -Z root
    echo "logcustcp end"
}

function logcuswifi() {
    echo "logcuswifi begin"
    path=/data/oppo_log/customer/buffered_wlan_logs
    mkdir -p ${path}
    #pid=`ps -A | grep cnss_diag | tr -s ' ' | cut -d ' ' -f 2`
    pid=`getprop sys.wifi.cnss_diag_pid`
    if [ "$pid" != "" ]
    then
        kill -SIGUSR1 $pid
    fi
    cat /proc/ath_pktlog/cld > ${path}/pktlog.dat
    sleep 2
    cp /data/oppo_log/buffered_wlan_logs/* ${path}
    rm /data/oppo_log/buffered_wlan_logs/*
    setprop sys.oppo.log.customer.wifi true
    echo "logcuswifi end"
}

function setdebugoff() {
    is_camera =`getprop persist.sys.assert.panic.camera`
    if [ x"${is_camera}" = x"true" ]; then
        setprop persist.camera.assert.panic false
    else
        setprop persist.sys.assert.panic false
    fi
}


case "$config" in
##add for log kit 2 begin
    "tranfer2")
        Preprocess
        tranfer2
        ;;
    "deleteFolder")
        deleteFolder
        ;;
    "deleteOrigin")
        deleteOrigin
        ;;
    "testkit")
        initLogPath2
        ;;
    "calculateFolderSize")
        calculateFolderSize
        ;;
##add for log kit 2 end
    "ps")
        Preprocess
        Ps
        ;;
    "top")
        Preprocess
        Top
        ;;
    "server")
        Preprocess
        Server
        ;;
    "dump")
        Preprocess
        Dumpsys
        ;;
    "dump_sysinfo")
        DumpSysMeminfo
        ;;
    "dump_wechat_info")
        DumpWechatMeminfo
        ;;
    "dump_storage")
        DumpStorage
        ;;
    "tranfer")
        Preprocess
        tranfer
        ;;
    "tranfer_tombstone")
        tranferTombstone
        ;;
    "logcache")
        CacheLog
        ;;
    "logpreprocess")
        PreprocessLog
        ;;
    "prepacketlog")
        prepacketlog
        ;;
    "wifipktlogtransf")
        wifipktlogtransf
        ;;
    "pktcheck")
        pktcheck
        ;;
    "tranfer_anr")
        tranferAnr
        ;;
    "main")
    #logkit2
        # initLogPath
        # Logcat
    #logkit2
        initLogPath2
        Logcat2
        ;;
    "radio")
    #logkit2
        # initLogPath
        # LogcatRadio
    #logkit2
        initLogPath2
        LogcatRadio2
        ;;
    "fingerprint")
        initLogPath
        LogcatFingerprint
        ;;
    "fpqess")
        initLogPath
        LogcatFingerprintQsee
        ;;
    "event")
    #logkit2
        # initLogPath
        # LogcatEvent
    #logkit2
        initLogPath2
        LogcatEvent2
        ;;
    "kernel")
    #logkit2
        # initLogPath
        # LogcatKernel
    #logkit2
        initLogPath2
        LogcatKernel2
        ;;
    "tcpdump")
    #logkit2
        # initLogPath
        # enabletcpdump
        # tcpdumpLog
    #logkit2
        initLogPath2
        enabletcpdump
        tcpdumpLog2
        ;;
    "clean")
        CleanAll
        ;;
    "clearcurrentlog")
        clearCurrentLog
        ;;
    "calcutelogsize")
        calculateLogSize
        ;;
    "cleardataoppolog")
        clearDataOppoLog
        ;;
    "movescreenrecord")
        moveScreenRecord
        ;;
    "cppstore")
        initLogPath
        cppstore
        ;;
    "screen_record")
        initLogPath
        screen_record
        ;;
    "screen_record_backup")
        screen_record_backup
        ;;
#ifdef VENDOR_EDIT
#Deliang.Peng@MultiMedia.Display.Service.Log, 2017/3/31,
#add for dump sf back tracey
    "sfdump")
        sfdump
        ;;
    "sfsystrace")
        sfsystrace
        ;;
#endif /* VENDOR_EDIT */
#ifdef VENDOR_EDIT
#Yanzhen.Feng@Swdp.Android.OppoDebug.LayerDump, 2015/12/09, Add for SurfaceFlinger Layer dump
    "layerdump")
        layerdump
        ;;
#endif /* VENDOR_EDIT */
#ifdef VENDOR_EDIT
#Yanzhen.Feng@Swdp.Android.OppoDebug, 2017/03/20, Add for systrace on phone
    "cont_systrace")
        cont_systrace
        ;;
#endif /* VENDOR_EDIT */
#ifdef VENDOR_EDIT
    "systrace_trigger_start")
        systrace_trigger_start
        ;;
    "systrace_trigger_stop")
        systrace_trigger_stop
        ;;
    "systrace_snapshot")
        systrace_snapshot
        ;;
#fangpan@Swdp.shanghai, 2017/06/05, Add for systrace snapshot mode
#RunSheng.Pei@PSW.AD.OppoDebug.1463805, 2018/07/02, Add for systrace config, begin {
    "systrace_config")
        systrace_config
        ;;
#end }
    "dumpstate")
        Preprocess
        Dumpstate
        ;;
    "enabletcpdump")
        enabletcpdump
        ;;
    "dumpenvironment")
        DumpEnvironment
        ;;

#Haoran.Zhang@PSW.AD.BuildConfig.StandaloneUserdata.1143522, 2017/09/13, Add for set prop sys.build.display.full_id
     "userdatarefresh")
         userdatarefresh
         ;;
#end
    "initcache")
        initcache
        ;;
    "logcatcache")
        logcatcache
        ;;
    "radiocache")
        radiocache
        ;;
    "eventcache")
        eventcache
        ;;
    "kernelcache")
        kernelcache
        ;;
    "tcpdumpcache")
        tcpdumpcache
        ;;
    "fingerprintcache")
        fingerprintcache
        ;;
    "fplogcache")
        fplogcache
        ;;
    "log_observer")
        log_observer
        ;;
    "junklogcat")
        junklogcat
    ;;
    "junkdmesg")
        junkdmesg
    ;;
    "junkststart")
        junksystrace_start
    ;;
    "junkststop")
        junksystrace_stop
    ;;
#ifdef VENDOR_EDIT
#Zhihao.Li@MultiMedia.AudioServer.FrameWork, 2016/10/19, Add for clean pcm dump file.
    "cleanpcmdump")
        cleanpcmdump
    ;;
#endif /* VENDOR_EDIT */
#ifdef VENDOR_EDIT
#Jianping.Zheng@Swdp.Android.Stability.Crash, 2016/08/09, Add for logd memory leak workaround
    "check_logd_memleak")
        check_logd_memleak
        ;;
#endif /* VENDOR_EDIT *
    "gettpinfo")
        gettpinfo
    ;;
    "inittpdebug")
        inittpdebug
    ;;
    "settplevel")
        settplevel
    ;;
#ifdef VENDOR_EDIT
#Canjie.Zheng@Swdp.Android.OppoDebug.LogKit,2017/01/21,add for ftm
        "logcatftm")
        logcatftm
    ;;
        "klogdftm")
        klogdftm
    ;;
#Canjie.Zheng@Swdp.Android.OppoDebug.LogKit,2017/03/09, add for Sensor.logger
    "resetlogpath")
        resetlogpath
    ;;
#Canjie.Zheng@Swdp.Android.OppoDebug.LogKit,2017/03/23, add for power key dump
    "pwkdumpon")
        pwkdumpon
    ;;
    "pwkdumpoff")
        pwkdumpoff
    ;;
    "dumpoff")
        dumpoff
    ;;
    "dumpon")
        dumpon
    ;;
    "rmminidump")
        rmminidump
    ;;
    "test")
        test
    ;;
    "readdump")
        readdump
    ;;
    "packupminidump")
        packupminidump
    ;;
#ifdef VENDOR_EDIT
#Junhao.Liang@PSW.AD.OppoDebug.LogKit.1378575, 2018/06/05, Add for recording information of ocp
    "packupocp")
        packupocp
    ;;
#endif VENDOR_EDIT
    "junklogmonitor")
        junk_log_monitor
#endif VENDOR_EDIT
#ifdef VENDOR_EDIT
#Jianping.Zheng@Swdp.Android.Stability.Crash,2017/04/04,add for record performance
    ;;
        "perf_record")
        perf_record
#endif VENDOR_EDIT
    ;;
#Jianping.Zheng@PSW.Android.Stability.Crash,2017/05/08,add for systemserver futex_wait block check
        "checkfutexwait")
        check_systemserver_futexwait_block
#end, add for systemserver futex_wait block check
    ;;
#Fei.Mo@PSW.BSP.Sensor, 2017/09/01 ,Add for power monitor top info
        "thermal_top")
        thermalTop
#end, Add for power monitor top info
    ;;
#Canjie.Zheng@PSW.AD.OppoDebug.LogKit.1078692, 2017/11/20, Add for iotop
        "getiotop")
        getiotop
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OppoPowerMonitor get dmesg at O
        "kernelcacheforopm")
        kernelcacheforopm
    ;;
#Weitao.Chen@PSW.AD.Stability.Crash.1295294, 2018/03/01, Add for trying to recover from sysetm hang
        "recover_hang")
        recover_hang
    ;;
#Jianping.Zheng@PSW.AD.Stability.Crash.1354723, 2018/04/19, Add for collect fs info through DCS
        "collectfsinfo")
        collectfsinfo
    ;;
#add for customer log
        "logcusmain")
        logcusmain
    ;;
        "logcusevent")
        logcusevent
    ;;
        "logcusradio")
        logcusradio
    ;;
        "setdebugoff")
        setdebugoff
    ;;
        "logcustcp")
        logcustcp
    ;;
        "logcuskernel")
        logcuskernel
    ;;
        "logcuswifi")
        logcuswifi
    ;;
       *)
    tranfer
      ;;
esac
