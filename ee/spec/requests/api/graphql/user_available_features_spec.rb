# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying user available features', :clean_gitlab_redis_cache, feature_category: :duo_chat do
  include GraphqlHelpers

  let(:fields) do
    <<~GRAPHQL
      duoChatAvailableFeatures
    GRAPHQL
  end

  let(:query) do
    graphql_query_for('currentUser', fields)
  end

  subject(:graphql_response) { graphql_data.dig('currentUser', 'duoChatAvailableFeatures') }

  context 'when user is not logged in' do
    let(:current_user) { nil }

    it 'returns an empty response' do
      post_graphql(query, current_user: current_user)

      expect(graphql_response).to be_nil
    end
  end

  context 'when user has access to Duo Pro' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed) }

    let(:unit_primitive) do
      build(:cloud_connector_unit_primitive, name: :any_name, add_ons: %w[duo_pro])
    end

    before do
      allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:user, :allowed?).and_return(true)

      create(
        :gitlab_subscription_user_add_on_assignment,
        user: current_user,
        add_on_purchase: add_on_purchase
      )

      allow(::Gitlab::CloudConnector::DataModel::UnitPrimitive).to(
        receive(:find_by_name).and_return(nil)
      )
      allow(::Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name).with(:include_file_context)
        .and_return(unit_primitive)
      allow(::Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
        .with(:include_merge_request_context)
        .and_return(unit_primitive)
    end

    it 'returns a list of available features' do
      post_graphql(query, current_user: current_user)

      expect(graphql_response).to match_array(%w[include_file_context include_merge_request_context])
    end

    context 'when user does not have access to chat' do
      before do
        allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:user, :allowed?).and_return(false)
      end

      it 'returns an empty response' do
        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq([])
      end
    end
  end
end
