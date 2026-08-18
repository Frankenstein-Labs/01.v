# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group.dependencyFirewallRuleActivity', feature_category: :dependency_firewall do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:configuration) do
    create(:security_orchestration_policy_configuration, :namespace, namespace: group)
  end

  let_it_be(:policy) do
    create(:security_policy, :dependency_firewall_policy,
      security_orchestration_policy_configuration: configuration, name: 'Block GPL')
  end

  let_it_be(:rule) { create(:dependency_firewall_policy_rule, security_policy: policy) }

  let(:fields) do
    'id ruleType policyName enabled mode blockedCount warnedCount activityCount sourceRelationship ' \
      'lastModified { at by { id name } } ' \
      'scope { excludingPersonalProjects excludingProjects { nodes { id name } } } ' \
      'source { ... on GroupSecurityPolicySource { inherited namespace { id name } } ' \
      '... on ProjectSecurityPolicySource { project { id name } } }'
  end

  let(:query) do
    graphql_query_for(
      :group, { full_path: group.full_path },
      query_graphql_field(:dependency_firewall_rule_activity, {}, fields)
    )
  end

  let(:current_user) { user }

  subject(:activity) do
    post_graphql(query, current_user: current_user)
    graphql_data_at(:group, :dependency_firewall_rule_activity)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true, dependency_firewall: true)
  end

  context 'with recorded block activity' do
    before do
      create(:dependency_firewall_activity_stat,
        dependency_firewall_policy_rule: rule, project: project, outcome: :blocked, count: 5)
    end

    it 'returns the rule with its blocked activity' do
      expect(activity).to contain_exactly(
        a_hash_including(
          'policyName' => 'Block GPL',
          'ruleType' => 'LICENSE',
          'mode' => 'ENFORCE',
          'blockedCount' => 5,
          'warnedCount' => 0,
          'activityCount' => 5
        )
      )
    end

    it 'excludes activity from projects outside the group' do
      other_project = create(:project)
      create(:dependency_firewall_activity_stat,
        dependency_firewall_policy_rule: rule, project: other_project, outcome: :blocked, count: 99)

      expect(activity.first['blockedCount']).to eq(5)
    end
  end

  context 'with a malicious rule in scope' do
    let_it_be(:malicious_rule) do
      create(:dependency_firewall_policy_rule, security_policy: policy,
        type: Security::DependencyFirewallPolicyRule.types[:malicious],
        content: { denied: [{ is_malicious: true }] })
    end

    it 'serializes the rule type as MALICIOUS instead of raising', :aggregate_failures do
      create(:dependency_firewall_activity_stat,
        dependency_firewall_policy_rule: malicious_rule, project: project, outcome: :blocked, count: 4)

      malicious = activity.find { |rule_activity| rule_activity['ruleType'] == 'MALICIOUS' }

      expect(malicious).to be_present
      expect(malicious['blockedCount']).to eq(4)
    end
  end

  context 'when a to date is given on the same day activity was recorded' do
    let(:query) do
      graphql_query_for(
        :group, { full_path: group.full_path },
        query_graphql_field(:dependency_firewall_rule_activity, { to: Date.current.iso8601 }, fields)
      )
    end

    it 'includes activity recorded later that day (to is treated as end-of-day)' do
      create(:dependency_firewall_activity_stat,
        dependency_firewall_policy_rule: rule, project: project, outcome: :blocked,
        count: 3, stat_time: Date.current.beginning_of_day + 12.hours)

      expect(activity.first['blockedCount']).to eq(3)
    end
  end

  context 'with the default (last 7 days) window' do
    around do |example|
      travel_to(Time.utc(2026, 7, 10, 12, 0, 0)) { example.run }
    end

    it 'counts activity within the 7-day window and excludes older activity', :aggregate_failures do
      create(:dependency_firewall_activity_stat,
        dependency_firewall_policy_rule: rule, project: project, outcome: :blocked,
        count: 5, stat_time: 6.days.ago.beginning_of_day)
      create(:dependency_firewall_activity_stat,
        dependency_firewall_policy_rule: rule, project: project, outcome: :blocked,
        count: 8, stat_time: 8.days.ago)

      expect(activity.first['blockedCount']).to eq(5)
    end
  end

  context 'when from is after to' do
    let(:query) do
      graphql_query_for(
        :group, { full_path: group.full_path },
        query_graphql_field(:dependency_firewall_rule_activity,
          { from: Date.current.iso8601, to: 3.days.ago.to_date.iso8601 }, fields)
      )
    end

    it 'returns an argument error' do
      post_graphql(query, current_user: current_user)

      expect_graphql_errors_to_include('`from` must be on or before `to`')
    end
  end

  context 'without recorded activity' do
    it 'still lists the active rule with zero counts' do
      expect(activity).to contain_exactly(
        a_hash_including('blockedCount' => 0, 'warnedCount' => 0, 'activityCount' => 0)
      )
    end
  end

  context 'with a disabled policy' do
    let_it_be(:disabled_policy) do
      create(:security_policy, :dependency_firewall_policy,
        security_orchestration_policy_configuration: configuration,
        name: 'Disabled Policy', enabled: false, policy_index: 1)
    end

    let_it_be(:disabled_rule) { create(:dependency_firewall_policy_rule, security_policy: disabled_policy) }

    it 'lists the disabled rule flagged as disabled alongside enabled ones', :aggregate_failures do
      by_name = activity.index_by { |item| item['policyName'] }

      expect(by_name.keys).to include('Block GPL', 'Disabled Policy')
      expect(by_name['Disabled Policy']['enabled']).to be(false)
      expect(by_name['Block GPL']['enabled']).to be(true)
    end
  end

  describe 'last modified' do
    it 'exposes the policy last-modified timestamp' do
      expect(activity.first.dig('lastModified', 'at')).to be_present
    end

    it 'exposes the user who last modified the policy YAML', :aggregate_failures do
      editor = create(:user, name: 'Policy Editor')
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |config|
        allow(config).to receive(:policy_last_updated_by).and_return(editor)
      end

      expect(activity.first.dig('lastModified', 'by')).to include('name' => 'Policy Editor')
    end
  end

  it 'returns the policy source for a policy owned by the group (direct)', :aggregate_failures do
    rule_activity = activity.first

    expect(rule_activity['source']['inherited']).to be(false)
    expect(rule_activity['source']['namespace']).to include('name' => group.name)
    expect(rule_activity['sourceRelationship']).to eq('DIRECT')
  end

  context 'with policies defined below the group (subgroup and project)' do
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:subgroup_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: subgroup)
    end

    let_it_be(:subgroup_policy) do
      create(:security_policy, :dependency_firewall_policy,
        security_orchestration_policy_configuration: subgroup_configuration, name: 'Subgroup policy')
    end

    let_it_be(:subgroup_rule) { create(:dependency_firewall_policy_rule, security_policy: subgroup_policy) }

    let_it_be(:project_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let_it_be(:project_policy) do
      create(:security_policy, :dependency_firewall_policy,
        security_orchestration_policy_configuration: project_configuration, name: 'Project policy')
    end

    let_it_be(:project_rule) { create(:dependency_firewall_policy_rule, security_policy: project_policy) }

    it 'includes rules from subgroup and project policies as descendant sources', :aggregate_failures do
      by_name = activity.index_by { |item| item['policyName'] }

      expect(by_name.keys).to include('Block GPL', 'Subgroup policy', 'Project policy')
      expect(by_name['Subgroup policy']['sourceRelationship']).to eq('DESCENDANT')
      expect(by_name['Project policy']['sourceRelationship']).to eq('DESCENDANT')
    end

    it 'links each descendant source to its defining namespace or project', :aggregate_failures do
      by_name = activity.index_by { |item| item['policyName'] }

      expect(by_name['Subgroup policy']['source']['namespace']).to include('name' => subgroup.name)
      expect(by_name['Project policy']['source']['project']).to include('name' => project.name)
    end
  end

  context 'when viewed from a subgroup that inherits the policy' do
    let_it_be(:subgroup) { create(:group, parent: group, owners: user) }

    let(:query) do
      graphql_query_for(
        :group, { full_path: subgroup.full_path },
        query_graphql_field(:dependency_firewall_rule_activity, {}, fields)
      )
    end

    it 'marks the rule as inherited from the ancestor group', :aggregate_failures do
      post_graphql(query, current_user: current_user)
      rule_activity = graphql_data_at(:group, :dependency_firewall_rule_activity).first

      expect(rule_activity['source']['inherited']).to be(true)
      expect(rule_activity['source']['namespace']).to include('name' => group.name)
      expect(rule_activity['sourceRelationship']).to eq('INHERITED_ONLY')
    end
  end

  context "with a policy scoped to exclude a project" do
    let_it_be(:excluded_project) { create(:project, group: group) }

    before do
      Security::Policy.find(policy.id).update!(scope: { projects: { excluding: [{ id: excluded_project.id }] } })
    end

    it 'resolves the policy scope, including excluded projects' do
      scope = activity.first['scope']

      expect(scope['excludingProjects']['nodes']).to contain_exactly(
        a_hash_including('name' => excluded_project.name)
      )
    end
  end

  it 'does not produce N+1 queries as more rules are added' do
    create(:dependency_firewall_activity_stat,
      dependency_firewall_policy_rule: rule, project: project, outcome: :blocked, count: 5)

    baseline = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

    extra_rule = create(:dependency_firewall_policy_rule, security_policy: policy)
    create(:dependency_firewall_activity_stat,
      dependency_firewall_policy_rule: extra_rule, project: project, outcome: :warned, count: 2)

    expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(baseline)
  end

  context 'when the dependency_firewall_phase1 feature flag is disabled' do
    before do
      stub_feature_flags(dependency_firewall_phase1: false)
    end

    it { is_expected.to eq([]) }
  end

  context 'when the dependency_firewall licensed feature is unavailable' do
    before do
      stub_licensed_features(security_orchestration_policies: true, dependency_firewall: false)
    end

    it { is_expected.to eq([]) }
  end

  context 'when the user cannot read security orchestration policies' do
    let(:current_user) { create(:user) }

    it { is_expected.to be_nil }
  end

  describe 'dependencyFirewallActivitySummary' do
    let(:summary_query) do
      graphql_query_for(
        :group, { full_path: group.full_path },
        query_graphql_field(:dependency_firewall_activity_summary, {},
          'blocked warned allowed totalTriggers activeRules blockingRules warningRules')
      )
    end

    before do
      create(:dependency_firewall_activity_stat,
        dependency_firewall_policy_rule: rule, project: project, outcome: :blocked, count: 3)
      create(:dependency_firewall_activity_stat,
        dependency_firewall_policy_rule: rule, project: project, outcome: :warned, count: 2)
      create(:dependency_firewall_activity_stat,
        dependency_firewall_policy_rule: nil, project: project, outcome: :allowed, count: 95)
    end

    it 'returns server-side outcome totals and the summed total triggers' do
      post_graphql(summary_query, current_user: current_user)
      summary = graphql_data_at(:group, :dependency_firewall_activity_summary)

      expect(summary).to eq(
        'blocked' => 3, 'warned' => 2, 'allowed' => 95, 'totalTriggers' => 100,
        'activeRules' => 1, 'blockingRules' => 1, 'warningRules' => 0
      )
    end

    context 'with an additional disabled policy' do
      let_it_be(:disabled_policy) do
        create(:security_policy, :dependency_firewall_policy,
          security_orchestration_policy_configuration: configuration,
          name: 'Disabled Policy', enabled: false, policy_index: 1)
      end

      let_it_be(:disabled_rule) { create(:dependency_firewall_policy_rule, security_policy: disabled_policy) }

      it 'counts only enabled rules as active' do
        post_graphql(summary_query, current_user: current_user)
        summary = graphql_data_at(:group, :dependency_firewall_activity_summary)

        expect(summary['activeRules']).to eq(1)
      end
    end

    context 'when the feature is unavailable (feature flag disabled)' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'returns a zeroed summary' do
        post_graphql(summary_query, current_user: current_user)

        expect(graphql_data_at(:group, :dependency_firewall_activity_summary)).to eq(
          'blocked' => 0, 'warned' => 0, 'allowed' => 0, 'totalTriggers' => 0,
          'activeRules' => 0, 'blockingRules' => 0, 'warningRules' => 0
        )
      end
    end
  end
end
