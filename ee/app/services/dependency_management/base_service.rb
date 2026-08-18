# frozen_string_literal: true

module DependencyManagement
  class BaseService
    def initialize(project:, params: {})
      @project = project
      @params = params
    end

    private

    attr_reader :project, :params

    def success_response(message: nil, payload: {})
      ServiceResponse.success(message: message, payload: payload)
    end

    def error_response(message:, payload: {})
      ServiceResponse.error(message: message, payload: payload)
    end

    def log_error(error)
      Gitlab::ErrorTracking.track_exception(
        error,
        class: self.class.name,
        project_id: project.id,
        message: error.message
      )
    end
  end
end
