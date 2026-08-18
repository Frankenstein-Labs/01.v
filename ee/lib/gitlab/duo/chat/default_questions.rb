# frozen_string_literal: true

module Gitlab
  module Duo
    module Chat
      class DefaultQuestions
        SUPPORTED_CONTEXT = [
          :code, :issue, :epic, :merge_request, :commit, :ci_build, :wiki
        ].freeze

        DEFAULT = [
          "How can I improve my code security?",
          "What are code review best practices?",
          "Help me set up continuous deployment",
          "Show me automated testing strategies",
          "How can I organize projects effectively in GitLab?",
          "How do I manage environment variables?",
          "What causes pipeline failures?",
          "How do I securely store secrets in GitLab CI/CD?",
          "How do I scan dependencies for vulnerabilities?",
          "How do I make my CI pipelines run faster?",
          "How do I debug issues with GitLab runners?",
          "How do I set up quality gates in my pipeline?",
          "How should I structure complex epics?",
          "What makes good acceptance criteria?",
          "How do I estimate story points?"
        ].freeze

        CODE = [
          "What does this code do?",
          "How can I make this code more efficient?",
          "Identify any security vulnerabilities in my code",
          "Are there any bugs in this code?",
          "Create documentation for this code"
        ].freeze

        WIKI = [
          "What is this wiki page about?",
          "What discussions exist on this page?",
          "How do I create a new wiki page?",
          "How can I create a wiki page template?",
          "Where can I see page version history?",
          "How do I customize the wiki sidebar?"
        ].freeze

        # @param [User] user
        # @param [String] url
        # @param [Ai::AiResource] resource - one of the subtypes of AiResource
        def initialize(user, url: nil, resource: nil)
          @user = user
          @resource = resource
          @page_url = url
        end

        def execute
          return questions_from_resource if resource
          return DEFAULT if page_url.blank?

          questions_from_url
        end

        private

        attr_reader :user, :resource, :page_url

        def questions_from_resource
          return DEFAULT unless user.allowed_to_use?(
            resource.chat_unit_primitive,
            root_namespace: resource.root_namespace
          )

          resource.chat_questions
        end

        def questions_from_url
          route = ::Gitlab::Llm::Utils::RouteHelper.new(page_url)

          return CODE if route.controller == "projects/blob"
          return WIKI if route.controller == "groups/wikis" || route.controller == "projects/wikis"

          DEFAULT
        end
      end
    end
  end
end
