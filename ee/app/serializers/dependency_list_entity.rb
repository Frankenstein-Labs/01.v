# frozen_string_literal: true

class DependencyListEntity < Grape::Entity
  include RequestAwareEntity

  present_collection true, :dependencies

  expose :dependencies, using: DependencyEntity

  expose :report, if: ->(_, options) { options[:pipeline] && can_read_job_path? } do
    # This data structure is kept only to avoid a breaking change to the dependency list export.
    # `pipeline` is from `project.latest_ingested_sbom_pipeline` and as long as it exists we
    # can assume that report ingestion was successful.
    expose :status, proc: ->(_) { :ok }

    expose :job_path do |_, options|
      project_pipeline_path(project, options[:pipeline].id)
    end

    expose :generated_at do |_, options|
      options[:pipeline].finished_at
    end
  end

  private

  def can_read_job_path?
    can?(request.user, :read_pipeline, project)
  end

  def project
    request.try(:project)
  end
end
