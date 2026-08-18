# frozen_string_literal: true

module Ai
  module Catalog
    module Onboarding
      class WorkflowTracker
        CACHE_TTL = 7.days

        def initialize(project)
          @project = project
        end

        def track(event_type, workflow)
          Rails.cache.write(cache_key(event_type), workflow.id, expires_in: CACHE_TTL)
        end

        def workflow_for(event_type)
          cached_id = Rails.cache.read(cache_key(event_type))
          return unless cached_id

          workflow = ::Ai::DuoWorkflows::Workflow.for_project(@project).find_by(id: cached_id)

          unless workflow
            Rails.cache.delete(cache_key(event_type))
            return
          end

          workflow
        end

        def active_workflow(event_type)
          workflow = workflow_for(event_type)
          return unless workflow&.created? || workflow&.running?

          workflow
        end

        private

        def cache_key(event_type)
          ['duo_agent_onboarding', event_type.to_s, @project.id]
        end
      end
    end
  end
end
