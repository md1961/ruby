#! /bin/env ruby

begin
  require 'highline'
rescue LoadError => e
  $stdout.puts "Gem 'highline' not found\n" \
             + "Please install with the following command\n" \
             + "  $ sudo gem install highline"
end         


# Constants

ENVIRONMENTS = %w(development production).freeze

DIR_CONFIG = 'config'
DIR_SCRIPT = 'script'
TARGET_FILES = [
                 ['unicorn-config.rb', DIR_CONFIG],
                 ['unicorn_env'      , DIR_CONFIG],
                 ['unicorn_port'     , DIR_CONFIG],
                 ['unicorn.sh'       , DIR_SCRIPT],
               ]
TARGET_DIRS  = TARGET_FILES.map { |file_and_dir| file_and_dir[1] }.freeze

COLOR_FOR_INPUT = :yellow


# Check directories to write and existence of target files

dirs_not_exist = TARGET_DIRS.select { |dir| ! File.directory?(dir) }
unless dirs_not_exist.empty?
  $stderr.puts "Cannot find directory '#{dirs_not_exist.join("' and '")}' in current directory"
  exit
end


# Main routine

hl = HighLine.new

begin
  appname     = hl.ask("Application Name: ") { |q| q.validate = /^[a-z]\w{3,}$/ }
  adds_d      = hl.agree("Add 'd' at end of '#{appname}' for script name?(Y/n)") { |q| q.default = 'yes' }
  environment = hl.choose(*ENVIRONMENTS) { |q| q.default = ENVIRONMENTS.first }

  appname_disp = appname.upcase
  scriptname = appname + (adds_d ? 'd' : '') + '.sh'

  puts "application name    = " + hl.color(appname     , COLOR_FOR_INPUT)
  puts "its displaying name = " + hl.color(appname_disp, COLOR_FOR_INPUT)
  puts "script name         = " + hl.color(scriptname  , COLOR_FOR_INPUT)
  puts "environment         = " + hl.color(environment , COLOR_FOR_INPUT)
end until hl.agree("OK to proceed(y/n)")

target_files = (TARGET_FILES + [[scriptname, DIR_SCRIPT]]).map { |file_and_dir| file_and_dir.reverse.join(File::SEPARATOR) }

files_exist = target_files.select { |file| File.exist?(file) }
unless files_exist.empty?
  is_multiple = files_exist.size >= 2
  msg = "The following file#{is_multiple ? 's' : ''} exist#{is_multiple ? '' : 's'}:\n" \
      + files_exist.map { |file| '  ' + file }.join("\n")
  ok_to_overwrite = hl.agree(msg + "\nOK to overwrite?(y/N)") { |q| q.default = 'no' }
  exit unless ok_to_overwrite
end

