# frozen_string_literal: true

FactoryBot.define do
  factory :analyzer_namespace_status, class: 'Security::AnalyzerNamespaceStatus' do
    namespace
    success { 0 }
    failure { 0 }
    stale { 0 }
    analyzer_type { :sast }

    after(:build) do |status, _|
      status.traversal_ids = status.namespace&.traversal_ids
    end
  end
end
