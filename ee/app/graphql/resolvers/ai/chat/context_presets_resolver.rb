# frozen_string_literal: true

module Resolvers
  module Ai
    module Chat
      class ContextPresetsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type ::Types::Ai::Chat::ContextPresetsType, null: true

        argument :question_count,
          GraphQL::Types::Int,
          required: false,
          description: 'Number of questions for the default screen.'

        argument :url,
          GraphQL::Types::String,
          required: false,
          description: 'URL of the page the user is currently on.'

        argument :resource_id,
          ::Types::GlobalIDType[::Ai::Model],
          required: false,
          description: "Global ID of the resource from the current page."

        argument :project_id, ::Types::GlobalIDType[::Project],
          required: false,
          description: "Global ID of the project the user is acting on."

        def resolve(url: nil, resource_id: nil, project_id: nil, question_count: 4)
          ai_resource = find_ai_resource(resource_id, project_id)
          questions = ::Gitlab::Duo::Chat::DefaultQuestions.new(current_user, url: url, resource: ai_resource)
                        .execute

          {
            questions: questions.sample(question_count),
            ai_resource_data: ai_resource&.serialize_for_ai&.to_json
          }
        end

        private

        def find_ai_resource(resource_id, project_id)
          resource = find_resource(resource_id, project_id)
          return unless resource

          ::Ai::AiResource::Wrapper.new(current_user, resource).wrap
        rescue ArgumentError
          nil
        end

        def find_resource(resource_id, project_id)
          return unless resource_id
          return find_commit_in_project(resource_id, project_id) if resource_id.model_class == Commit

          authorized_find!(id: resource_id)
        end

        def find_commit_in_project(resource_id, project_id)
          project = authorized_find!(id: project_id)
          return unless project

          project.commit_by(oid: resource_id.model_id)
        end

        def authorized_resource?(object)
          return unless object

          Ability.allowed?(current_user, "read_#{object.to_ability_name}", object)
        end
      end
    end
  end
end
