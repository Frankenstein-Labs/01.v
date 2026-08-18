# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.gitlabCreditsUnavailableReason', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:current_user) { user }
  let(:duo_chat_instance) { instance_double(::Gitlab::Llm::DuoChat) }

  let(:query) do
    <<~QUERY
      query {
        gitlabCreditsUnavailableReason
      }
    QUERY
  end

  before do
    allow(::Gitlab::Llm::DuoChat).to receive(:new).and_return(duo_chat_instance)
  end

  subject(:request) { post_graphql(query, current_user: current_user) }

  context 'when user is not authenticated' do
    let(:current_user) { nil }

    it 'returns null' do
      request

      expect(graphql_data['gitlabCreditsUnavailableReason']).to be_nil
    end
  end

  context 'when credits are available' do
    before do
      allow(duo_chat_instance).to receive(:usage_billing_forbidden?).and_return(false)
    end

    it 'returns null' do
      request

      expect(graphql_data['gitlabCreditsUnavailableReason']).to be_nil
    end
  end

  context 'when billing is forbidden' do
    before do
      allow(duo_chat_instance).to receive(:usage_billing_forbidden?).and_return(true)
    end

    it 'returns USAGE_BILLING_FORBIDDEN' do
      request

      expect(graphql_data['gitlabCreditsUnavailableReason']).to eq('USAGE_BILLING_FORBIDDEN')
    end
  end

  context 'when namespace_id is provided' do
    let(:query) do
      <<~QUERY
        query {
          gitlabCreditsUnavailableReason(namespaceId: "#{global_id_of(group)}")
        }
      QUERY
    end

    before_all do
      group.add_developer(user)
    end

    before do
      allow(duo_chat_instance).to receive(:usage_billing_forbidden?).and_return(false)
    end

    it 'returns null when credits are available' do
      request

      expect(graphql_data['gitlabCreditsUnavailableReason']).to be_nil
    end
  end
end
