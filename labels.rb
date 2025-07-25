#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'octokit_utils'
require_relative 'options'

def primary_remote
  ['upstream', 'origin'].map do |name|
    get_remote(name)
  end.compact.first
end

def get_remote(name)
  require 'rugged'
  remote = Rugged::Repository.new('.').remotes[name] rescue nil
  parts  = remote.url.match(/(\w+\/[\w-]+)(?:\.git)?$/) if remote
  parts[1] if parts
end

options = parse_options do |opts, result|
  opts.on('-f', '--fix-labels', 'Add the missing labels to repo') { result[:fix_labels] = true }
  opts.on('-d', '--delete-labels', 'Delete unwanted labels from repo') { result[:delete_labels] = true }

  opts.on('-n', '--namespace [NAME]', 'Name of a GitHub namespace to work on.') do |v|
    result[:namespace] = v
  end

  opts.on('-r', '--repo-regex [REGEX]', 'Repository regex') do |v|
    result[:repo_regex] = v
    raise "--repo-regex can only be used in conjunction with --namespace" unless result[:namespace]
  end

  opts.on('--repo [REPO]', 'Pass a repository name, defaults to the current upstream.') do |v|
    result[:remote] = v || primary_remote
    raise 'Could not guess primary remote. Try using --remote instead.' unless result[:remote]
  end

  opts.on('--remote REMOTE', 'Name of a remote to work on.') do |v|
    result[:remote] = get_remote(v)
    raise "No url set for remote #{v}" unless result[:remote]
  end
end

util = OctokitUtils.new(options[:oauth])

if options[:remote]
  parsed = { options[:remote] => { 'github' => options[:remote] } }
elsif options[:namespace]
  options[:repo_regex] = '.*' if options[:repo_regex].nil?
  parsed = util.list_repos(options[:namespace], options)
else
  parsed = load_url(options)
end

wanted_labels = [
  { name: 'backwards-incompatible', color: 'eb6420', description: 'This change will lead to a major version bump for the next release' },
  { name: 'bug', color: '0e8a16', description: "Something isn't working" },
  { name: 'documentation', color: '006b75', description: 'Improvements or additions to documentation' },
  { name: 'duplicate', color: 'cccccc', description: 'This issue or pull request already exists' },
  { name: 'enhancement', color: '0052cc', description: 'New feature or request' },
  { name: 'good first issue', color: '7057ff', description: 'Good for newcomers' },
  { name: 'help wanted', color: '159818', description: 'Extra attention is needed' },
  { name: 'invalid', color: 'e4e669', description: "This doesn't seem right" },
  { name: 'modulesync', color: 'fbca04', description: 'PR related to modulesync' },
  { name: 'question', color: 'cc317c', description: 'Further information is requested' },
  { name: 'security', color: 'b60205', description: 'Related to a security issue' },
  { name: 'skip-changelog', color: '343e4c', description: 'Excluded from CHANGELOG' },
  { name: 'wontfix', color: 'ffffff', description: 'This will not be worked on' },
]

label_names = []
wanted_labels.each do |wanted_label|
  label_names.push(wanted_label[:name])
end
puts "Checking for the following labels: #{label_names}"

parsed.each do |_k, v|
  if options[:namespace]
    repo_name = "#{options[:namespace]}/#{_k}"
  else
    repo_name = (v['github']).to_s
  end
  next if util.repo_is_fork?(repo_name)
  next if util.repo_is_archived?(repo_name)
  missing_labels = util.fetch_repo_missing_labels(repo_name, wanted_labels)
  incorrect_labels = util.fetch_repo_incorrect_labels(repo_name, wanted_labels)
  extra_labels = util.fetch_repo_extra_labels(repo_name, wanted_labels)
  puts "Delete: #{repo_name}, #{extra_labels}"
  puts "Create: #{repo_name}, #{missing_labels}"
  puts "Fix: #{repo_name}, #{incorrect_labels}"

  if options[:delete_labels]
    util.delete_repo_labels(repo_name, extra_labels) unless extra_labels.empty?
  end
  next unless options[:fix_labels]

  util.update_repo_labels(repo_name, incorrect_labels) unless incorrect_labels.empty?
  util.add_repo_labels(repo_name, missing_labels) unless missing_labels.empty?
end
