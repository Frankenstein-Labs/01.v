# frozen_string_literal: true

module EE
  module Organizations
    module Transfer
      module GroupsService
        extend ::Gitlab::Utils::Override
        include ::Gitlab::Utils::StrongMemoize

        override :perform_transfer
        def perform_transfer
          super

          transfer_subscriptions
          transfer_ai_catalog_items
          transfer_custom_dashboards
        end

        private

        def transfer_subscriptions
          update_organization_id_for(::GitlabSubscriptions::AddOnPurchase) { |relation| relation.by_namespace(group) }
          update_organization_id_for(::GitlabSubscriptions::SeatAssignment) { |relation| relation.by_namespace(group) }

          update_organization_id_for(::GitlabSubscriptions::UserAddOnAssignment) do |relation|
            relation.for_add_on_purchases(add_on_purchases_relation)
          end

          update_organization_id_for(::GitlabSubscriptions::UserAddOnAssignmentVersion) do |relation|
            relation.for_add_on_purchases(add_on_purchases_relation)
          end
        end

        def add_on_purchases_relation
          ::GitlabSubscriptions::AddOnPurchase.by_namespace(group)
        end
        strong_memoize_attr :add_on_purchases_relation

        # rubocop:disable CodeReuse/ActiveRecord -- Query specific to this service
        def transfer_ai_catalog_items
          project_ids = ::Project.in_namespace(group.self_and_descendant_ids(skope: ::Namespace)).select(:id)

          update_organization_id_for(::Ai::Catalog::Item) do |relation|
            relation.where(project_id: project_ids)
          end
        end
        # rubocop:enable CodeReuse/ActiveRecord

        def transfer_custom_dashboards
          # Dashboards scoped to a namespace in the transferred group move with
          # it; organization-scoped dashboards (namespace_id: nil) stay with the
          # old organization. The dashboards subquery filters on namespace_id
          # only, so it stays valid after the parent update below.
          descendant_ids = group.self_and_descendant_ids(skope: ::Namespace)
          dashboards = ::Analytics::CustomDashboards::Dashboard.by_namespace(descendant_ids)

          update_organization_id_for(::Analytics::CustomDashboards::Dashboard) do |relation|
            relation.by_namespace(descendant_ids)
          end

          update_organization_id_for(::Analytics::CustomDashboards::SearchData) do |relation|
            relation.for_custom_dashboards(dashboards)
          end

          update_organization_id_for(::Analytics::CustomDashboards::DashboardVersion) do |relation|
            relation.for_custom_dashboards(dashboards)
          end
        end
      end
    end
  end
end
