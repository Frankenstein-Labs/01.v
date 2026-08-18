# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Governance::PostgresqlMetricsService, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:timeframe) { Ai::Governance::MetricsTimeframe.new(:last_7_days) }

  around do |example|
    travel_to(Time.utc(2026, 7, 3, 15, 30)) { example.run }
  end

  before_all do
    create(:duo_workflows_workflow, project: project, user: user,
      workflow_definition: 'software_development', created_at: Time.utc(2026, 7, 1, 10))
    create(:duo_workflows_workflow, project: project, user: user,
      workflow_definition: 'software_development', created_at: Time.utc(2026, 7, 1, 12))
    create(:duo_workflows_workflow, project: project, user: user,
      workflow_definition: 'convert_to_gitlab_ci', created_at: Time.utc(2026, 6, 28))
    # previous window
    create(:duo_workflows_workflow, project: project, user: user,
      workflow_definition: 'software_development', created_at: Time.utc(2026, 6, 20))
    # excluded: chat
    create(:duo_workflows_workflow, project: project, user: user,
      workflow_definition: 'chat', created_at: Time.utc(2026, 7, 1))
    # excluded: outside hierarchy
    create(:duo_workflows_workflow, project: other_project, user: user,
      workflow_definition: 'software_development', created_at: Time.utc(2026, 7, 1))
  end

  subject(:payload) { described_class.new(group, current_user: user, timeframe: timeframe).execute.payload }

  it 'counts sessions in the current and previous windows for the group hierarchy', :aggregate_failures do
    expect(payload[:sessions][:count]).to eq(3)
    expect(payload[:sessions][:previous_count]).to eq(1)
  end

  it 'counts distinct active agent instances, collapsing multiple definitions', :aggregate_failures do
    # current window: 3 sessions across 2 definitions, all the same
    # (user, project, environment) tuple => one agent instance.
    expect(payload[:agents][:count]).to eq(1)
    expect(payload[:agents][:previous_count]).to eq(1)
  end

  it 'returns a zero-filled ascending trend covering every bucket', :aggregate_failures do
    trend = payload[:sessions][:trend]
    expect(trend.map { |point| point[:bucket_start] }).to eq(timeframe.bucket_starts)
    expect(trend.sum { |point| point[:count] }).to eq(3)
    expect(trend.find { |point| point[:bucket_start] == Time.utc(2026, 7, 1) }[:count]).to eq(2)
  end

  it 'resolves the whole payload in two aggregate queries against the workflows table' do
    recorder = ActiveRecord::QueryRecorder.new do
      described_class.new(group, current_user: user, timeframe: timeframe).execute
    end

    workflow_queries = recorder.log.select { |query| query.include?('duo_workflows_workflows') }
    expect(workflow_queries.size).to eq(2)
  end

  context 'with a project container' do
    subject(:payload) { described_class.new(project, current_user: user, timeframe: timeframe).execute.payload }

    it 'scopes to the project' do
      expect(payload[:sessions][:count]).to eq(3)
    end
  end

  context 'with a namespace-attached workflow on a descendant subgroup' do
    let_it_be(:subgroup_namespace_workflow) do
      create(:duo_workflows_workflow, project: nil, namespace: subgroup, user: user,
        workflow_definition: 'software_development', created_at: Time.utc(2026, 7, 1, 14))
    end

    it 'counts the descendant namespace-attached workflow in the group hierarchy' do
      expect(payload[:sessions][:count]).to eq(4)
    end

    context 'with a second namespace-attached workflow on a different subgroup' do
      let_it_be(:other_subgroup) { create(:group, parent: group) }
      let_it_be(:other_subgroup_workflow) do
        create(:duo_workflows_workflow, project: nil, namespace: other_subgroup, user: user,
          workflow_definition: 'software_development', created_at: Time.utc(2026, 7, 1, 15))
      end

      it 'keeps the two namespaces as separate agent instances', :aggregate_failures do
        # `num_nonnulls(namespace_id, project_id) = 1`, so both rows carry a NULL
        # project_id. Without namespace_id in the key they would collapse into one.
        expect(payload[:sessions][:count]).to eq(5)
        # the project-attached baseline instance, plus one per namespace
        expect(payload[:agents][:count]).to eq(3)
      end
    end
  end

  context 'with one agent active on two days' do
    # Baseline already has software_development on Jul 1 at 10:00 and 12:00 plus
    # convert_to_gitlab_ci on Jun 28, all the same (user, project, environment), so the
    # agent is one instance active across more than one bucket.
    it 'counts the agent once in the total but once per bucket in the trend', :aggregate_failures do
      expect(payload[:agents][:count]).to eq(1)

      populated = payload[:agents][:trend].reject { |point| point[:count] == 0 }

      # Two populated buckets, each reporting the single agent. Asserting the count
      # and the per-bucket value separately says what matters without depending on
      # bucket order, which `#returns a zero-filled ascending trend` already covers.
      expect(populated.size).to eq(2)
      expect(populated.map { |point| point[:count] }.uniq).to eq([1])
      # So the trend deliberately does not sum to the headline count.
      expect(populated.sum { |point| point[:count] }).to eq(2)
      expect(payload[:sessions][:trend].sum { |point| point[:count] }).to eq(payload[:sessions][:count])
    end
  end

  context 'with environments renamed in 18.6' do
    # ENVIRONMENTS_DEPRECATIONS maps ide -> chat and web -> ambient, and both spellings
    # remain valid inputs, so the same person on the same product can arrive under either.
    # They must collapse onto one agent instance.
    let_it_be(:renamed_pairs) do
      [[:ide, :chat], [:web, :ambient]].each_with_index.map do |(old_name, new_name), index|
        [old_name, new_name].each_with_index.map do |environment, offset|
          create(:duo_workflows_workflow, project: project, user: user, environment: environment,
            workflow_definition: 'software_development',
            created_at: Time.utc(2026, 7, 2, 6 + (index * 2) + offset))
        end
      end
    end

    it 'counts one agent instance per product, not one per spelling' do
      # Baseline rows are all `ide`, which normalizes to `chat`. Adding an explicit `chat`
      # row must not create a second instance, and web + ambient must contribute one.
      expect(payload[:agents][:count]).to eq(2)
    end

    it 'still counts every session' do
      expect(payload[:sessions][:count]).to eq(7)
    end
  end

  context 'with agent-class segmentation' do
    using RSpec::Parameterized::TableSyntax

    # Existing current-window rows have no agent_type (internal). Add external
    # sessions in the current window: two agent types, one of them twice, all
    # sharing the internal rows' (user, project, environment).
    before_all do
      create(:duo_workflows_workflow, project: project, user: user, agent_type: 'claude_code',
        workflow_definition: 'software_development', created_at: Time.utc(2026, 7, 2, 9))
      create(:duo_workflows_workflow, project: project, user: user, agent_type: 'cursor',
        workflow_definition: 'software_development', created_at: Time.utc(2026, 7, 2, 10))
      create(:duo_workflows_workflow, project: project, user: user, agent_type: 'claude_code',
        workflow_definition: 'convert_to_gitlab_ci', created_at: Time.utc(2026, 7, 2, 11))
    end

    where(:agent_class, :expected_sessions, :expected_agents) do
      :all          | 6 | 3
      :internal_dap | 3 | 1
      :external     | 3 | 2
    end

    with_them do
      it 'filters sessions and keys agent instances by class', :aggregate_failures do
        payload = described_class.new(group, current_user: user, timeframe: timeframe,
          agent_class: agent_class).execute.payload

        expect(payload[:sessions][:count]).to eq(expected_sessions)
        expect(payload[:agents][:count]).to eq(expected_agents)
      end
    end

    context 'with the same agent type registered on two machines' do
      let_it_be(:laptop) do
        create(:ai_agent_identity, user: user, project: project, agent_type: 'claude-code')
      end

      let_it_be(:ci_runner) do
        create(:ai_agent_identity, user: user, project: project, agent_type: 'claude-code')
      end

      before_all do
        create(:duo_workflows_workflow, project: project, user: user, agent_type: 'claude-code',
          agent_identity_id: laptop.id, workflow_definition: 'software_development',
          created_at: Time.utc(2026, 7, 2, 12))
        create(:duo_workflows_workflow, project: project, user: user, agent_type: 'claude-code',
          agent_identity_id: ci_runner.id, workflow_definition: 'software_development',
          created_at: Time.utc(2026, 7, 2, 13))
      end

      it 'counts one instance per identity, not one per agent type', :aggregate_failures do
        payload = described_class.new(group, current_user: user, timeframe: timeframe,
          agent_class: :external).execute.payload

        # claude_code, cursor (identity-less, keyed on agent_type) plus the laptop and
        # the CI runner, which share a user, project and agent type but not an identity.
        expect(payload[:sessions][:count]).to eq(5)
        expect(payload[:agents][:count]).to eq(4)
      end
    end

    it 'partitions agent instances: ALL equals INTERNAL_DAP plus EXTERNAL' do
      all, internal, external = [:all, :internal_dap, :external].map do |agent_class|
        described_class.new(group, current_user: user, timeframe: timeframe,
          agent_class: agent_class).execute.payload[:agents][:count]
      end

      expect(all).to eq(internal + external)
    end
  end
end
