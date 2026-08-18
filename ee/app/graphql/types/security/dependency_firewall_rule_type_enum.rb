# frozen_string_literal: true

module Types
  module Security
    class DependencyFirewallRuleTypeEnum < BaseEnum
      graphql_name 'DependencyFirewallRuleType'
      description 'Type of a dependency firewall policy rule.'

      value 'LICENSE', value: 'license', description: 'Rule matching on package licenses.'
      value 'VULNERABILITY', value: 'vulnerability', description: 'Rule matching on package vulnerabilities.'
      value 'MALICIOUS', value: 'malicious', description: 'Rule matching on packages flagged as malicious.'
    end
  end
end
