# frozen_string_literal: true

module Vulnerabilities
  class ConsistencyCheckWorker
    include ApplicationWorker

    data_consistency :sticky
    feature_category :vulnerability_management

    idempotent!

    def perform(check_class_name, project_id)
      project = Project.find_by_id(project_id)

      return if project.blank?

      check_class_name.constantize.execute(project)
    end
  end
end
