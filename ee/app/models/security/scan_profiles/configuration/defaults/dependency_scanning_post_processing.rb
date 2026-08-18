# frozen_string_literal: true

module Security
  module ScanProfiles
    class Configuration
      module Defaults
        module DependencyScanningPostProcessing
          VALUES = {
            auto_remediation: {
              cooldown: 7,
              severity_level: 'high',
              upgrade_policy: 'minor',
              open_merge_requests_limit: 10,
              runner_tags: []
            }
          }.freeze
        end
      end
    end
  end
end
