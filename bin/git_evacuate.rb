#! /bin/env ruby

EVACUATION_BRANCH = 'tmp'.freeze

git_status = `git status 2> /dev/null`

unless $?.success?
  STDERR.puts "Not a git repository"
  exit
end

RE_CURRENT_BRANCH_IN_STATUS_COMMAND = /\AOn branch (\S+)\s*$/

unless git_status =~ RE_CURRENT_BRANCH_IN_STATUS_COMMAND
  STDERR.puts "Cannot get current branch name from first line of git status command output"
  exit
end

current_branch = Regexp.last_match(1)

if current_branch == EVACUATION_BRANCH
  STDERR.puts "Cannot proceed because current branch name is equal to evacuation branch '#{EVACUATION_BRANCH}'"
  exit
end

RE_CLEAN_REPOSITORY = /^nothing to commit, working directory clean/

if git_status =~ RE_CLEAN_REPOSITORY
  STDERR.puts "Nothing to do, because local repository is clean"
  exit
end

RE_REMOTE_REPO_URL = /^\s*Push\s+URL:\s+(\S+)\s*$/

remote_repos = `git remote show`.split
hash_remote_repo_to_evacuate_to = {}
remote_repos.each do |remote_repo|
  if `git remote show #{remote_repo}` =~ RE_REMOTE_REPO_URL
    url = Regexp.last_match(1)
    if url =~ /github\.com/
      hash_remote_repo_to_evacuate_to[remote_repo] = url
      break
    end
  end
end

if hash_remote_repo_to_evacuate_to.empty?
  STDERR.puts "No remote repository found to evacuate to"
  exit
end

remote_repo = hash_remote_repo_to_evacuate_to.keys.first
remote_url  = hash_remote_repo_to_evacuate_to[remote_repo]

puts "Use remote repository '#{remote_repo}' (#{remote_url}) to evacuate to"
puts "Branch '\e[33m#{EVACUATION_BRANCH}'\e[0m of both local and remote '#{remote_repo}' will be removed"
print "OK to proceed? (y/N) "
c = STDIN.getc
unless c == 'y'
  STDERR.puts "Quit execution on user's request"
  exit
end


COMMIT_MESSAGE = "(tmp) automated evacuation from branch #{current_branch} by git_evacuate.rb".freeze

system("git br -D #{EVACUATION_BRANCH} 2> /dev/null")
system("git push #{remote_repo} :#{EVACUATION_BRANCH} 2> /dev/null")
system("git add .")
system("git commit -m '#{COMMIT_MESSAGE}'")
system("git checkout -b #{EVACUATION_BRANCH}")
system("git push #{remote_repo} #{EVACUATION_BRANCH}:#{EVACUATION_BRANCH}")
system("git checkout #{current_branch}")
system("git reset --soft HEAD^")
system("git reset HEAD")
