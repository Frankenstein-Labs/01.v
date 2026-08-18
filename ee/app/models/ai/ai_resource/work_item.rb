# frozen_string_literal: true

module Ai
  module AiResource
    class WorkItem < Ai::AiResource::Issue
      def serialize_for_ai(content_limit: default_content_limit)
        synced_epic = resource.synced_epic
        if synced_epic
          ::EpicSerializer.new(current_user: current_user) # rubocop: disable CodeReuse/Serializer -- we need to serialize resource here
                          .represent(synced_epic, {
                            user: current_user,
                            notes_limit: content_limit,
                            serializer: 'ai',
                            resource: self
                          })
        else
          super
        end
      end

      def current_page_type
        'work_item'
      end
    end
  end
end
