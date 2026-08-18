# frozen_string_literal: true

module Search
  module Zoekt
    class ProjectTransferWorker
      include ApplicationWorker
      include Search::Worker
      prepend ::Geo::SkipSecondary

      pause_control :zoekt

      idempotent!
      data_consistency :delayed
      urgency :throttled

      def perform(project_id, old_namespace_id)
        return unless ::Search::Zoekt.licensed_and_indexing_enabled?

        project = Project.find_by_id(project_id)
        old_namespace = Namespace.find_by_id(old_namespace_id)

        return false unless project && old_namespace

        if old_namespace.use_zoekt?
          Search::Zoekt.delete_async(project_id, root_namespace_id: old_namespace.root_ancestor.id)
        end

        return unless project.use_zoekt?

        ::Search::Zoekt.index_async(project_id)
      end
    end
  end
end
