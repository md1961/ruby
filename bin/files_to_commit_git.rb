#! /bin/env ruby

=begin
On branch problem03
Your branch is up-to-date with 'origin/problem03'.
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

        modified:   README.md

Untracked files:
  (use "git add <file>..." to include in what will be committed)

        diff.all.txt

no changes added to commit (use "git add" and/or "git commit -a")
[kumagai@namaka asagao-extended]$ git add .
[kumagai@namaka asagao-extended]$ git st
On branch problem03
Your branch is up-to-date with 'origin/problem03'.
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

        modified:   README.md
        new file:   diff.all.txt
=end

opens_with_vim = false
if ARGV[0] == '-o' || ARGV[0] == '-p'
  opens_with_vim = true
elsif ARGV[0]
  STDERR.puts "Usage: #{File.basename($0)} [-[op]] (pass options to vim)"
  exit
end

INDENTS = [' ' * 8, "\t"]

line_with_file = `git status`.split("\n").select { |line| line =~ /\A#{INDENTS.join('|')}/ }
filenames = line_with_file.map { |line| line.sub(/\A\s*(?:modified:|new file:)?\s*/, '') }

if opens_with_vim
  system("vim #{ARGV[0]} #{filenames.join(' ')}")
else
  puts filenames.join("\n")
end
