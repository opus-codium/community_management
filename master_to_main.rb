#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'octokit_utils'
require_relative 'options'

options = parse_options do |opts, result|
  opts.on('-n', '--namespace=NAME', 'Name of a GitHub namespace to work on.') do |v|
    result[:namespace] = v
  end
end

util = OctokitUtils.new(options[:oauth])

repos = util.list_repos(options[:namespace], repo_regex: '.*')

repos.each do |repo|
  repo_name = "#{options[:namespace]}/#{repo}"

  next if util.repo_is_fork?(repo_name)
  next if util.repo_is_archived?(repo_name)

  branch = util.client.branch(repo_name, 'master')
  next if branch['name'] == 'main'

  util.client.rename_branch(repo_name, 'master', 'main')

  puts "#{repo_name}: master -> main"
rescue Octokit::NotFound
  # Ignore
end
