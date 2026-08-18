# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiUsage::AiInstanceUsageEventType, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be_with_reload(:namespace) { create(:namespace) }
  let_it_be_with_reload(:user) { create(:user, namespace: namespace) }
  let(:usage_event) { create(:ai_usage_event, user: user, namespace: namespace) }

  it 'has timestamp event user extras namespace_path fields' do
    expect(described_class).to have_graphql_fields(*%w[timestamp event user extras namespace_path])
  end

  describe '#namespace_path' do
    subject(:resolved_field) { resolve_field(:namespace_path, field_object, current_user: user) }

    context 'for ClickHouse data', :click_house do
      let(:field_object) { ClickHouse::Client.select("SELECT * FROM ai_usage_events LIMIT 1", :main).first }

      before do
        allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
        usage_event.store_to_clickhouse
        ClickHouse::DumpWriteBufferWorker.new.perform(Ai::UsageEvent.clickhouse_table_name)
      end

      it { is_expected.to eq(namespace.traversal_path(with_organization: false)) }
    end

    context 'for Postgres data' do
      let(:field_object) { usage_event }

      it 'returns namespace_path' do
        expect(resolved_field.value).to eq(namespace.traversal_path(with_organization: false))
      end
    end
  end
end
