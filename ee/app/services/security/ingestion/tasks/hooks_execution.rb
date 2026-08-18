# frozen_string_literal: true

module Security
  module Ingestion
    module Tasks
      class HooksExecution < AbstractTask
        def execute
          SecApplicationRecord.current_transaction.after_commit do
            new_vulnerabilities.each do |vulnerability|
              vulnerability.execute_hooks
              vulnerability.trigger_false_positive_detection
            end
          end
        end

        private

        def new_vulnerabilities
          new_finding_maps.map(&:vulnerability_id)
                          .then { |ids| Vulnerability.id_in(ids) }
        end

        def new_finding_maps
          finding_maps.select { |map| map.new_record && (map.tracked_context.nil? || map.tracked_context.is_default?) }
        end
      end
    end
  end
end
