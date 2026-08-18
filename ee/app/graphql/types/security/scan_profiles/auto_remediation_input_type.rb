# frozen_string_literal: true

module Types
  module Security
    module ScanProfiles
      class AutoRemediationInputType < BaseInputObject
        graphql_name 'SecurityScanProfileAutoRemediationInput'
        description 'Auto-remediation configuration for a dependency scanning post-processing scan profile.'

        argument :enabled, GraphQL::Types::Boolean,
          required: false,
          experiment: { milestone: '19.3' },
          description: 'Whether auto-remediation is enabled.'

        argument :cooldown, GraphQL::Types::Int,
          required: false,
          experiment: { milestone: '19.3' },
          description: 'Minimum number of days after a package is released before it can be used.'

        argument :severity_level, ::Types::VulnerabilitySeverityEnum,
          required: false,
          experiment: { milestone: '19.3' },
          description: 'Minimum vulnerability severity that triggers an automated upgrade. ' \
            'Findings below this threshold are skipped.'

        argument :upgrade_policy, ::Types::Security::ScanProfiles::UpgradePolicyEnum,
          required: false,
          experiment: { milestone: '19.3' },
          description: 'Highest version bump allowed when remediating.'

        argument :open_merge_requests_limit, GraphQL::Types::Int,
          required: false,
          experiment: { milestone: '19.3' },
          description: 'Maximum number of open auto-remediation merge requests at once.'
      end
    end
  end
end
