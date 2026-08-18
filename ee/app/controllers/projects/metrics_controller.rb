# frozen_string_literal: true

module Projects
  class MetricsController < Projects::ApplicationController
    feature_category :observability

    before_action :authorize_read_observability!

    def index; end

    def show
      @metric_id = params[:id]
      @metric_type = params[:type]
    end
  end
end
