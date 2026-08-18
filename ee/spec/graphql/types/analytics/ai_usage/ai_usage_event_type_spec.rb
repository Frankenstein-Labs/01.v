# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiUsage::AiUsageEventType, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be_with_reload(:namespace) { create(:namespace) }
  let_it_be_with_reload(:user) { create(:user, namespace: namespace) }
  let_it_be(:usage_event) { create(:ai_usage_event, user: user, namespace: namespace) }

  let(:batch_loader) { instance_double(Gitlab::Graphql::Loaders::BatchModelLoader) }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(:timestamp, :event, :user)
  end

  describe 'fields' do
    subject(:fields) { described_class.fields }

    it 'has expected fields' do
      expected_fields = %i[timestamp user event]

      expect(described_class).to have_graphql_fields(*expected_fields)
    end

    it 'has proper types' do
      expect(fields['timestamp']).to have_graphql_type(Types::TimeType.to_non_null_type)
      expect(fields['user']).to have_graphql_type(Types::UserType.to_non_null_type)
      expect(fields['event']).to have_graphql_type(Types::Analytics::AiUsage::AiUsageEventTypeEnum.to_non_null_type)
    end
  end

  describe '#user' do
    subject(:usage_event_user) { resolve_field(:user, usage_event, current_user: user) }

    it 'fetches the user' do
      expect(Gitlab::Graphql::Loaders::BatchModelLoader)
        .to receive(:new)
        .with(User, usage_event.user.id)
        .and_return(batch_loader)
      expect(batch_loader).to receive(:find)

      usage_event_user
    end
  end
end
