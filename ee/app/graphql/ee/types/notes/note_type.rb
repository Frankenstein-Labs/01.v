# frozen_string_literal: true

module EE
  module Types
    module Notes
      module NoteType
        extend ActiveSupport::Concern

        prepended do
          field :duo_workflow_links,
            resolver: ::Resolvers::Ai::DuoWorkflows::NoteDuoWorkflowLinksResolver,
            description: 'GitLab Duo Agent Platform sessions linked to the note.' do
              extension ::Gitlab::Graphql::Limit::FieldCallCount, limit: 1
            end

          field :duo_triggered_session,
            ::Types::Ai::DuoWorkflows::WorkflowType,
            null: true,
            directives: granular_scope_directive(
              permissions: :read_duo_workflow, boundary: :user, boundary_type: :user
            ),
            description: 'Duo Agent Platform session triggered by the note. ' \
              'Returns nil for system notes or when no triggered session exists.'
        end

        def duo_triggered_session
          return if object.system?

          BatchLoader::GraphQL.for(object.id).batch(key: :duo_triggered_session) do |note_ids, loader|
            links = ::Ai::DuoWorkflows::WorkflowNote.triggered_for_notes(note_ids)

            resolved = {}
            links.each do |link|
              next if resolved.key?(link.note_id)

              # Record the newest link first so older links cannot be used as fallbacks
              # if the newest workflow is unauthorized.
              resolved[link.note_id] = nil

              workflow = link.workflow
              next unless workflow
              next unless Ability.allowed?(current_user, :read_duo_workflow, workflow)

              resolved[link.note_id] = workflow
            end

            note_ids.each { |id| loader.call(id, resolved[id]) }
          end
        end
      end
    end
  end
end
