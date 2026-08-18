# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::AiMetricsService, feature_category: :value_stream_management do
  include ClickHouseHelpers

  subject(:service_response) do
    described_class.new(current_user, namespace: container, from: from, to: to, fields: fields).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:user1) { create(:user, developer_of: group) }

  let(:current_user) { user1 }
  let(:from) { Time.current }
  let(:to) { Time.current }
  let(:fields) do
    Analytics::AiAnalytics::DuoChatUsageService::FIELDS +
      Analytics::AiAnalytics::CodeSuggestionUsageService::FIELDS +
      Analytics::AiAnalytics::DuoUsageService::FIELDS
  end

  shared_examples 'common ai metrics service' do
    let(:expected_filters) { { from: from, to: to, fields: fields } }

    before do
      allow_next_instance_of(::Analytics::AiAnalytics::DuoChatUsageService, current_user,
        hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success(
          payload: { duo_chat_contributors_count: 8 }))
      end

      allow_next_instance_of(::Analytics::AiAnalytics::CodeSuggestionUsageService, current_user,
        hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
          code_contributors_count: 10,
          code_suggestions_contributors_count: 3,
          code_suggestions_shown_count: 5,
          code_suggestions_accepted_count: 2
        }))
      end

      allow_next_instance_of(::Analytics::AiAnalytics::DuoUsageService, current_user,
        hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: { duo_used_count: 11 }))
      end
    end

    it 'returns merged payload of all services' do
      expect(service_response).to be_success
      expect(service_response.payload).to eq({
        duo_chat_contributors_count: 8,
        code_contributors_count: 10,
        code_suggestions_contributors_count: 3,
        code_suggestions_shown_count: 5,
        code_suggestions_accepted_count: 2,
        duo_used_count: 11
      })
    end
  end

  shared_examples 'handles nil date parameters' do
    let(:expected_filters) { { from: nil, to: nil, fields: fields } }

    before do
      allow_next_instance_of(::Analytics::AiAnalytics::DuoChatUsageService, current_user,
        hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute).and_return(
          ServiceResponse.success(payload: { duo_chat_contributors_count: 8 }))
      end

      allow_next_instance_of(::Analytics::AiAnalytics::CodeSuggestionUsageService, current_user,
        hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
          code_contributors_count: 10,
          code_suggestions_contributors_count: 3,
          code_suggestions_shown_count: 5,
          code_suggestions_accepted_count: 2
        }))
      end

      allow_next_instance_of(::Analytics::AiAnalytics::DuoUsageService, current_user,
        hash_including(expected_filters)) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: { duo_used_count: 11 }))
      end
    end

    it 'returns merged payload of all services with nil parameters' do
      expect(service_response).to be_success
      expect(service_response.payload).to eq({
        duo_chat_contributors_count: 8,
        code_contributors_count: 10,
        code_suggestions_contributors_count: 3,
        code_suggestions_shown_count: 5,
        code_suggestions_accepted_count: 2,
        duo_used_count: 11
      })
    end
  end

  context 'for group' do
    let_it_be(:container) { subgroup }

    it_behaves_like 'common ai metrics service'

    context 'with nil date parameters' do
      let(:from) { nil }
      let(:to) { nil }

      it_behaves_like 'handles nil date parameters'
    end
  end

  context 'for project' do
    let_it_be(:container) { project.project_namespace.reload }

    it_behaves_like 'common ai metrics service'

    context 'with nil date parameters' do
      let(:from) { nil }
      let(:to) { nil }

      it_behaves_like 'handles nil date parameters'
    end
  end
end
