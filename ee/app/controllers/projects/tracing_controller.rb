# frozen_string_literal: true

module Projects
  class TracingController < Projects::ApplicationController
    feature_category :observability

    before_action :authorize_read_observability!

    def index; end

    def show
      @trace_id = params[:id]
    end
  end
end
