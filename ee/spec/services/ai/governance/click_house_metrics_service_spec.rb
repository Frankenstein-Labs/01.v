# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Governance::ClickHouseMetricsService, :click_house,
  feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:user) { create(:user) }

  let(:timeframe) { Ai::Governance::MetricsTimeframe.new(:last_7_days) }
  let(:project_path) { project.project_namespace.traversal_path(with_organization: true) }

  around do |example|
    travel_to(Time.utc(2026, 7, 3, 15, 30)) { example.run }
  end

  before do
    insert_rows([
      { id: 1, definition: 'software_development', created_at: '2026-07-01 10:00:00', path: project_path },
      { id: 2, definition: 'software_development', created_at: '2026-07-01 12:00:00', path: project_path,
        environment: 2 },
      { id: 3, definition: 'convert_to_gitlab_ci', created_at: '2026-06-28 09:00:00', path: project_path },
      { id: 4, definition: 'software_development', created_at: '2026-06-20 09:00:00', path: project_path },
      { id: 5, definition: 'chat', created_at: '2026-07-01 09:00:00', path: project_path },
      { id: 6, definition: 'software_development', created_at: '2026-07-01 09:00:00', path: '0/999/' },
      { id: 7, definition: 'software_development', created_at: '2026-07-01 11:00:00', path: project_path,
        project_id: 12345 }
    ])
    # duplicate version of id 1 (siphon update) - must not double-count
    insert_rows([{ id: 1, definition: 'software_development', created_at: '2026-07-01 10:00:00',
                   path: project_path, replicated_at: '2026-07-02 00:00:00' }])
  end

  subject(:payload) { described_class.new(group, current_user: user, timeframe: timeframe).execute.payload }

  it 'counts deduplicated sessions in current and previous windows', :aggregate_failures do
    expect(payload[:sessions][:count]).to eq(4)
    expect(payload[:sessions][:previous_count]).to eq(1)
  end

  it 'counts distinct agent instances', :aggregate_failures do
    # ids 1 and 3 share (user, project, environment) across two definitions =>
    # one instance; id 2 differs on environment => a second instance; id 7
    # differs only on project_id => a third instance.
    expect(payload[:agents][:count]).to eq(3)
    expect(payload[:agents][:previous_count]).to eq(1)
  end

  it 'returns a zero-filled ascending trend', :aggregate_failures do
    trend = payload[:sessions][:trend]

    # every timeframe bucket is present, in ascending order (matches bucket_starts exactly)
    expect(trend.map { |point| point[:bucket_start] }).to eq(timeframe.bucket_starts)
    # populated bucket carries its count...
    expect(trend.find { |point| point[:bucket_start] == Time.utc(2026, 7, 1) }[:count]).to eq(3)
    # ...and a bucket with no sessions is zero-filled rather than absent
    expect(trend.find { |point| point[:bucket_start] == Time.utc(2026, 7, 2) }[:count]).to eq(0)
  end

  context 'with a project container' do
    subject(:payload) { described_class.new(project, current_user: user, timeframe: timeframe).execute.payload }

    it 'scopes by the project namespace traversal path' do
      expect(payload[:sessions][:count]).to eq(4)
    end
  end

  context 'with environments renamed in 18.6' do
    # ide (1) normalizes to chat (4), web (2) to ambient (5). Base row 1 is environment
    # NULL, row 2 is web (2). Adding ide, chat, and ambient rows for the same
    # (user, project) must not create one instance per spelling.
    before do
      insert_rows([
        { id: 20, definition: 'software_development', created_at: '2026-07-02 06:00:00',
          path: project_path, environment: 1 },
        { id: 21, definition: 'software_development', created_at: '2026-07-02 07:00:00',
          path: project_path, environment: 4 },
        { id: 22, definition: 'software_development', created_at: '2026-07-02 08:00:00',
          path: project_path, environment: 5 }
      ])
    end

    it 'collapses each renamed pair onto one agent instance' do
      # NULL environment (rows 1, 3), chat from ide+chat (20, 21), ambient from web+ambient
      # (2, 22), and row 7 which differs on project_id => 4 instances.
      expect(payload[:agents][:count]).to eq(4)
    end
  end

  context 'with agent-class segmentation' do
    using RSpec::Parameterized::TableSyntax

    # Base current-window rows have no agent_type (internal). Add external
    # sessions: two agent types, one of them twice, all sharing the
    # (user_id, project_id, environment) of internal rows 1 and 3.
    before do
      insert_rows([
        { id: 10, definition: 'software_development', created_at: '2026-07-02 09:00:00',
          path: project_path, agent_type: 'claude_code' },
        { id: 11, definition: 'software_development', created_at: '2026-07-02 10:00:00',
          path: project_path, agent_type: 'cursor' },
        { id: 12, definition: 'convert_to_gitlab_ci', created_at: '2026-07-02 11:00:00',
          path: project_path, agent_type: 'claude_code' }
      ])
    end

    where(:agent_class, :expected_sessions, :expected_agents) do
      :all          | 7 | 5
      :internal_dap | 4 | 3
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
      before do
        insert_rows([
          { id: 13, definition: 'software_development', created_at: '2026-07-02 12:00:00',
            path: project_path, agent_type: 'claude-code', agent_identity_id: 501 },
          { id: 14, definition: 'software_development', created_at: '2026-07-02 13:00:00',
            path: project_path, agent_type: 'claude-code', agent_identity_id: 502 }
        ])
      end

      it 'counts one instance per identity, not one per agent type', :aggregate_failures do
        payload = described_class.new(group, current_user: user, timeframe: timeframe,
          agent_class: :external).execute.payload

        expect(payload[:sessions][:count]).to eq(5)
        expect(payload[:agents][:count]).to eq(4)
      end
    end
  end

  context 'with namespace-attached sessions in two namespaces' do
    # num_nonnulls(namespace_id, project_id) = 1, so these carry a NULL project_id.
    # Without namespace_id in the key they collapse onto one agent instance.
    before do
      insert_rows([
        { id: 30, definition: 'software_development', created_at: '2026-07-02 06:00:00',
          path: project_path, project_id: 'NULL', namespace_id: 8001 },
        { id: 31, definition: 'software_development', created_at: '2026-07-02 07:00:00',
          path: project_path, project_id: 'NULL', namespace_id: 8002 }
      ])
    end

    it 'keeps the two namespaces as separate agent instances', :aggregate_failures do
      expect(payload[:sessions][:count]).to eq(6)
      # the three baseline instances plus one per namespace
      expect(payload[:agents][:count]).to eq(5)
    end
  end

  def insert_rows(rows)
    rows.each do |row|
      agent_type = row.key?(:agent_type) ? "'#{row[:agent_type]}'" : 'NULL'
      agent_identity_id = row.fetch(:agent_identity_id, 'NULL')
      namespace_id = row.fetch(:namespace_id, 'NULL')

      ClickHouse::Client.execute(<<~SQL, :main)
        INSERT INTO siphon_duo_workflows_workflows
          (id, user_id, project_id, namespace_id, environment, agent_type, agent_identity_id, created_at, workflow_definition, traversal_path, _siphon_replicated_at, _siphon_deleted)
        VALUES
          (#{row[:id]}, #{user.id}, #{row.fetch(:project_id, 'NULL')}, #{namespace_id}, #{row.fetch(:environment, 'NULL')}, #{agent_type}, #{agent_identity_id}, '#{row[:created_at]}', '#{row[:definition]}',
           '#{row[:path]}', '#{row.fetch(:replicated_at, row[:created_at])}', false)
      SQL
    end
  end
end
