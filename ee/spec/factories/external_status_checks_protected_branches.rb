# frozen_string_literal: true

FactoryBot.define do
  factory :external_status_checks_protected_branch, class: 'MergeRequests::ExternalStatusChecksProtectedBranch' do
    external_status_check
    protected_branch
  end
end
