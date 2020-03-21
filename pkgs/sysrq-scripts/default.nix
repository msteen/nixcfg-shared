{ writeShBin, syncUmountAll, buildEnv }:

# https://github.com/Drive-Trust-Alliance/sedutil/wiki/Encrypting-your-disk
let
  prepareForTrigger = ''
    pids=$(ps -o pid,args | grep /bin/ | grep -Ev '(grep |/bin/ash /init|/bin/sysrq-)' | awk '{print $1}')

    echo 'sysrq> terminate all other processes'
    kill -s TERM $pids

    echo 'sysrq> give processes time to terminate'
    sleep 1

    echo 'sysrq> kill all remaining processes'
    kill -s KILL $pids > /dev/null 2>&1

    echo 'sysrq> sync and unmount all filesystems'
    ${syncUmountAll}

    echo 1 > /proc/sys/kernel/sysrq
  '';

  sysrq-poweroff = writeShBin "sysrq-poweroff" ''
    ${prepareForTrigger}
    echo 'sysrq> request system poweroff'
    echo o > /proc/sysrq-trigger # p[o]weroff
  '';

  sysrq-reboot = writeShBin "sysrq-reboot" ''
    ${prepareForTrigger}
    echo 'sysrq> request system reboot'
    echo b > /proc/sysrq-trigger # re[b]oot
  '';

in buildEnv {
  name = "sysrq-scripts";
  paths = [
    sysrq-poweroff
    sysrq-reboot
  ];
}
