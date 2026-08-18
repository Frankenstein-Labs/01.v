# frozen_string_literal: true

module Analytics
  module KnowledgeGraph
    class RequestContext
      attr_reader :source_type, :session_id, :user_agent

      def initialize(source_type: nil, session_id: nil, user_agent: nil)
        @source_type = source_type
        @session_id = session_id
        @user_agent = user_agent
      end
    end
  end
end
