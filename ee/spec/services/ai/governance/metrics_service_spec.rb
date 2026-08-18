# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Governance::MetricsService, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:response) { ServiceResponse.success(payload: {}) }

  context 'when the container is a group' do
    subject(:execute) { described_class.new(group, current_user: user, timeframe: :last_7_days).execute }

    context 'when ClickHouse is enabled for analytics' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(group).and_return(true)
      end

      it 'dispatches to the ClickHouse service and returns its response' do
        expect_next_instance_of(Ai::Governance::ClickHouseMetricsService) do |service|
          expect(service).to receive(:execute).and_return(response)
        end

        expect(execute).to eq(response)
      end
    end

    context 'when ClickHouse is not enabled' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(group).and_return(false)
      end

      it 'dispatches to the Postgres service and returns its response' do
        expect_next_instance_of(Ai::Governance::PostgresqlMetricsService) do |service|
          expect(service).to receive(:execute).and_return(response)
        end

        expect(execute).to eq(response)
      end
    end
  end

  context 'when the container is a project' do
    subject(:execute) { described_class.new(project, current_user: user, timeframe: :last_7_days).execute }

    context 'when ClickHouse is enabled for analytics' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?)
          .with(project.project_namespace).and_return(true)
      end

      it 'dispatches to the ClickHouse service and returns its response' do
        expect_next_instance_of(Ai::Governance::ClickHouseMetricsService) do |service|
          expect(service).to receive(:execute).and_return(response)
        end

        expect(execute).to eq(response)
      end
    end

    context 'when ClickHouse is not enabled' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?)
          .with(project.project_namespace).and_return(false)
      end

      it 'dispatches to the Postgres service and returns its response' do
        expect_next_instance_of(Ai::Governance::PostgresqlMetricsService) do |service|
          expect(service).to receive(:execute).and_return(response)
        end

        expect(execute).to eq(response)
      end
    end
  end

  context 'when an agent class is given' do
    subject(:execute) do
      described_class.new(group, current_user: user, timeframe: :last_7_days, agent_class: :external).execute
    end

    before do
      allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(group).and_return(false)
    end

    it 'forwards the agent class to the backend service' do
      backend = instance_double(Ai::Governance::PostgresqlMetricsService, execute: response)

      expect(Ai::Governance::PostgresqlMetricsService).to receive(:new)
        .with(group, hash_including(agent_class: :external)).and_return(backend)

      expect(execute).to eq(response)
    end
  end
end
