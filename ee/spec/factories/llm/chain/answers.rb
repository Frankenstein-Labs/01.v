# frozen_string_literal: true

FactoryBot.define do
  factory :answer, class: '::Gitlab::Llm::Chain::Answer' do
    status { :ok }
    is_final { false }
    gitlab_context { 'context' }
    content { 'content' }
    tool { nil }
    suggestion { nil }
    extras { nil }

    trait :final do
      is_final { true }
    end

    trait :tool do
      tool { Gitlab::Llm::Chain::Tools::IssueReader }
      suggestion { 'suggestion' }
    end

    initialize_with do
      new(
        status: status,
        context: gitlab_context,
        content: content,
        tool: tool,
        suggestions: suggestion,
        is_final: is_final,
        extras: extras
      )
    end

    skip_create
  end
end
