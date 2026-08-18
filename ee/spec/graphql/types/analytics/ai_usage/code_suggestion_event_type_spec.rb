# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiUsage::CodeSuggestionEventType, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be_with_reload(:namespace) { create(:namespace) }
  let_it_be_with_reload(:user) { create(:user, namespace: namespace) }
  let_it_be(:extras) { { language: 'ruby', suggestion_size: '3', unique_tracking_id: '12345' } }
  let_it_be(:usage_event) do
    create(:ai_usage_event, user: user, namespace: namespace, extras: extras)
  end

  let(:batch_loader) { instance_double(Gitlab::Graphql::Loaders::BatchModelLoader) }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(:timestamp, :event, :user,
      :language, :suggestionSize, :uniqueTrackingId)
  end

  %i[language suggestion_size unique_tracking_id].each do |field|
    describe "##{field}" do
      it 'resolves from extras' do
        expect(resolve_field(field, usage_event, current_user: user)).to eq(extras[field])
      end
    end
  end
end
