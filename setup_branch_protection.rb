#!/usr/bin/env ruby
# frozen_string_literal: true

# https://docs.github.com/en/rest/reference/repos#update-branch-protection
# https://octokit.github.io/octokit.rb/Octokit/Client/Repositories.html#protect_branch-instance_method

require_relative 'octokit_utils'
require_relative 'options'

options = parse_options
util = OctokitUtils.new(options[:oauth])
client = util.client

# puts client.branch_protection('puppetlabs/puppetlabs-acl', 'main', accept: 'application/vnd.github.luke-cage-preview+json').inspect

# protect_rule = {
#   url: 'https://api.github.com/repos/puppetlabs/puppetlabs-acl/branches/main/protection',
#   required_status_checks:
#    {
#      url: 'https://api.github.com/repos/puppetlabs/puppetlabs-acl/branches/main/protection/required_status_checks',
#      strict: false,
#      contexts: ['Spec Tests (Puppet: ~> 6.0, Ruby Ver: 2.5)', 'license/cla'],
#      contexts_url: 'https://api.github.com/repos/puppetlabs/puppetlabs-acl/branches/main/protection/required_status_checks/contexts'
#    },
#   required_pull_request_reviews: {
#     url: 'https://api.github.com/repos/puppetlabs/puppetlabs-acl/branches/main/protection/required_pull_request_reviews',
#     dismiss_stale_reviews: true,
#     require_code_owner_reviews: false,
#     required_approving_review_count: 1
#   },
#   enforce_admins: {
#     url: 'https://api.github.com/repos/puppetlabs/puppetlabs-acl/branches/main/protection/enforce_admins',
#     enabled: false
#   },
#   required_linear_history: { enabled: false },
#   allow_force_pushes: { enabled: false },
#   allow_deletions: { enabled: false },
#   required_conversation_resolution: { enabled: false }
# }

parsed = load_url(options)
parsed.each do |_k, v|
  repo_name = (v['github']).to_s
  begin
    client.unprotect_branch(repo_name, 'main', accept: 'application/vnd.github.luke-cage-preview+json')
  rescue StandardError => e
    puts e
  end

  begin
    client.protect_branch(repo_name, 'main', {
                            accept: 'application/vnd.github.luke-cage-preview+json',
                            required_status_checks: {
                              strict: true,
                            },
                            enforce_admins: false,
                            required_pull_request_reviews: {
                              dismiss_stale_reviews: true,
                              require_code_owner_reviews: true,
                              required_approving_review_count: 1
                            },
                            required_signatures: true,
                          })
    puts "updated #{repo_name}"
  rescue StandardError => e
    puts "failed to update #{repo_name}"
    puts e
  end
end
