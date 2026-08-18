# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Resolvers::Ci::Minutes::DedicatedMonthlyUsageResolver, feature_category: :hosted_runners do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:namespace1) { create(:namespace) }
  let_it_be(:namespace2) { create(:namespace) }
  let_it_be(:billing_month) { Date.new(2025, 1, 1) }
  let_it_be(:billing_month2) { Date.new(2025, 2, 1) }

  let_it_be(:usage1) do
    create(:ci_hosted_runner_monthly_usage, billing_month: billing_month, compute_minutes_used: 100,
      runner_duration_seconds: 6000, root_namespace: namespace1)
  end

  let_it_be(:usage2) do
    create(:ci_hosted_runner_monthly_usage, billing_month: billing_month, compute_minutes_used: 200,
      runner_duration_seconds: 12000, root_namespace: namespace2)
  end

  let_it_be(:usage3) do
    create(:ci_hosted_runner_monthly_usage, billing_month: billing_month2, compute_minutes_used: 100,
      runner_duration_seconds: 6000, root_namespace: namespace1)
  end

  let_it_be(:usage4) do
    create(:ci_hosted_runner_monthly_usage, billing_month: billing_month2, compute_minutes_used: 200,
      runner_duration_seconds: 12000, root_namespace: namespace2)
  end

  let(:year) { nil }
  let(:args) { { billing_month: billing_month_arg, year: year, grouping: grouping } }

  before do
    stub_application_setting(gitlab_dedicated_instance: true)
  end

  describe '#resolve' do
    context 'when grouping is INSTANCE_AGGREGATE', :enable_admin_mode do
      let(:grouping) { 'INSTANCE_AGGREGATE' }
      let(:billing_month_arg) { billing_month }

      it 'returns the correct instance aggregate data' do
        result = resolve_usage(admin)

        expect(result.count).to eq(1)
        expect(result.first.compute_minutes).to eq(usage1.compute_minutes_used + usage2.compute_minutes_used)
        expect(result.first.duration_seconds).to eq(usage1.runner_duration_seconds + usage2.runner_duration_seconds)
        expect(result.first.root_namespace).to be_nil
      end

      context 'when year is passed', :enable_admin_mode do
        let(:billing_month_arg) { nil }
        let(:year) { 2025 }

        it 'returns the correct instance aggregate data for all months in the year' do
          result = resolve_usage(admin)

          expect(result.count).to eq(2)
          expect(result.map(&:billing_month_iso8601)).to match_array([
            billing_month.iso8601,
            billing_month2.iso8601
          ])
          expect(result.sum(&:compute_minutes)).to eq(
            usage1.compute_minutes_used + usage2.compute_minutes_used +
            usage3.compute_minutes_used + usage4.compute_minutes_used
          )
          expect(result.sum(&:duration_seconds)).to eq(
            usage1.runner_duration_seconds + usage2.runner_duration_seconds +
            usage3.runner_duration_seconds + usage4.runner_duration_seconds
          )
          expect(result.first.root_namespace).to be_nil
        end
      end
    end

    context 'when grouping is PER_ROOT_NAMESPACE', :enable_admin_mode do
      let(:grouping) { 'PER_ROOT_NAMESPACE' }
      let(:billing_month_arg) { billing_month }

      it 'returns the correct data per root namespace' do
        result = resolve_usage(admin)

        expect(result.count).to eq(2)
        expect(result.map(&:root_namespace_id)).to match_array([namespace1.id, namespace2.id])

        namespace1_usage = result.find { |usage| usage.root_namespace_id == namespace1.id }
        namespace2_usage = result.find { |usage| usage.root_namespace_id == namespace2.id }

        expect(namespace1_usage.compute_minutes).to eq(usage1.compute_minutes_used)
        expect(namespace2_usage.compute_minutes).to eq(usage2.compute_minutes_used)
      end

      context 'when year is passed', :enable_admin_mode do
        let(:billing_month_arg) { nil }
        let(:year) { 2025 }

        it 'returns the correct data per root namespace for all months in the year' do
          result = resolve_usage(admin)

          expect(result.count).to eq(4)
          expect(result.map(&:billing_month_iso8601)).to match_array([
            billing_month2.iso8601,
            billing_month2.iso8601,
            billing_month.iso8601,
            billing_month.iso8601
          ])
          expect(result.sum(&:compute_minutes)).to eq(
            usage1.compute_minutes_used +
            usage2.compute_minutes_used +
            usage3.compute_minutes_used +
            usage4.compute_minutes_used
          )
          expect(result.sum(&:duration_seconds)).to eq(
            usage1.runner_duration_seconds +
            usage2.runner_duration_seconds +
            usage3.runner_duration_seconds +
            usage4.runner_duration_seconds
          )
        end
      end
    end

    context 'with runner_id filter', :enable_admin_mode do
      let_it_be(:runner) { create(:ci_runner) }
      let_it_be(:other_runner) { create(:ci_runner) }
      let_it_be(:usage1) { create(:ci_hosted_runner_monthly_usage, runner: runner, compute_minutes_used: 100) }
      let_it_be(:usage2) { create(:ci_hosted_runner_monthly_usage, runner: other_runner, compute_minutes_used: 200) }

      let(:args) { { grouping: 'INSTANCE_AGGREGATE', runner_id: runner.to_global_id } }

      it 'returns usage data only for the specified runner' do
        result = resolve_usage(admin)
        expect(result.first.compute_minutes).to eq(100)
      end
    end

    describe 'auth' do
      context 'when user is not on GitLab Dedicated', :enable_admin_mode do
        let(:grouping) { 'INSTANCE_AGGREGATE' }
        let(:billing_month_arg) { billing_month }

        before do
          stub_application_setting(gitlab_dedicated_instance: false)
        end

        it 'returns no data' do
          result = resolve_usage(admin)

          expect(result).to be_empty
        end
      end

      context 'when user is not an admin' do
        let(:grouping) { 'INSTANCE_AGGREGATE' }
        let(:billing_month_arg) { billing_month }

        it 'returns no data' do
          result = resolve_usage(user)

          expect(result).to be_empty
        end
      end
    end

    def resolve_usage(current_user)
      resolve(described_class, obj: nil, args: args, ctx: { current_user: current_user }).to_a
    end
  end
end
