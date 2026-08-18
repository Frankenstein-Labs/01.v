# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    class TrackMergedMrWorker
      include TracksAutoRemediationMrEvent

      idempotent!

      EVENT_NAME = 'merge_dependency_management_auto_remediation_mr'
    end
  end
end
