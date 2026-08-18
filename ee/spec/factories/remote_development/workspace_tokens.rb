# frozen_string_literal: true

FactoryBot.define do
  factory :workspace_token, class: 'RemoteDevelopment::WorkspaceToken' do
    association :workspace
  end
end
