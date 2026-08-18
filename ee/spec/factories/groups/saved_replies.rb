# frozen_string_literal: true

FactoryBot.define do
  factory :group_saved_reply, class: 'Groups::SavedReply' do
    sequence(:name) { |n| "saved_reply_#{n}" }
    content { 'Saved Reply Content' }

    group
  end
end
