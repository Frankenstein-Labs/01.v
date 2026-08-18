# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module ReindexProjectElasticZoektData
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :reindex_project_elastic_zoekt_data
          scope_to ->(relation) { relation.where(archived: true) }
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            sub_batch.each do |namespace_setting|
              # root_namespace_id is set to 0 just to validate GroupArchivedEvent schema.
              # This attribute is not used by the called workers
              data = { group_id: namespace_setting.namespace_id, root_namespace_id: 0 }
              ::Search::Elastic::GroupArchivedEventWorker.perform_async('Namespaces::Groups::GroupArchivedEvent', data)
              ::Search::Zoekt::GroupArchivedEventWorker.perform_async('Namespaces::Groups::GroupArchivedEvent', data)
            end
          end
        end
      end
    end
  end
end
