#! /bin/env ruby

require 'tempfile'


FILES_FOR_RAILS_DIR = [
  %w(app models),
  %w(app controllers),
  %w(app views),
  %w(config application.rb),
  %w(db migrate),
].freeze

FILES_FOR_RAILS_DIR.map { |array| File.join(*array) }.each do |file|
  unless File.exist?(file)
    STDERR.puts "Quit execution as you're not in a Rails root directory."
    exit
  end
end


FILES_FOR_GIT_REPOSITORY = [
  %w(.git config),
].freeze

FILES_FOR_GIT_REPOSITORY.map { |array| File.join(*array) }.each do |file|
  unless File.exist?(file)
    STDERR.puts "Quit execution as you're not in a git repository."
    exit
  end
end


DIR_SOURCE = File.expand_path(File.join(File.dirname(__FILE__), 'files_for_generate_error_messages_for')).freeze

DIR_HELPER     = File.join(%w(app helpers)).freeze
DIR_TEMPLATE   = File.join(%w(app views application)).freeze
DIR_STYLESHEET = File.join(%w(app assets stylesheets)).freeze

TARGET_HELPER        = 'application_helper.rb'
SOURCE_HELPER_APPEND = 'application_helper_append.rb'

SOURCE_TEMPLATE   = '_error_messages_for.html.erb'
SOURCE_STYLESHEET = 'errors.css'


# app/helpers/application_helper.rb

RE_METHOD_IN_HELPER = /\A\s*def\s+error_messages\for/
RE_END_OF_HELPER_BODY = /\Aend\s*\z/

f_tmp = Tempfile.open(TARGET_HELPER)
is_method_written = false
method_exists = false
File.open(File.join(DIR_HELPER, TARGET_HELPER), 'r') do |f|
  f.each do |line|
    method_exists = true if line =~ RE_METHOD_IN_HELPER
    if line =~ RE_END_OF_HELPER_BODY && ! is_method_written
      File.open(File.join(DIR_SOURCE, SOURCE_HELPER_APPEND)) do |f2|
        f2.each do |line2|
          f_tmp.write line2
        end
      end
      is_method_written = true
    end
    f_tmp.write line
  end
end
f_tmp.close

FileUtils.cp(f_tmp.path, File.join(DIR_HELPER, TARGET_HELPER))


# app/views/application/_error_messages_for.html.erb

FileUtils.mkdir(DIR_TEMPLATE) unless File.exist?(DIR_TEMPLATE)
FileUtils.cp(File.join(DIR_SOURCE, SOURCE_TEMPLATE), DIR_TEMPLATE)


# app/assets/stylesheets/errors.css

FileUtils.cp(File.join(DIR_SOURCE, SOURCE_STYLESHEET), DIR_STYLESHEET)

