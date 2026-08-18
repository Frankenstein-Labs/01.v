# frozen_string_literal: true

module Security
  module AgentArtifactsDownloadable
    extend ActiveSupport::Concern

    included do
      before_action :authorize_view_agent_artifacts!
      before_action :check_agent_artifacts_enabled!
    end

    def download
      workflow = find_session_artifact(params.require(:id))
      return render_404 unless workflow

      send_session_artifact(workflow)
    end

    private

    # Including controllers must implement `find_session_artifact(id)` to return
    # the Ai::DuoWorkflows::Workflow backing the session, scoped to their
    # resource (group or project), or nil.
    def send_session_artifact(workflow)
      send_data(
        ::Gitlab::Json.dump(::Ai::DuoWorkflows::SessionArtifactExportService.new(workflow).as_json),
        type: 'application/json; charset=utf-8',
        filename: "session-artifact-#{workflow.id}.json",
        disposition: 'attachment'
      )
    end

    def authorize_view_agent_artifacts!
      raise NotImplementedError, "#{self.class} must implement #authorize_view_agent_artifacts!"
    end

    def check_agent_artifacts_enabled!
      raise NotImplementedError, "#{self.class} must implement #check_agent_artifacts_enabled!"
    end
  end
end
