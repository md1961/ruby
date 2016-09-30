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

INDENTS = [' ' * 8, "\t"]

line_with_file = `git status`.split("\n").select { |line| line =~ /\A#{INDENTS.join('|')}/ }
puts line_with_file.map { |line| line.sub(/\A\s*(?:modified:|new file:)?\s*/, '') }.join("\n")
