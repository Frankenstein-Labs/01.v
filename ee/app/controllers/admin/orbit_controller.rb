# frozen_string_literal: true

module Admin
  class OrbitController < Admin::ApplicationController
    feature_category :knowledge_graph
    urgency :low

    before_action :check_orbit_available!

    private

    def check_orbit_available!
      render_404 unless can?(current_user, :read_admin_knowledge_graph_settings)
    end
  end
end
