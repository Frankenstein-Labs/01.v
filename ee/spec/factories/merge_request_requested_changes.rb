# frozen_string_literal: true

FactoryBot.define do
  factory :merge_request_requested_changes, class: 'MergeRequests::RequestedChange' do
    user
    merge_request
    project
  end
end
