#! /bin/env ruby

begin
  require 'highline'
rescue LoadError => e
  $stdout.puts "Gem 'highline' not found\n" \
             + "Please install with the following command\n" \
             + "  $ sudo gem install highline"
end         

require 'fileutils'


# Constants

ENVIRONMENTS = %w(development production).freeze

DIR_SOURCE = File.expand_path(File.join(File.dirname(__FILE__), 'files_for_generate_unicorn_script')).freeze

DIR_CONFIG = 'config'
DIR_SCRIPT = 'script'

FILE_UNICORN_CONFIG      = 'unicorn-config.rb'
FILE_UNICORN_SCRIPT      = 'unicorn.sh'
FILE_SERVER_START_SCRIPT = 'start_server.sh'

TARGET_FILES_TO_COPY  = [
                          [DIR_CONFIG, FILE_UNICORN_CONFIG],
                          [DIR_SCRIPT, FILE_UNICORN_SCRIPT],
                        ].freeze
TARGET_FILE_ENV  = 'unicorn_env'
TARGET_FILE_PORT = 'unicorn_port'
TARGET_FILES_TO_WRITE = [
                          [DIR_CONFIG, TARGET_FILE_ENV ],
                          [DIR_CONFIG, TARGET_FILE_PORT],
                        ].freeze
TARGET_FILES = TARGET_FILES_TO_COPY + TARGET_FILES_TO_WRITE

TARGET_DIRS  = TARGET_FILES.map { |file_and_dir| file_and_dir.first }.uniq.freeze

RE_APPNAME_INNPUT = /^[a-z]\w{2,}$/

COLOR_FOR_INPUT = :yellow


# Check directories to write and existence of target files

dirs_not_exist = TARGET_DIRS.select { |dir| ! File.directory?(dir) }
unless dirs_not_exist.empty?
  $stderr.puts "Cannot find directory '#{dirs_not_exist.join("' and '")}' in current directory"
  exit
end


# Ask input and verify

hl = HighLine.new

begin
  appname     = hl.ask("Application Name: ") { |q| q.validate = RE_APPNAME_INNPUT }
  adds_d      = hl.agree("Add 'd' at end of '#{appname}' for script name?(Y/n)") { |q| q.default = 'yes' }
  environment = hl.choose(*ENVIRONMENTS) { |q| q.default = ENVIRONMENTS.first }
  port        = hl.ask("Port No.: ", Integer) { |q| q.above = 99; q.below = 100000 }

  appname_disp = appname.upcase
  scriptname = appname + (adds_d ? 'd' : '') + '.sh'

  puts "application name    = " + hl.color(appname     , COLOR_FOR_INPUT)
  puts "its displaying name = " + hl.color(appname_disp, COLOR_FOR_INPUT)
  puts "script name         = " + hl.color(scriptname  , COLOR_FOR_INPUT)
  puts "environment         = " + hl.color(environment , COLOR_FOR_INPUT)
  puts "port No.            = " + hl.color(port        , COLOR_FOR_INPUT)
end until hl.agree("OK to proceed(y/n)")

target_files = (TARGET_FILES + [[DIR_SCRIPT, scriptname]]).map { |dir_and_file| File.join(dir_and_file) }

files_exist = target_files.select { |file| File.exist?(file) }
unless files_exist.empty?
  is_multiple = files_exist.size >= 2
  msg = "The following file#{is_multiple ? 's' : ''} exist#{is_multiple ? '' : 's'}:\n" \
      + files_exist.map { |file| '  ' + file }.join("\n")
  ok_to_overwrite = hl.agree(msg + "\nOK to overwrite?(y/N)") { |q| q.default = 'no' }
  unless ok_to_overwrite
    $stderr.puts "Exit to prevent from overwriting the existing file(s)"
    exit
  end
end


# Write the files

# unicorn_env
File.open(File.join(DIR_CONFIG, TARGET_FILE_ENV) , 'w') do |f|
  f.write environment
end
# unicorn_port
File.open(File.join(DIR_CONFIG, TARGET_FILE_PORT), 'w') do |f|
  f.write port
end
# unicorn-config.rb
FileUtils.cp(File.join(DIR_SOURCE, FILE_UNICORN_CONFIG), File.join(DIR_CONFIG, FILE_UNICORN_CONFIG))
# unicorn.sh
FileUtils.cp(File.join(DIR_SOURCE, FILE_UNICORN_SCRIPT), File.join(DIR_SCRIPT, FILE_UNICORN_SCRIPT))

RE_USERNAME_IN_START_SCRIPT = /%username%/
RE_APPNAME_IN_START_SCRIPT  = /%appname%/

# server-start script
username = `whoami`.chomp
File.open(File.join(DIR_SOURCE, FILE_SERVER_START_SCRIPT), 'r') do |f_in|
  File.open(File.join(DIR_SCRIPT, scriptname), 'w') do |f_out|
    f_in.each do |line|
      line.gsub!(RE_USERNAME_IN_START_SCRIPT, username    )
      line.gsub!(RE_APPNAME_IN_START_SCRIPT , appname_disp)
      f_out.write line
    end
  end
end


#[EOF]

