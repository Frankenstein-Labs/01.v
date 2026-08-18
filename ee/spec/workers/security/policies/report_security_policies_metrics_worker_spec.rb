# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Policies::ReportSecurityPoliciesMetricsWorker, feature_category: :security_policy_management do
  describe '#perform' do
    subject(:run_worker) { described_class.new.perform }

    shared_examples 'reports prometheus metrics' do
      it 'reports prometheus metrics' do
        queue_size_gauge_double = instance_double(Prometheus::Client::Gauge)

        expect(Gitlab::Metrics).to receive(:gauge)
                                     .at_least(:once)
                                     .with(:security_policies_active_builds_scheduled_scans, anything, {})
                                     .and_return(queue_size_gauge_double)

        expect(queue_size_gauge_double).to receive(:set).with({}, active_ci_builds_count)

        run_worker
      end
    end

    context 'when there is no active ci builds created by scan execution policy scheduled scans' do
      let(:active_ci_builds_count) { 0 }

      it_behaves_like 'reports prometheus metrics'
    end

    context 'when there are active ci builds created by scan execution policy scheduled scans' do
      before do
        create_list(:ci_build, 2,
          :running,
          created_at: 1.minute.ago,
          updated_at: 1.minute.ago,
          pipeline: create(:ci_pipeline, source: :security_orchestration_policy))
        create(:ci_build, :success,
          created_at: 1.minute.ago,
          updated_at: 1.minute.ago,
          pipeline: create(:ci_pipeline, source: :security_orchestration_policy))
        create(:ci_build, :failed,
          created_at: 1.minute.ago,
          updated_at: 1.minute.ago,
          pipeline: create(:ci_pipeline, source: :security_orchestration_policy))
      end

      let(:active_ci_builds_count) { 2 }

      it_behaves_like 'reports prometheus metrics'
    end

    context 'when there is a timeout error' do
      before do
        allow(Ci::Build).to receive(:with_pipeline_source_type).and_raise(ActiveRecord::QueryCanceled.new('timeout'))
      end

      it 'does not report prometheus metrics' do
        expect(Gitlab::Metrics).not_to receive(:gauge)

        run_worker
      end

      it 'logs the timeout error' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(an_instance_of(ActiveRecord::QueryCanceled),
          metric: 'security_policies_active_builds_scheduled_scans')

        run_worker
      end

      it 'handles timeout gracefully without affecting other operations' do
        expect { run_worker }.not_to raise_error
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:active_ci_builds_count) { 0 }

      it_behaves_like 'reports prometheus metrics'
    end
  end
end
