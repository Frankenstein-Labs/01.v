# frozen_string_literal: true

FactoryBot.define do
  factory :analyzer_project_status, class: 'Security::AnalyzerProjectStatus' do
    project
    build { nil }
    status { :success }
    analyzer_type { :sast }
    last_call { Time.current }
    archived { false }

    after(:build) do |status, _|
      status.traversal_ids = status.project&.namespace&.traversal_ids
    end

    Enums::Security.analyzer_types_for_status.each_key do |type|
      trait type do
        analyzer_type { type }
      end
    end
  end
end
