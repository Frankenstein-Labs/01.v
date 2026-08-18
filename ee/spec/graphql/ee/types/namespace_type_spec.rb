# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Namespace'], feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }

  it 'has specific fields' do
    expected_fields = %w[
      add_on_eligible_users
      additional_purchased_storage_size
      total_repository_size_excess
      total_repository_size
      contains_locked_projects
      repository_size_excess_project_count
      actual_repository_size_limit
      actual_size_limit
      storage_size_limit
      compliance_frameworks
      security_policies
      pipeline_execution_policies
      pipeline_execution_schedule_policies
      scan_execution_policies
      approval_policies
      vulnerability_management_policies
      security_policy_project
      product_analytics_stored_events_limit
      subscription_history
      custom_fields
      statuses
      licensed_feature_availability
      lifecycle_templates
      plan
      aiSettings
      aiDomainSettings
      workItemSettings
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'Storage related fields' do
    let_it_be(:group) do
      create(:group, additional_purchased_storage_size: 100, repository_size_limit: 10_240)
    end

    let_it_be(:group_member) { create(:group_member, group: group, user: user) }
    let_it_be(:query) do
      %(
        query {
          namespace(fullPath: "#{group.full_path}") {
            additionalPurchasedStorageSize
            containsLockedProjects
            actualRepositorySizeLimit
          }
        }
      )
    end

    subject(:storage_related_query) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    it "returns the expected values for customized fields defined in NamespaceType" do
      namespace = storage_related_query.dig('data', 'namespace')

      expect(namespace['additionalPurchasedStorageSize']).to eq(100.megabytes)
      expect(namespace['containsLockedProjects']).to be false
      expect(namespace['actualRepositorySizeLimit']).to eq(10_240)
    end
  end

  describe 'fields with :ai_workflows scope' do
    it 'includes :ai_workflows scope for the aiSettings field' do
      field = described_class.fields['aiSettings']
      expect(field.instance_variable_get(:@scopes)).to include(:ai_workflows)
    end

    it 'includes :ai_workflows scope for the lifecycles field' do
      field = described_class.fields['lifecycles']
      expect(field.instance_variable_get(:@scopes)).to include(:ai_workflows)
    end
  end

  describe 'Security Policies', feature_category: :security_policy_management do
    let_it_be(:security_policy_management_project) { create(:project) }
    let_it_be(:group) { create(:group) }
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: group,
        security_policy_management_project: security_policy_management_project)
    end

    let(:policy_yaml) do
      Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration.yml', dir: 'ee')).load!
    end

    let(:response) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before_all do
      policy_configuration.security_policy_management_project.add_maintainer(user)
    end

    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |policy|
        allow(policy).to receive_messages(
          policy_configuration_valid?: true, policy_hash: policy_yaml, policy_last_updated_at: Time.now
        )
      end

      stub_licensed_features(security_orchestration_policies: true)
    end

    describe 'designatedAsCsp' do
      include Security::PolicyCspHelpers

      let(:query) do
        %(
        query {
          namespace(fullPath: "#{group.full_path}") {
            designatedAsCsp
          }
        }
      )
      end

      subject(:csp) { response.dig('data', 'namespace', 'designatedAsCsp') }

      it { is_expected.to be(false) }

      context 'when the group is designated as a CSP' do
        before do
          stub_csp_group(group)
        end

        it { is_expected.to be(true) }
      end
    end
  end
end
