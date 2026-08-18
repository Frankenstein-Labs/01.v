# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::CycleAnalytics::Concerns::IssuableStageResolver,
  feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:stub_resolver_class) do
    Class.new do
      attr_reader :object, :current_user

      include Resolvers::Analytics::CycleAnalytics::Concerns::IssuableStageResolver

      def initialize(namespace, user)
        @object = namespace
        @current_user = user
      end
    end
  end

  let(:resolver) { stub_resolver_class.new(group, user) }

  describe '#use_clickhouse?' do
    subject(:result) { resolver.send(:use_clickhouse?, args) }

    let(:args) { { from: 1.month.ago, to: Time.zone.today } }

    context 'when CLICKHOUSE_METRIC_CLASS is not defined' do
      it { is_expected.to be_falsy }
    end

    context 'when CLICKHOUSE_METRIC_CLASS is defined' do
      before do
        stub_resolver_class.const_set(:CLICKHOUSE_METRIC_CLASS, Class.new)
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
      end

      it { is_expected.to be(true) }

      context 'when ClickHouse analytics is disabled' do
        before do
          allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
        end

        it { is_expected.to be_falsy }
      end

      context 'when dora_metrics_use_clickhouse feature flag is disabled' do
        before do
          stub_feature_flags(dora_metrics_use_clickhouse: false)
        end

        it { is_expected.to be_falsy }
      end

      described_class::UNSUPPORTED_CLICKHOUSE_FILTER_KEYS.each do |filter_key|
        context "when #{filter_key} filter is present" do
          let(:args) { { filter_key => ['value'] } }

          it { is_expected.to be_falsy }
        end
      end
    end

    context 'when CLICKHOUSE_METRIC_CLASS is defined on a superclass' do
      # Mirrors Resolvers::Analytics::CycleAnalytics::BaseCountResolver.[](:group),
      # which builds group-level resolvers as `Class.new(self) { ... }`.
      let(:group_resolver_class) { Class.new(stub_resolver_class) }
      let(:resolver) { group_resolver_class.new(group, user) }

      before do
        stub_resolver_class.const_set(:CLICKHOUSE_METRIC_CLASS, Class.new)
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#resolve' do
    let(:clickhouse_metric_class) do
      Class.new do
        attr_reader :options

        def initialize(stage:, current_user:, options:) # rubocop:disable Lint/UnusedMethodArgument -- test double signature must match the real class
          @options = options
        end

        def raw_value
          5.0
        end

        def links
          []
        end
      end
    end

    let(:metric_class) do
      Class.new do
        attr_reader :options

        def initialize(stage:, current_user:, options:) # rubocop:disable Lint/UnusedMethodArgument -- test double signature must match the real class
          @options = options
        end

        def raw_value
          3.0
        end

        def links
          []
        end
      end
    end

    context 'when use_clickhouse? returns true' do
      before do
        stub_resolver_class.const_set(:CLICKHOUSE_METRIC_CLASS, clickhouse_metric_class)
        stub_resolver_class.const_set(:METRIC_CLASS, metric_class)
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
      end

      it 'calls the ClickHouse metric class and returns formatted data' do
        result = resolver.resolve(from: 1.month.ago, to: Time.zone.today)

        expect(result).to include(value: 5.0, unit: 'days', links: [])
      end

      it 'converts from/to into UTC Time instances truncated to day boundaries' do
        from = 1.month.ago.to_date
        to = Time.zone.today

        expect(clickhouse_metric_class).to receive(:new) do |**kwargs|
          expect(kwargs[:options][:from]).to eq(from.to_time.utc.beginning_of_day)
          expect(kwargs[:options][:to]).to eq(to.to_time.utc.end_of_day)

          clickhouse_metric_class.allocate
        end

        resolver.resolve(from: from, to: to)
      end

      context 'when value is 1 day' do
        before do
          metric = clickhouse_metric_class.new(stage: nil, current_user: nil, options: {})
          allow(metric).to receive(:raw_value).and_return(1.0)
          allow(clickhouse_metric_class).to receive(:new).and_return(metric)
        end

        it 'uses singular unit' do
          expect(resolver.resolve(from: 1.month.ago, to: Time.zone.today)[:unit]).to eq('day')
        end
      end

      context 'when value is nil' do
        before do
          metric = clickhouse_metric_class.new(stage: nil, current_user: nil, options: {})
          allow(metric).to receive(:raw_value).and_return(nil)
          allow(clickhouse_metric_class).to receive(:new).and_return(metric)
        end

        it 'returns nil value' do
          expect(resolver.resolve(from: 1.month.ago, to: Time.zone.today)[:value]).to be_nil
        end
      end
    end

    context 'when use_clickhouse? returns false' do
      before do
        stub_resolver_class.const_set(:METRIC_CLASS, metric_class)
      end

      it 'calls the PG metric and returns formatted data' do
        result = resolver.resolve(from: 1.month.ago, to: Time.zone.today)

        expect(result).to include(value: 3.0, unit: 'days', links: [])
      end

      it 'leaves from/to untouched' do
        from = 1.month.ago.to_date
        to = Time.zone.today

        expect(metric_class).to receive(:new) do |**kwargs|
          expect(kwargs[:options][:from]).to eq(from)
          expect(kwargs[:options][:to]).to eq(to)

          metric_class.allocate
        end

        resolver.resolve(from: from, to: to)
      end
    end

    context 'when METRIC_CLASS is not defined' do
      it 'raises NameError' do
        expect { resolver.resolve(from: 1.month.ago, to: Time.zone.today) }.to raise_error(NameError)
      end
    end
  end
end
