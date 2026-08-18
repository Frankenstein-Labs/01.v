# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::ObservabilityIssuesHelper, feature_category: :observability do
  using RSpec::Parameterized::TableSyntax

  let(:project) { build_stubbed(:project) }
  let(:user) { build_stubbed(:user) }

  describe '#observability_issue_params' do
    let(:params) do
      {
        observability_links: {
          metrics: CGI.escape('{"a":"b"}'),
          logs: CGI.escape('{"a":"b"}'),
          tracing: CGI.escape('{"a":"b"}')
        }
      }
    end

    let(:service) do
      ::Issues::BuildService.new(container: project, current_user: user, params: params)
    end

    subject do
      service.observability_issue_params
    end

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :read_observability, project).and_return(true)
    end

    context 'when user does not have permissions' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :read_observability, project).and_return(false)
      end

      it { is_expected.to eq({}) }
    end

    context 'when feature flag and licence flag are enabled and user have permissions' do
      context 'when params are empty' do
        let(:params) { {} }

        it { is_expected.to eq({}) }
      end

      context 'when observability_links params is empty' do
        let(:params) { { observability_links: {} } }

        it { is_expected.to eq({}) }
      end

      context 'when observability_links[:logs] is invalid JSON' do
        let(:params) do
          { observability_links: { logs: 'invalidjson' } }
        end

        it { is_expected.to eq({}) }
      end

      context 'when observability_links[:metrics] is invalid JSON' do
        let(:params) do
          { observability_links: { metrics: 'invalidjson' } }
        end

        it { is_expected.to eq({}) }
      end

      context 'when observability_links[:tracing] is invalid JSON' do
        let(:params) do
          { observability_links: { tracing: 'invalidjson' } }
        end

        it { is_expected.to eq({}) }
      end

      context 'when observability_links[:logs] is valid stringified JSON' do
        let(:params) do
          { observability_links: { logs: '{"a":"b"}' } }
        end

        let(:expected_params) do
          {
            foo: 'bar'
          }
        end

        before do
          allow(service).to receive(:observability_logs_issues_params).and_return(expected_params)
        end

        it { is_expected.to eq(expected_params) }
      end

      context 'when observability_links[:metrics] is valid stringified JSON' do
        let(:params) do
          { observability_links: { metrics: '{"a":"b"}' } }
        end

        let(:expected_params) do
          {
            foo: 'baz'
          }
        end

        before do
          allow(service).to receive(:observability_metrics_issues_params).and_return(expected_params)
        end

        it { is_expected.to eq(expected_params) }
      end

      context 'when observability_links[:tracing] is valid stringified JSON' do
        let(:params) do
          { observability_links: { tracing: '{"a":"b"}' } }
        end

        let(:expected_params) do
          {
            foo: 'baz'
          }
        end

        before do
          allow(service).to receive(:observability_tracing_issues_params).and_return(expected_params)
        end

        it { is_expected.to eq(expected_params) }
      end
    end
  end
end
