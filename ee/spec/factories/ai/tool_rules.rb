# frozen_string_literal: true

FactoryBot.define do
  factory :ai_tool_rule, class: 'Ai::ToolRule' do
    namespace { build_stubbed(:namespace) }
    tool_name { 'create_issue' }
    web_access { :ask }
  end
end
