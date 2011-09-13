#! /bin/sh

if [ `uname` = "Darwin" ]
then
  MACOSX=Darwin
fi

if [ "$MACOSX" = "" ]
then
  READLINK_OPTIONS=-f
fi

RAILS_ROOT_DIR=$(dirname $(dirname $(readlink $READLINK_OPTIONS $0 || echo $0)))

CONFIG_FILE=$RAILS_ROOT_DIR/config/unicorn-config.rb

ENVIRONMENT_FILE=$RAILS_ROOT_DIR/config/unicorn_env
ENVIRONMENT=$(head -1 $ENVIRONMENT_FILE) || exit

/usr/local/bin/unicorn_rails --config-file $CONFIG_FILE --env $ENVIRONMENT --daemonize

