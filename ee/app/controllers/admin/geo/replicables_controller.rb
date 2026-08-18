# frozen_string_literal: true

module Admin
  module Geo
    class ReplicablesController < Admin::Geo::ApplicationController
      before_action :check_license!
      before_action :set_replicator_class, only: [:index, :show]
      before_action :set_replicator_with_id, only: :show
      before_action :load_node_data, only: [:index, :show]

      def index
        # legacy routes always get redirected, either to the current node, or
        # if a secondary, we know the ID this should use, so redirect there instead
        return if params.permit(:id)[:id].present?

        redirect_path = if ::Gitlab::Geo.secondary?
                          site_replicables_admin_geo_node_path(
                            id: ::Gitlab::Geo.current_node.id,
                            replicable_name_plural: replicable_name_plural
                          )
                        else
                          admin_geo_nodes_path
                        end

        redirect_to redirect_path
      end

      def show; end

      def set_replicator_class
        replicable_name = replicable_name_plural.singularize

        @replicator_class = Gitlab::Geo::Replicator.for_replicable_name(replicable_name)
      rescue NotImplementedError
        render_404
      end

      def set_replicator_with_id
        replicable_id = params.permit(:replicable_id)[:replicable_id].to_i
        return render_404 if replicable_id <= 0

        replicable_name = replicable_name_plural.singularize

        @replicator = Gitlab::Geo::Replicator.for_replicable_params(replicable_name:, replicable_id:)
      rescue NotImplementedError
        render_404
      end

      def replicable_name_plural
        params.permit(:replicable_name_plural)[:replicable_name_plural]
      end
    end
  end
end
