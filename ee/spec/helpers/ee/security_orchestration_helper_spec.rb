# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::SecurityOrchestrationHelper, feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project, group: create(:group)) }
  let_it_be_with_refind(:namespace) { create(:group, :public, owners: [create(:user)]) }
  let_it_be(:timezones) { [{ identifier: "Europe/Paris" }] }

  let(:policy_file_path) { '.gitlab/security-policies/policy.yml' }

  describe '#can_update_security_orchestration_policy_project?' do
    let(:owner) { project.first_owner }

    before do
      allow(helper).to receive(:current_user) { owner }
    end

    it 'returns false when user cannot update security orchestration policy project' do
      allow(helper).to receive(:can?).with(owner, :update_security_orchestration_policy_project,
        project).and_return(false)
      expect(helper.can_update_security_orchestration_policy_project?(project)).to be false
    end

    context 'when user can update security orchestration policy project' do
      it 'returns true for project' do
        allow(helper).to receive(:can?).with(owner, :update_security_orchestration_policy_project,
          project).and_return(true)
        expect(helper.can_update_security_orchestration_policy_project?(project)).to be true
      end

      context 'for namespace' do
        before do
          allow(helper).to receive(:can?).with(owner, :update_security_orchestration_policy_project,
            namespace).and_return(true)
        end

        it 'returns true' do
          expect(helper.can_update_security_orchestration_policy_project?(namespace)).to be true
        end

        it 'returns false when designated as CSP' do
          allow(namespace).to receive(:designated_as_csp?).and_return(true)
          expect(helper.can_update_security_orchestration_policy_project?(namespace)).to be false
        end
      end
    end
  end

  describe '#assigned_policy_project' do
    context 'for project' do
      subject { helper.assigned_policy_project(project) }

      context 'when a project does have a security policy project' do
        let_it_be(:policy_management_project) { create(:project) }

        let_it_be(:security_orchestration_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            security_policy_management_project: policy_management_project, project: project
          )
        end

        let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [build(:scan_execution_policy)]) }

        before do
          allow_next_instance_of(Repository) do |repository|
            allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
          end
        end

        context 'when policy.yml file is missing' do
          let(:policy_yaml) { nil }

          it 'includes policy_yaml_missing as true and policy_yaml_has_syntax_errors as false' do
            is_expected.to include(
              id: policy_management_project.to_global_id.to_s,
              name: policy_management_project.name,
              full_path: policy_management_project.full_path,
              branch: policy_management_project.default_branch_or_main,
              policy_yaml_has_syntax_errors: 'false',
              policy_yaml_missing: 'true',
              policy_yaml_path: "/#{policy_management_project.full_path}/-/blob/main/#{policy_file_path}"
            )
          end
        end

        context 'when policy.yml file is invalid' do
          before do
            allow(Security::OrchestrationPolicyConfiguration::POLICY_SCHEMA).to receive(:valid?).and_return(false)
          end

          it 'include information about policy management project and policy yaml status' do
            is_expected.to include(
              id: policy_management_project.to_global_id.to_s,
              name: policy_management_project.name,
              full_path: policy_management_project.full_path,
              branch: policy_management_project.default_branch_or_main,
              policy_yaml_has_syntax_errors: 'true',
              policy_yaml_missing: 'false',
              policy_yaml_path: "/#{policy_management_project.full_path}/-/blob/main/#{policy_file_path}"
            )
          end
        end

        context 'when policy.yml file is valid' do
          before do
            allow(Security::OrchestrationPolicyConfiguration::POLICY_SCHEMA).to receive(:valid?).and_return(true)
          end

          it 'includes policy_yaml_has_syntax_errors as false and policy_yaml_missing as false' do
            is_expected.to include(
              id: policy_management_project.to_global_id.to_s,
              name: policy_management_project.name,
              full_path: policy_management_project.full_path,
              branch: policy_management_project.default_branch_or_main,
              policy_yaml_has_syntax_errors: 'false',
              policy_yaml_missing: 'false',
              policy_yaml_path: "/#{policy_management_project.full_path}/-/blob/main/#{policy_file_path}"
            )
          end
        end
      end

      context 'when a project does not have a security policy project' do
        subject { helper.assigned_policy_project(project) }

        it { is_expected.to be_nil }
      end
    end

    context 'for namespace' do
      subject { helper.assigned_policy_project(project) }

      context 'when a namespace does have a security policy project' do
        let_it_be(:policy_management_project) { create(:project) }
        let_it_be(:security_orchestration_policy_configuration) do
          create(
            :security_orchestration_policy_configuration, :namespace,
            security_policy_management_project: policy_management_project, namespace: namespace
          )
        end

        subject { helper.assigned_policy_project(namespace) }

        it 'include information about policy management project' do
          is_expected.to include({
            id: policy_management_project.to_global_id.to_s,
            name: policy_management_project.name,
            full_path: policy_management_project.full_path,
            branch: policy_management_project.default_branch_or_main,
            policy_yaml_has_syntax_errors: 'false',
            policy_yaml_missing: 'true',
            policy_yaml_path: "/#{policy_management_project.full_path}/-/blob/main/#{policy_file_path}"
          })
        end
      end

      context 'when a namespace does not have a security policy project' do
        it { is_expected.to be_nil }
      end
    end
  end

  describe '#breadcrumb_by_type' do
    let_it_be(:policy_type) { 'approval_policy' }

    subject { helper.breadcrumb_by_type(policy_type) }

    context 'when merge request approval policy' do
      it 'returns correct breadcrumb type' do
        is_expected.to eq('New merge request approval policy')
      end
    end

    context 'when scan execution policy' do
      let_it_be(:policy_type) { 'scan_execution_policy' }

      it 'returns correct breadcrumb type' do
        is_expected.to eq('New scan execution policy')
      end
    end

    context 'when pipeline execution policy' do
      let_it_be(:policy_type) { 'pipeline_execution_policy' }

      it 'returns correct breadcrumb type' do
        is_expected.to eq('New pipeline execution policy')
      end
    end

    context 'when policy type does not exist' do
      let_it_be(:policy_type) { 'wrong type' }

      it 'returns correct breadcrumb type' do
        is_expected.to eq('New policy')
      end
    end
  end

  describe '#orchestration_policy_data' do
    shared_examples_for 'loads software_licenses names' do
      context 'for software_licenses' do
        it 'gets the license names from ::Gitlab::SPDX::Catalogue' do
          expect(::Gitlab::SPDX::Catalogue).to receive(:latest_active_license_names)

          orchestration_policy_data
        end
      end
    end

    context 'for project' do
      let(:owner) { project.first_owner }
      let(:policy) { nil }
      let(:policy_type) { 'scan_execution_policy' }
      let(:base_data) do
        {
          assigned_policy_project: nil.to_json,
          disable_scan_policy_update: 'false',
          namespace_id: project.id,
          namespace_path: kind_of(String),
          designated_as_csp: 'false',
          policy_editor_empty_state_svg_path: kind_of(String),
          policies_path: kind_of(String),
          policy: policy&.to_json,
          policy_type: policy_type,
          role_approver_types: %w[developer maintainer owner],
          scan_policy_documentation_path: kind_of(String),
          software_licenses: kind_of(Array),
          global_group_approvers_enabled:
            Gitlab::CurrentSettings.security_policy_global_group_approvers_enabled.to_json,
          root_namespace_path: project.root_ancestor.full_path,
          timezones: timezones.to_json,
          max_active_scan_execution_policies_reached: 'false',
          max_active_pipeline_execution_policies_reached: 'false',
          max_active_scan_result_policies_reached: 'false',
          max_scan_result_policies_allowed: Gitlab::CurrentSettings.security_approval_policies_limit,
          max_scan_execution_policies_allowed: 5,
          max_pipeline_execution_policies_allowed:
            Gitlab::CurrentSettings.pipeline_execution_policies_per_configuration_limit,
          max_vulnerability_management_policies_allowed: 5,
          max_active_vulnerability_management_policies_reached: 'false',
          max_scan_execution_policy_actions: Gitlab::CurrentSettings.scan_execution_policies_action_limit,
          max_scan_execution_policy_schedules: Gitlab::CurrentSettings.scan_execution_policies_schedule_limit,
          enabled_experiments: [],
          access_tokens: [].to_json,
          policy_editor_enabled: 'false'
        }
      end

      before do
        allow(helper).to receive(:timezone_data).with(format: :full).and_return(timezones)
        allow(helper).to receive(:current_user) { owner }
        # When no policy config exists, create_security_policy is checked
        allow(helper).to receive(:can?).with(owner, :create_security_policy, project).and_return(true)
      end

      subject(:orchestration_policy_data) { helper.orchestration_policy_data(project, policy_type, policy) }

      context 'when a new policy is being created' do
        let(:policy) { nil }
        let(:policy_type) { nil }

        it { is_expected.to match(base_data) }
      end

      context 'when an existing policy is being edited' do
        let(:policy) { build(:scan_execution_policy, name: 'Run DAST in every pipeline') }

        it { is_expected.to match(base_data) }
      end

      context 'when scan policy update is disabled' do
        before do
          allow(helper).to receive(:can?).with(owner, :create_security_policy, project).and_return(false)
        end

        it { is_expected.to match(base_data.merge(disable_scan_policy_update: 'true')) }
      end

      context 'when a project does have a security policy project' do
        let_it_be(:policy_management_project) { create(:project) }

        let_it_be(:security_orchestration_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            security_policy_management_project: policy_management_project, project: project
          )
        end

        before do
          # When policy config exists, modify_security_policy is checked
          allow(helper).to receive(:can?).with(owner, :modify_security_policy, project).and_return(true)
        end

        it 'include information about policy management project' do
          is_expected.to match(base_data.merge(assigned_policy_project: {
            id: policy_management_project.to_global_id.to_s,
            name: policy_management_project.name,
            full_path: policy_management_project.full_path,
            branch: policy_management_project.default_branch_or_main,
            policy_yaml_has_syntax_errors: 'false',
            policy_yaml_missing: 'true',
            policy_yaml_path: "/#{policy_management_project.full_path}/-/blob/main/#{policy_file_path}"
          }.to_json))
        end
      end

      it_behaves_like 'loads software_licenses names'
    end

    context 'for namespace' do
      let(:owner) { namespace.first_owner }
      let(:policy) { nil }
      let(:policy_type) { 'scan_execution_policy' }
      let(:base_data) do
        {
          assigned_policy_project: nil.to_json,
          disable_scan_policy_update: 'false',
          policy: policy&.to_json,
          policy_editor_empty_state_svg_path: kind_of(String),
          policy_type: policy_type,
          policies_path: kind_of(String),
          role_approver_types: %w[developer maintainer owner],
          scan_policy_documentation_path: kind_of(String),
          namespace_path: namespace.full_path,
          namespace_id: namespace.id,
          designated_as_csp: 'false',
          software_licenses: kind_of(Array),
          global_group_approvers_enabled:
            Gitlab::CurrentSettings.security_policy_global_group_approvers_enabled.to_json,
          root_namespace_path: namespace.root_ancestor.full_path,
          timezones: timezones.to_json,
          max_active_scan_execution_policies_reached: 'false',
          max_active_pipeline_execution_policies_reached: 'false',
          max_active_scan_result_policies_reached: 'false',
          max_scan_result_policies_allowed: Gitlab::CurrentSettings.security_approval_policies_limit,
          max_scan_execution_policies_allowed: 5,
          max_pipeline_execution_policies_allowed:
            Gitlab::CurrentSettings.pipeline_execution_policies_per_configuration_limit,
          max_vulnerability_management_policies_allowed: 5,
          max_active_vulnerability_management_policies_reached: 'false',
          max_scan_execution_policy_actions: Gitlab::CurrentSettings.scan_execution_policies_action_limit,
          max_scan_execution_policy_schedules: Gitlab::CurrentSettings.scan_execution_policies_schedule_limit,
          enabled_experiments: [],
          access_tokens: [].to_json,
          policy_editor_enabled: 'false'
        }
      end

      before do
        allow(helper).to receive(:timezone_data).with(format: :full).and_return(timezones)
        allow(helper).to receive(:current_user) { owner }
        # When no policy config exists, create_security_policy is checked
        allow(helper).to receive(:can?).with(owner, :create_security_policy, namespace).and_return(true)
      end

      subject(:orchestration_policy_data) do
        helper.orchestration_policy_data(namespace, policy_type, policy)
      end

      context 'when a new policy is being created' do
        let(:policy) { nil }
        let(:policy_type) { nil }

        it { is_expected.to match(base_data) }
      end

      context 'when policy editor is enabled' do
        before do
          create(:user_preference, user: owner, policy_advanced_editor: true)
        end

        it { is_expected.to match(base_data.merge(policy_editor_enabled: 'true')) }
      end

      context 'when an existing policy is being edited' do
        let(:policy_type) { 'scan_execution_policy' }

        let(:policy) do
          build(:scan_execution_policy, name: 'Run DAST in every pipeline')
        end

        it { is_expected.to match(base_data) }
      end

      context 'when scan policy update is disabled' do
        before do
          allow(helper).to receive(:can?)
            .with(owner, :create_security_policy, namespace)
            .and_return(false)
        end

        it { is_expected.to match(base_data.merge(disable_scan_policy_update: 'true')) }
      end

      context 'when a namespace does have a security policy project' do
        let_it_be(:policy_management_project) { create(:project) }

        let_it_be(:security_orchestration_policy_configuration) do
          create(
            :security_orchestration_policy_configuration, :namespace,
            security_policy_management_project: policy_management_project, namespace: namespace
          )
        end

        before do
          # When policy config exists, modify_security_policy is checked
          allow(helper).to receive(:can?).with(owner, :modify_security_policy, namespace).and_return(true)
        end

        it 'include information about policy management project' do
          is_expected.to match(base_data.merge(assigned_policy_project: {
            id: policy_management_project.to_global_id.to_s,
            name: policy_management_project.name,
            full_path: policy_management_project.full_path,
            branch: policy_management_project.default_branch_or_main,
            policy_yaml_has_syntax_errors: 'false',
            policy_yaml_missing: 'true',
            policy_yaml_path: "/#{policy_management_project.full_path}/-/blob/main/#{policy_file_path}"
          }.to_json))
        end
      end

      it_behaves_like 'loads software_licenses names'

      context 'when the namespace is designated as CSP' do
        include Security::PolicyCspHelpers

        before do
          stub_csp_group(namespace)
        end

        it { is_expected.to match(base_data.merge(designated_as_csp: 'true')) }
      end
    end
  end

  shared_examples 'when source does not have a security policy project' do
    it { is_expected.to be_falsey }
  end

  shared_examples 'when source has active scan policies' do |limit_reached: false|
    before do
      allow_next_instance_of(Repository) do |repository|
        allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      end
    end

    it 'returns if max active scan policies limit was reached' do
      is_expected.to eq(limit_reached)
    end
  end

  shared_examples '#max_active_scan_execution_policies_reached for source' do
    context 'when a source does not have a security policy project' do
      it_behaves_like 'when source does not have a security policy project'
    end

    context 'when a source did not reach the limit of active scan execution policies' do
      it_behaves_like 'when source has active scan policies'
    end

    context 'when a source reached the limit of active scan execution policies' do
      before do
        allow_next_instance_of(Security::SecurityOrchestrationPolicies::LimitService) do |service|
          allow(service).to receive(:scan_execution_policies_per_configuration_limit).and_return(1)
        end
      end

      it_behaves_like 'when source has active scan policies', limit_reached: true
    end
  end

  describe '#max_active_scan_execution_policies_reached?' do
    let_it_be(:policy_management_project) { create(:project, :repository) }

    let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [build(:scan_execution_policy)]) }

    context 'for project' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: project
        )
      end

      subject { helper.max_active_scan_execution_policies_reached?(project) }

      it_behaves_like '#max_active_scan_execution_policies_reached for source'
    end

    context 'for namespace' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration, :namespace,
          security_policy_management_project: policy_management_project, namespace: namespace
        )
      end

      subject { helper.max_active_scan_execution_policies_reached?(namespace) }

      it_behaves_like '#max_active_scan_execution_policies_reached for source'
    end
  end

  shared_examples '#max_active_vulnerability_management_policies_reached for source' do
    context 'when a source does not have a security policy project' do
      it_behaves_like 'when source does not have a security policy project'
    end

    context 'when a source did not reach the limit of active vulnerability management policies' do
      it_behaves_like 'when source has active scan policies', limit_reached: false
    end

    context 'when a source reached the limit of active vulnerability management policies' do
      before do
        allow_next_instance_of(Security::SecurityOrchestrationPolicies::LimitService) do |service|
          allow(service).to receive(:vulnerability_management_policies_per_configuration_limit).and_return(1)
        end
      end

      it_behaves_like 'when source has active scan policies', limit_reached: true
    end
  end

  describe '#max_active_vulnerability_management_policies_reached?' do
    let_it_be(:policy_management_project) { create(:project, :repository) }

    let(:policy_yaml) do
      build(:orchestration_policy_yaml, vulnerability_management_policy: [build(:vulnerability_management_policy)])
    end

    context 'for project' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: project
        )
      end

      subject { helper.max_active_vulnerability_management_policies_reached?(project) }

      it_behaves_like '#max_active_vulnerability_management_policies_reached for source'
    end

    context 'for namespace' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration, :namespace,
          security_policy_management_project: policy_management_project, namespace: namespace
        )
      end

      subject { helper.max_active_vulnerability_management_policies_reached?(namespace) }

      it_behaves_like '#max_active_vulnerability_management_policies_reached for source'
    end
  end

  shared_examples '#max_active_pipeline_execution_policies_reached for source' do
    context 'when a source does not have a security policy project' do
      it_behaves_like 'when source does not have a security policy project'
    end

    context 'when a source did not reach the limit of active pipeline execution policies' do
      it_behaves_like 'when source has active scan policies', limit_reached: false
    end

    context 'when a source reached the limit of active pipeline execution policies' do
      before do
        allow_next_instance_of(Security::SecurityOrchestrationPolicies::LimitService) do |service|
          allow(service).to receive(:pipeline_execution_policies_per_configuration_limit).and_return(1)
        end
      end

      it_behaves_like 'when source has active scan policies', limit_reached: true
    end
  end

  describe '#max_active_pipeline_execution_policies_reached?' do
    let_it_be(:policy_management_project) { create(:project, :repository) }

    let(:policy_yaml) do
      build(:orchestration_policy_yaml, pipeline_execution_policy: [build(:pipeline_execution_policy)])
    end

    context 'for project' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: project
        )
      end

      subject { helper.max_active_pipeline_execution_policies_reached?(project) }

      it_behaves_like '#max_active_pipeline_execution_policies_reached for source'
    end

    context 'for namespace' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration, :namespace,
          security_policy_management_project: policy_management_project, namespace: namespace
        )
      end

      subject { helper.max_active_pipeline_execution_policies_reached?(namespace) }

      it_behaves_like '#max_active_pipeline_execution_policies_reached for source'
    end
  end

  shared_examples '#max_active_scan_result_policies_reached for source' do
    context 'when a source does not have a security policy project' do
      it_behaves_like 'when source does not have a security policy project'
    end

    context 'when a source did not reach the limit of active scan result policies' do
      it_behaves_like 'when source has active scan policies'
    end

    context 'when a source reached the limit of active scan result policies' do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:security_approval_policies_limit).and_return(1)
      end

      it_behaves_like 'when source has active scan policies', limit_reached: true
    end
  end

  describe '#max_active_scan_result_policies_reached?' do
    let_it_be(:policy_management_project) { create(:project, :repository) }

    let(:policy_yaml) { build(:orchestration_policy_yaml, approval_policy: [build(:approval_policy)]) }

    context 'for project' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: project
        )
      end

      subject { helper.max_active_scan_result_policies_reached?(project) }

      it_behaves_like '#max_active_scan_result_policies_reached for source'
    end

    context 'for namespace' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration, :namespace,
          security_policy_management_project: policy_management_project, namespace: namespace
        )
      end

      subject { helper.max_active_scan_result_policies_reached?(namespace) }

      it_behaves_like '#max_active_scan_result_policies_reached for source'
    end
  end

  describe '#security_configurations_preventing_project_deletion' do
    let_it_be(:project) { create(:project) }

    subject(:preventing_configurations) { helper.security_configurations_preventing_project_deletion(project) }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    context 'when there are no preventing configurations' do
      it 'is an empty relation' do
        expect(preventing_configurations).to be_empty
      end
    end

    context 'when there are preventing configurations' do
      let_it_be(:config) do
        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
      end

      it 'returns the preventing configurations' do
        expect(preventing_configurations).to contain_exactly(config)
      end

      context 'when security orchestration policies are not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'is an empty relation' do
          expect(preventing_configurations).to be_empty
        end
      end
    end
  end

  describe '#policy_configurations_within_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let(:feature_licensed) { true }

    subject(:preventing_configurations) { helper.policy_configurations_within_group(group) }

    before do
      stub_licensed_features(security_orchestration_policies: feature_licensed)
    end

    context 'when security orchestration policies are not available' do
      let(:feature_licensed) { false }

      it 'is an empty relation' do
        expect(preventing_configurations).to be_empty
      end
    end

    context 'when there are no preventing configurations' do
      it 'is an empty relation' do
        expect(preventing_configurations).to be_empty
      end
    end

    context 'when there are preventing configurations' do
      let!(:config) do
        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
      end

      it 'returns the preventing configurations' do
        expect(preventing_configurations).to contain_exactly(config)
      end
    end
  end

  describe '#security_configurations_preventing_group_deletion' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let(:feature_licensed) { true }

    subject(:result) { helper.security_configurations_preventing_group_deletion(group) }

    before do
      stub_licensed_features(security_orchestration_policies: feature_licensed)
      stub_const("#{described_class}::GROUP_DELETION_CONFIGURATIONS_LIMIT", 2)
    end

    context 'when security orchestration policies are not available' do
      let(:feature_licensed) { false }

      it 'returns empty configurations and no more records' do
        expect(result[:limited_configurations]).to be_empty
        expect(result[:has_more]).to be false
      end
    end

    context 'when there are no preventing configurations' do
      it 'returns empty configurations and no more records' do
        expect(result[:limited_configurations]).to be_empty
        expect(result[:has_more]).to be false
      end
    end

    context 'when there are preventing configurations' do
      let!(:config) do
        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
      end

      it 'returns limited configurations and no more records' do
        expect(result[:limited_configurations]).to contain_exactly(config)
        expect(result[:has_more]).to be false
      end

      context 'when there are more than the limit configurations' do
        before do
          create_list(:security_orchestration_policy_configuration, 3, security_policy_management_project: project)
        end

        it 'limits configurations to the mocked limit and indicates more records exist' do
          expect(result[:limited_configurations].count).to eq(2)
          expect(result[:has_more]).to be true
        end
      end
    end
  end

  describe '#access_tokens_for_container' do
    let_it_be(:policy_management_project) { create(:project) }

    subject(:access_tokens) { helper.access_tokens_for_container(container) }

    shared_examples 'without policy configuration' do
      context 'when container has no security orchestration policy configuration' do
        it 'returns empty array' do
          expect(access_tokens).to be_empty
        end
      end
    end

    shared_examples 'with policy configuration' do
      let_it_be_with_reload(:bot_user1) { create(:user, :project_bot) }
      let_it_be_with_reload(:bot_user2) { create(:user, :project_bot) }
      let_it_be(:regular_user) { create(:user) }

      let_it_be_with_refind(:bot_token1) { create(:personal_access_token, user: bot_user1, name: 'Bot Token 1') }
      let_it_be_with_refind(:bot_token2) { create(:personal_access_token, user: bot_user2, name: 'Bot Token 2') }
      let_it_be(:regular_token) { create(:personal_access_token, user: regular_user, name: 'Regular Token') }
      let_it_be(:impersonation_token) do
        create(:personal_access_token, :impersonation, user: bot_user1, name: 'Impersonation Token')
      end

      context 'when there are bot users with access tokens' do
        before do
          setup_bot_users
        end

        it 'returns access tokens for bot users only' do
          expect(access_tokens).to contain_exactly(
            { id: bot_token1.id, name: 'Bot Token 1' },
            { id: bot_token2.id, name: 'Bot Token 2' }
          )
        end

        it 'excludes impersonation tokens' do
          expect(access_tokens).not_to include({ id: impersonation_token.id, name: 'Impersonation Token' })
        end

        it 'excludes tokens from regular users' do
          expect(access_tokens).not_to include({ id: regular_token.id, name: 'Regular Token' })
        end
      end

      context 'when bot users have no access tokens' do
        before do
          PersonalAccessToken.where(user: [bot_user1, bot_user2]).delete_all
        end

        it 'returns empty array' do
          expect(access_tokens).to be_empty
        end
      end

      context 'when there are no bot users' do
        before do
          remove_bot_users
        end

        it 'returns empty array' do
          expect(access_tokens).to be_empty
        end
      end
    end

    context 'for project container' do
      let_it_be(:container) { create(:project) }
      let_it_be(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: container, namespace: nil
        )
      end

      def setup_bot_users
        container.add_maintainer(bot_user1)
        container.add_maintainer(bot_user2)
      end

      def remove_bot_users
        container.project_members.where(user: [bot_user1, bot_user2]).delete_all
      end

      it_behaves_like 'without policy configuration'
      it_behaves_like 'with policy configuration'
    end

    context 'for namespace container' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:container) { create(:group, parent: root_group) }
      let_it_be(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, namespace: container, project: nil
        )
      end

      def setup_bot_users
        bot_user1.user_detail.update!(bot_namespace: container)
        bot_user2.user_detail.update!(bot_namespace: root_group)
        container.add_maintainer(bot_user1)
        root_group.add_maintainer(bot_user2)
      end

      def remove_bot_users
        container.group_members.where(user: [bot_user1, bot_user2]).delete_all
        root_group.group_members.where(user: [bot_user1, bot_user2]).delete_all
      end

      it_behaves_like 'without policy configuration'
      it_behaves_like 'with policy configuration'
    end
  end
end
