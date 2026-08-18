# frozen_string_literal: true

module VulnerableHelpers
  class BadVulnerableError < StandardError
    def message
      'The given vulnerable must be either `Project`, `Namespace`, or `InstanceSecurityDashboard`'
    end
  end
end
