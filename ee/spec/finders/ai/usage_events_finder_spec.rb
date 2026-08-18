# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageEventsFinder, feature_category: :value_stream_management do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user, freeze: false) { create(:user, namespace: group) }

  let_it_be(:to) { Time.zone.today }
  let_it_be(:from) { Time.zone.today - 20.days }

  let(:finder_params) do
    { from: from, to: to, namespace: group }
  end

  describe '#execute' do
    context 'when clickhouse analytics is not enabled for a namespace' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
      end

      it 'calls PostgresqlUsageEventsFinder' do
        expect(Ai::PostgresqlUsageEventsFinder).to receive(:new).with(user, **finder_params)
          .once.and_return(instance_double(Ai::PostgresqlUsageEventsFinder, execute: nil))

        described_class.new(user, **finder_params).execute
      end
    end

    context 'when clickhouse analytics is enabled for a namespace' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
      end

      it 'calls ClickHouseUsageEventsFinder' do
        expect(Ai::ClickHouseUsageEventsFinder).to receive(:new).with(user, **finder_params)
          .once.and_return(instance_double(Ai::ClickHouseUsageEventsFinder, execute: nil))

        described_class.new(user, **finder_params).execute
      end
    end
  end
end
