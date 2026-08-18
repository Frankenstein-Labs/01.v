# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillRolledUpWeightForWorkItems
        extend ActiveSupport::Concern

        def perform
          each_sub_batch do |sub_batch|
            # Find "leaf nodes" - work items that are not parents of other work items.
            # We exclude work items that have children since their weights
            # will be rolled up from their children. We also exclude Standalone work items as
            # they do not have parents so we do not need to backfill their rolled up weights.
            leaf_nodes = sub_batch.where(
              'NOT EXISTS (SELECT 1 FROM work_item_parent_links WHERE work_item_parent_id = issues.id)'
            ).where('EXISTS (SELECT 1 FROM work_item_parent_links WHERE work_item_id = issues.id)').pluck(:id)
            ::WorkItems::Weights::UpdateWeightsWorker.perform_async(leaf_nodes) if leaf_nodes.any?
          end
        end
      end
    end
  end
end
