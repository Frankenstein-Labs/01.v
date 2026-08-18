# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.vulnerabilities.policyAutoDismissed', feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, security_dashboard_projects: [project], developer_of: [project]) }
  let_it_be(:security_policy_bot) { create(:user, :security_policy_bot, guest_of: [project]) }
  let_it_be_with_reload(:vulnerability) { create(:vulnerability, :with_finding, project: project) }

  let_it_be(:fields) do
    <<~QUERY
      policyAutoDismissed
    QUERY
  end

  let_it_be(:query) do
    graphql_query_for('vulnerabilities', {}, query_graphql_field('nodes', {}, fields))
  end

  subject(:policy_auto_dismissed) { graphql_data.dig('vulnerabilities', 'nodes').first['policyAutoDismissed'] }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  it 'returns false for vulnerabilitites not dismissed by policy' do
    post_graphql(query, current_user: user)

    expect(policy_auto_dismissed).to be false
  end

  context 'when the vulnerability was automatically dismissed by a policy' do
    it 'returns true for vulnerabilitites dismissed by policy' do
      vulnerability.update!(state: :dismissed, dismissed_by: security_policy_bot)

      post_graphql(query, current_user: user)
      expect(policy_auto_dismissed).to be true
    end
  end
end
