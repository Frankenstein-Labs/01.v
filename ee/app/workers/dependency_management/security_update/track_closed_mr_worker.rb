# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    class TrackClosedMrWorker
      include TracksAutoRemediationMrEvent

      idempotent!

      EVENT_NAME = 'close_dependency_management_auto_remediation_mr'
    end
  end
end
