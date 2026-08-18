# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project.dependencyFirewallRuleActivity', feature_category: :dependency_firewall do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, group: group, developers: user) }
  let_it_be(:configuration) do
    create(:security_orchestration_policy_configuration, :namespace, namespace: group)
  end

  let_it_be(:policy) do
    create(:security_policy, :dependency_firewall_policy,
      security_orchestration_policy_configuration: configuration, name: 'Block GPL')
  end

  let_it_be(:rule) { create(:dependency_firewall_policy_rule, security_policy: policy) }

  let(:fields) do
    'policyName enabled blockedCount lastModified { at } ' \
      'source { ... on GroupSecurityPolicySource { inherited namespace { id name } } }'
  end

  let(:query) do
    graphql_query_for(
      :project, { full_path: project.full_path },
      query_graphql_field(:dependency_firewall_rule_activity, {}, fields)
    )
  end

  let(:current_user) { user }

  subject(:activity) do
    post_graphql(query, current_user: current_user)
    graphql_data_at(:project, :dependency_firewall_rule_activity)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true, dependency_firewall: true)
  end

  it 'returns the rule with activity recorded for the project, inherited from the group' do
    create(:dependency_firewall_activity_stat,
      dependency_firewall_policy_rule: rule, project: project, outcome: :blocked, count: 7)

    expect(activity).to contain_exactly(
      a_hash_including(
        'policyName' => 'Block GPL',
        'blockedCount' => 7,
        'source' => a_hash_including(
          'inherited' => true,
          'namespace' => a_hash_including('name' => group.name)
        )
      )
    )
  end

  it 'excludes activity recorded against projects other than this one' do
    other_project = create(:project, group: group)
    create(:dependency_firewall_activity_stat,
      dependency_firewall_policy_rule: rule, project: other_project, outcome: :blocked, count: 99)

    expect(activity.first['blockedCount']).to eq(0)
  end

  it 'exposes the policy last-modified timestamp' do
    expect(activity.first.dig('lastModified', 'at')).to be_present
  end

  context 'with a disabled policy inherited from the group' do
    let_it_be(:disabled_policy) do
      create(:security_policy, :dependency_firewall_policy,
        security_orchestration_policy_configuration: configuration,
        name: 'Disabled Policy', enabled: false, policy_index: 1)
    end

    let_it_be(:disabled_rule) { create(:dependency_firewall_policy_rule, security_policy: disabled_policy) }

    it 'lists the disabled rule flagged as disabled', :aggregate_failures do
      by_name = activity.index_by { |item| item['policyName'] }

      expect(by_name['Disabled Policy']['enabled']).to be(false)
      expect(by_name['Block GPL']['enabled']).to be(true)
    end
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
end
