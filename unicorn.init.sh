#!/bin/bash

usage(){
	script=`basename $0`
	echo $1
	echo "usage: $script {start|stop|reload|restart|dup|ok|cancel|status}"
	exit 1
}

up_unicorn(){
	if [ -z "$RAILS_DEVEL_NAME" ]; then
		echo "RAILS_DEVEL_NAME is not detected"
	else
		echo "unicorn starting..."
		RAILS_DEVEL_NAME=$RAILS_DEVEL_NAME bundle exec unicorn_rails -c config/unicorn.rb -E $RACK_ENV -D
	fi
}

send_signal(){
	send_signal_to_pid $pid $1 $2
}
send_signal_to_old(){
	send_signal_to_pid $oldpid $1 $2
}
send_signal_to_pid(){
	echo "unicorn $3..."
	kill $2 `cat $1`
}

pid_exist(){
	test -f $pid
	return $?
}
pid_not_exist(){
	test ! -f $pid
	return $?
}
oldpid_exist(){
	test -f $oldpid
	return $?
}
oldpid_not_exist(){
	test ! -f $oldpid
	return $?
}

unicorn_status(){
	ps --pid `cat $1` -o pid=,stat=
}
unicorn_status_v(){
	ps --pid `cat $1` -o pid,stat,args
}
unicorn_status_vv(){
	ps --ppid `cat $1` -o ppid,pid,stat,args
}
unicorn_status_vvv(){
	ps --pid `cat $1` --ppid `cat $1` -o ppid,pid,stat,args
}

if [ $# -lt 1 ]; then
	usage "args too short"
fi

if [ -z "$RACK_ENV" ]; then
	if [ -z "$RAILS_ENV" ]; then
		RACK_ENV=development
	else
		RACK_ENV=$RAILS_ENV
	fi
fi

pid=tmp/pids/unicorn.pid
oldpid=$pid.oldbin

case $1 in
	start)
		pid_not_exist && up_unicorn
		;;
	stop)
		pid_exist && oldpid_not_exist && send_signal -QUIT $1
		;;
	reload)
		pid_exist && oldpid_not_exist && send_signal -HUP $1
		;;
	restart)
		pid_exist && oldpid_not_exist && send_signal -QUIT $1
		while pid_exist; do
			sleep 1
		done
		up_unicorn
		;;
	dup)
		pid_exist && oldpid_not_exist && send_signal -USR2 $1
		;;
	ok)
		pid_exist && oldpid_exist && send_signal_to_old -QUIT $1
		;;
	cancel)
		pid_exist && oldpid_exist && send_signal_to_old -HUP "reload oldbin"
		oldp=`cat $oldpid`
		while [ -z "`ps --ppid "$oldp" -o pid=`" ]; do
			sleep 1
		done
		pid_exist && oldpid_exist && send_signal -QUIT "cancel"
		;;
	status)
		verbose=
		while [ $# -gt 1 ]; do
			case $2 in
				-v|-vv|-vvv)
					verbose=_${2#-}
					;;
			esac
			shift
		done
		if pid_exist; then
			echo
			unicorn_status$verbose $pid
			echo
		else
			echo
			echo "UNICORN NOT EXIST"
			echo
		fi
		if oldpid_exist; then
			echo "*** OLDBIN ***"
			unicorn_status$verbose $oldpid
			echo
		fi
		;;
	*)
		usage "invalid command"
		;;
esac
exit 0
