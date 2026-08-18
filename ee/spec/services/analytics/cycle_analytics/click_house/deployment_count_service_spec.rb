# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::ClickHouse::DeploymentCountService, :click_house, :freeze_time, feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:other_project) { create(:project, group: group) }
  let_it_be(:production_env) { create(:environment, :production, project: project) }
  let_it_be(:staging_env) { create(:environment, :staging, project: project) }

  let(:from) { 15.days.ago.to_date }
  let(:to) { 1.day.ago.to_date }
  let(:traversal_path) { project.project_namespace.traversal_path(with_organization: true) }

  subject(:service) { described_class.new(traversal_path: traversal_path, from: from, to: to) }

  def insert_environments(*envs)
    clickhouse_fixture(:siphon_environments, envs.map do |env|
      {
        id: env.id,
        project_id: env.project_id,
        traversal_path: env.project.project_namespace.traversal_path(with_organization: true),
        tier: ::Environment.tiers[env.tier.to_sym],
        _siphon_deleted: false,
        _siphon_replicated_at: Time.current
      }
    end)
  end

  def insert_deployment(id:, env:, status:, finished_at:, deleted: false, replicated_at: Time.current)
    clickhouse_fixture(:siphon_deployments, [{
      id: id,
      project_id: env.project_id,
      traversal_path: env.project.project_namespace.traversal_path(with_organization: true),
      environment_id: env.id,
      status: ::Deployment.statuses[status],
      finished_at: finished_at,
      _siphon_deleted: deleted,
      _siphon_replicated_at: replicated_at
    }])
  end

  before do
    insert_environments(production_env, staging_env)
  end

  it 'returns 0 when no deployments exist' do
    expect(service.execute).to eq(0)
  end

  context 'with successful production deployments' do
    before do
      insert_deployment(id: 1, env: production_env, status: :success, finished_at: 5.days.ago)
      insert_deployment(id: 2, env: production_env, status: :success, finished_at: 10.days.ago)
    end

    it 'counts successful production deployments' do
      expect(service.execute).to eq(2)
    end
  end

  context 'when deployments are outside the date range' do
    before do
      insert_deployment(id: 1, env: production_env, status: :success, finished_at: 20.days.ago)
    end

    it 'returns 0' do
      expect(service.execute).to eq(0)
    end
  end

  context 'when deployments are to non-production environments' do
    before do
      insert_deployment(id: 1, env: staging_env, status: :success, finished_at: 5.days.ago)
    end

    it 'excludes non-production deployments' do
      expect(service.execute).to eq(0)
    end
  end

  context 'when deployments are not successful' do
    before do
      insert_deployment(id: 1, env: production_env, status: :failed, finished_at: 5.days.ago)
    end

    it 'excludes non-successful deployments' do
      expect(service.execute).to eq(0)
    end
  end

  context 'when deployments belong to projects outside the traversal path' do
    let_it_be(:other_group) { create(:group) }
    let_it_be(:unrelated_project) { create(:project, group: other_group) }
    let_it_be(:unrelated_production_env) { create(:environment, :production, project: unrelated_project) }

    before do
      insert_environments(unrelated_production_env)
      insert_deployment(id: 1, env: unrelated_production_env, status: :success, finished_at: 5.days.ago)
    end

    it 'excludes deployments from projects outside the traversal path' do
      expect(service.execute).to eq(0)
    end
  end

  context 'when traversal path covers multiple projects' do
    let_it_be(:other_production_env) { create(:environment, :production, project: other_project) }
    let(:traversal_path) { group.traversal_path(with_organization: true) }

    before do
      insert_environments(other_production_env)
      insert_deployment(id: 1, env: other_production_env, status: :success, finished_at: 5.days.ago)
      insert_deployment(id: 2, env: production_env, status: :success, finished_at: 5.days.ago)
    end

    it 'counts deployments across all projects in the group' do
      expect(service.execute).to eq(2)
    end
  end

  context 'when a deployment is marked as deleted' do
    before do
      insert_deployment(id: 1, env: production_env, status: :success,
        finished_at: 5.days.ago, replicated_at: 1.hour.ago)
      insert_deployment(id: 1, env: production_env, status: :success,
        finished_at: 5.days.ago, deleted: true, replicated_at: Time.current + 5.seconds)
    end

    it 'excludes deleted deployments' do
      expect(service.execute).to eq(0)
    end
  end

  context 'when an environment is marked as deleted' do
    before do
      insert_deployment(id: 1, env: production_env, status: :success, finished_at: 5.days.ago)
      clickhouse_fixture(:siphon_environments, [{
        id: production_env.id,
        project_id: production_env.project_id,
        traversal_path: production_env.project.project_namespace.traversal_path(with_organization: true),
        tier: ::Environment.tiers[:production],
        _siphon_deleted: true,
        _siphon_replicated_at: Time.current + 5.seconds
      }])
    end

    it 'excludes deployments to deleted environments' do
      expect(service.execute).to eq(0)
    end
  end

  context 'with date boundary inclusion (UTC)' do
    let(:from) { Date.new(2026, 4, 30) }
    let(:to) { Date.new(2026, 5, 5) }

    before do
      insert_deployment(id: 1, env: production_env, status: :success,
        finished_at: Time.utc(2026, 4, 30, 0, 0, 0))
      insert_deployment(id: 2, env: production_env, status: :success,
        finished_at: Time.utc(2026, 5, 5, 14, 0, 0))
      insert_deployment(id: 3, env: production_env, status: :success,
        finished_at: Time.utc(2026, 5, 5, 23, 59, 59))
    end

    it 'includes deployments at UTC start-of-from and end-of-to' do
      expect(service.execute).to eq(3)
    end
  end

  context 'with deployments outside the UTC day boundary' do
    let(:from) { Date.new(2026, 4, 30) }
    let(:to) { Date.new(2026, 5, 5) }

    before do
      insert_deployment(id: 1, env: production_env, status: :success,
        finished_at: Time.utc(2026, 4, 29, 23, 59, 59))
      insert_deployment(id: 2, env: production_env, status: :success,
        finished_at: Time.utc(2026, 5, 6, 0, 0, 1))
    end

    it 'excludes deployments one second outside UTC bounds' do
      expect(service.execute).to eq(0)
    end
  end

  context 'when latest replicated row supersedes status' do
    before do
      insert_deployment(id: 1, env: production_env, status: :success,
        finished_at: 5.days.ago, replicated_at: 1.hour.ago)
      insert_deployment(id: 1, env: production_env, status: :failed,
        finished_at: 5.days.ago, replicated_at: Time.current)
    end

    it 'uses argMax status and excludes the deployment' do
      expect(service.execute).to eq(0)
    end
  end
end
