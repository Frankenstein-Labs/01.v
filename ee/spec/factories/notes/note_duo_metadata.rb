# frozen_string_literal: true

FactoryBot.define do
  factory :note_duo_metadata, class: 'Notes::NoteDuoMetadata' do
    namespace { association(:namespace) }
    note { association(:note) }
    workflow { association(:duo_workflows_workflow) }
  end
end
