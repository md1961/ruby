#! /bin/bash

# Please prepare file 'config/unicorn_port' and 'config/unicorn_env'
# which has only port No. and Rails environment, respectively, in it

RAILS_ROOT_DIR=$(dirname $(dirname $(readlink $0)))

START_SCRIPT=$RAILS_ROOT_DIR/script/unicorn.sh

PID_FILE=$RAILS_ROOT_DIR/tmp/pids/unicorn.pid
PID=$(head -1 $PID_FILE 2> /dev/null)
PS_RUNNING=$(ps h -p $PID 2> /dev/null)

ENVIRONMENT_FILE=$RAILS_ROOT_DIR/config/unicorn_env
ENVIRONMENT=$(head -1 $ENVIRONMENT_FILE) || exit

PORT_FILE=$RAILS_ROOT_DIR/config/unicorn_port
PORT=$(head -1 $PORT_FILE) || exit

PS_GREP_PATTERN="$PID.*unicorn_rails"

USER=%username%

prog="%appname%"

msg_running="$prog is already running (PID=$PID, environment=$ENVIRONMENT, port=$PORT)"
msg_not_running="$prog is out of service (environment=$ENVIRONMENT, port=$PORT)"


start() {
  if [ "$PID" != "" -a "$PS_RUNNING" != "" ]
  then
    echo $"$msg_running"
  else
    do_start
  fi
  return $?
}

do_start() {
  echo $"Starting $prog ..."
  su - -c $START_SCRIPT $USER
}

stop() {
  if [ "$PID" = "" -o "$PS_RUNNING" = "" ]
  then
    echo $"$msg_not_running"
  else
    echo $"Stopping $prog ..."
    kill $PID
  fi
  return $?
}

restart(){
  stop && do_start
}

status() {
  if [ "$PID" = "" -o "$PS_RUNNING" = "" ]
  then
    echo $"$msg_not_running"
  else
    echo $"$msg_running"
    echo
    ps_index
    ps_server
  fi
}

ps_index() {
  ps -ef | grep PID | grep -v 'grep'
}

ps_server() {
  ps -ef | grep $PS_GREP_PATTERN | grep -v 'grep'
}


case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  status)
    status
    ;;
  *)
    echo $"Usage: $0 {start|stop|restart|status}"
    RETVAL=1
esac

exit $RETVAL

