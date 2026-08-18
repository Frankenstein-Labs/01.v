# frozen_string_literal: true

FactoryBot.define do
  factory :project_saved_reply, class: 'Projects::SavedReply' do
    sequence(:name) { |n| "saved_reply_#{n}" }
    content { 'Saved Reply Content' }

    project
  end
end
