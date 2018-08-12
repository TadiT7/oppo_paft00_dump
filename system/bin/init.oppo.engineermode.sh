#!/system/bin/sh

config="$1"

function doAddRadioFile(){
    if [ -d /opporeserve/radio ]; then
        if [ ! -f /opporeserve/radio/exp_operator_switch.config ]; then
            touch /opporeserve/radio/exp_operator_switch.config
        fi
        if [ ! -f /opporeserve/radio/exp_region_netlock.config ]; then
            touch /opporeserve/radio/exp_region_netlock.config
        fi
        if [ ! -f /opporeserve/radio/exp_operator_simlock_switch.config ]; then
            touch /opporeserve/radio/exp_operator_simlock_switch.config
        fi
        if [ ! -f /opporeserve/radio/exp_operator_simlock_times.config ]; then
            touch /opporeserve/radio/exp_operator_simlock_times.config
        fi
        if [ ! -f /opporeserve/radio/exp_sim_operator_switch.config ]; then
            touch /opporeserve/radio/exp_sim_operator_switch.config
        fi
        if [ ! -f /opporeserve/radio/exp_open_market_singlecard.config ]; then
            touch /opporeserve/radio/exp_open_market_singlecard.config
        fi

        if [ ! -f /opporeserve/radio/exp_operator_devicelock_status.config ]; then
            touch /opporeserve/radio/exp_operator_devicelock_status.config
        fi
        if [ ! -f /opporeserve/radio/exp_operator_devicelock_imsi.config ]; then
            touch /opporeserve/radio/exp_operator_devicelock_imsi.config
        fi
        if [ ! -f /opporeserve/radio/exp_operator_devicelock_iccid.config ]; then
            touch /opporeserve/radio/exp_operator_devicelock_iccid.config
        fi
        if [ ! -f /opporeserve/radio/exp_operator_devicelock_days.config ]; then
            touch /opporeserve/radio/exp_operator_devicelock_days.config
        fi
        if [ ! -f /opporeserve/radio/exp_operator_devicelock_first_bind_time.config ]; then
            touch /opporeserve/radio/exp_operator_devicelock_first_bind_time.config
        fi
        if [ ! -f /opporeserve/radio/exp_operator_devicelock_last_bind_time.config ]; then
            touch /opporeserve/radio/exp_operator_devicelock_last_bind_time.config
        fi
        if [ ! -f /opporeserve/radio/exp_operator_devicelock_unlock_time.config ]; then
            touch /opporeserve/radio/exp_operator_devicelock_unlock_time.config
        fi

        chown radio system /opporeserve/radio/exp_operator_switch.config
        chown radio system /opporeserve/radio/exp_region_netlock.config
        chown radio system /opporeserve/radio/exp_operator_simlock_switch.config
        chown radio system /opporeserve/radio/exp_operator_simlock_times.config
        chown radio system /opporeserve/radio/exp_sim_operator_switch.config
        chown radio system /opporeserve/radio/exp_open_market_singlecard.config

        chown radio system /opporeserve/radio/exp_operator_devicelock_status.config
        chown radio system /opporeserve/radio/exp_operator_devicelock_imsi.config
        chown radio system /opporeserve/radio/exp_operator_devicelock_iccid.config
        chown radio system /opporeserve/exp_operator_devicelock_days.config
        chown radio system /opporeserve/radio/exp_operator_devicelock_first_bind_time.config
        chown radio system /opporeserve/radio/exp_operator_devicelock_last_bind_time.config
        chown radio system /opporeserve/radio/exp_operator_devicelock_unlock_time.config

        chmod 0660 /opporeserve/radio/exp_operator_switch.config
        chmod 0660 /opporeserve/radio/exp_region_netlock.config
        chmod 0660 /opporeserve/radio/exp_operator_simlock_switch.config
        chmod 0660 /opporeserve/radio/exp_operator_simlock_times.config
        chmod 0660 /opporeserve/radio/exp_sim_operator_switch.config
        chmod 0660 /opporeserve/radio/exp_open_market_singlecard.config

        chmod 0660 /opporeserve/radio/exp_operator_devicelock_status.config
        chmod 0660 /opporeserve/radio/exp_operator_devicelock_imsi.config
        chmod 0660 /opporeserve/radio/exp_operator_devicelock_iccid.config
        chmod 0660 /opporeserve/exp_operator_devicelock_days.config
        chmod 0660 /opporeserve/radio/exp_operator_devicelock_first_bind_time.config
        chmod 0660 /opporeserve/radio/exp_operator_devicelock_last_bind_time.config
        chmod 0660 /opporeserve/radio/exp_operator_devicelock_unlock_time.config
    fi
}

function doSwitchEng {
    if [ -f /persist/engineermode/adb_switch ]; then
        setprop persist.sys.allcommode true
        setprop persist.sys.oppo.usbactive true
        setprop persist.sys.adb.engineermode 0
        setprop sys.usb.config diag,adb
        setprop persist.sys.usb.config diag,adb
        adb_switch=`cat /persist/engineermode/adb_switch`
        if [ "$adb_switch"x = "ENABLE_BY_MASTERCLEAR"x ]; then
            setprop persist.sys.oppo.fromadbclear true
            rm /persist/engineermode/adb_switch
        fi
    fi
}

function doStartDiagSocketLog {
    ip_address=`getprop sys.engineer.diag.socket.ip`
    port=`getprop sys.engineer.diag.socket.port`
    if [ -z "${ip_address}" ]; then
        ip_address=181.157.1.200
    fi
    if [ -z "${port}" ]; then
        port=2500
    fi
    diag_socket_log -a ${ip_address} -p ${port} -r 10000
}

function doStopDiagSocketLog {
    diag_socket_log -k
}

case "$config" in
    "addRadioFile")
    doAddRadioFile
    ;;
    "switchEng")
    doSwitchEng
    ;;
    "startDiagSocketLog")
    doStartDiagSocketLog
    ;;
    "stopDiagSocketLog")
    doStopDiagSocketLog
    ;;
esac
