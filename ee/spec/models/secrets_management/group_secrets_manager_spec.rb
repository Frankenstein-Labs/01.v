# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }

  subject(:secrets_manager) { create(:group_secrets_manager, group: group) }

  it { is_expected.to belong_to(:group) }

  it { is_expected.to validate_presence_of(:group) }

  it_behaves_like 'a secrets manager'

  describe '#pending_deprovision_task?' do
    it 'delegates to GroupSecretsManagerMaintenanceTask.deprovision_pending_for?' do
      expect(SecretsManagement::GroupSecretsManagerMaintenanceTask)
        .to receive(:deprovision_pending_for?).with(secrets_manager.group_id).and_return(true)

      expect(secrets_manager.pending_deprovision_task?).to be(true)
    end
  end

  describe '#effective_status' do
    it 'returns the underlying status when no deprovision task is pending' do
      expect(secrets_manager.effective_status).to eq(secrets_manager.status)
    end

    it 'returns DEPROVISIONING when a deprovision task is pending, regardless of underlying status' do
      secrets_manager.update!(status: described_class::STATUSES[:active])
      create(:group_secrets_manager_maintenance_task, :deprovision, group: group)

      expect(secrets_manager.effective_status).to eq(described_class::STATUSES[:deprovisioning])
    end
  end

  describe '#pipeline_auth_cel_program' do
    let(:group_id) { group.id.to_s }

    subject(:program) { secrets_manager.pipeline_auth_cel_program(group_id) }

    it 'includes unprotected_global_policy variable set when protection_level is protected' do
      unprotected_global = program[:variables].find { |v| v[:name] == 'unprotected_global_policy' }

      expect(unprotected_global[:expression])
        .to eq('protection_level == "protected" ? "pipelines/combined/unprotected/global" : ""')
    end

    it 'includes unprotected_env_policy variable set when protection_level is protected and environment present' do
      unprotected_env = program[:variables].find { |v| v[:name] == 'unprotected_env_policy' }

      expected = 'protection_level == "protected" && environment != "" ? ' \
        '"pipelines/combined/unprotected/env/" + env_hex : ""'
      expect(unprotected_env[:expression]).to eq(expected)
    end

    it 'grants unprotected policies alongside protected policies in the CEL expression' do
      expect(program[:expression]).to include('unprotected_global_policy')
      expect(program[:expression]).to include('unprotected_env_policy')
    end
  end

  describe '#ci_policy_name_for_environment' do
    it 'returns protected environment-based policy for non-wildcard environments' do
      environment = 'production'

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: true))
        .to eq("pipelines/combined/protected/env/#{environment.unpack1('H*')}")
    end

    it 'returns unprotected environment-based policy for non-wildcard environments' do
      environment = 'production'

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: false))
        .to eq("pipelines/combined/unprotected/env/#{environment.unpack1('H*')}")
    end

    it 'returns protected global policy for wildcard environment' do
      environment = '*'

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: true))
        .to eq("pipelines/combined/protected/global")
    end

    it 'returns unprotected global policy for wildcard environment' do
      environment = '*'

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: false))
        .to eq("pipelines/combined/unprotected/global")
    end

    it 'handles special characters in environment names' do
      environment = 'staging/us-east-1'
      hex_env = environment.unpack1('H*')

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: true))
        .to eq("pipelines/combined/protected/env/#{hex_env}")
    end
  end

  describe '#org_path' do
    it 'returns org_<organization_id>' do
      expect(secrets_manager.org_path).to eq("org_#{group.organization_id}")
    end
  end

  describe '#root_namespace_path' do
    it 'returns group_<root_namespace_id> for a root group' do
      expect(secrets_manager.root_namespace_path).to eq("group_#{group.id}")
    end

    context 'for a deeply nested group' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup_a) { create(:group, parent: root_group) }
      let_it_be(:subgroup_b) { create(:group, parent: subgroup_a) }

      subject(:secrets_manager) { create(:group_secrets_manager, group: subgroup_b) }

      it 'uses the root ancestor id, not the immediate parent' do
        expect(secrets_manager.root_namespace_path).to eq("group_#{root_group.id}")
      end
    end
  end

  describe '#group_path' do
    subject(:path) { secrets_manager.group_path }

    it 'returns group_<group_id> for a root group' do
      expect(path).to eq("group_#{group.id}")
    end

    context 'for a nested group' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:nested_group) { create(:group, parent: parent_group) }

      subject(:secrets_manager) { create(:group_secrets_manager, group: nested_group) }

      it 'returns only the group path without the parent group' do
        expect(secrets_manager.group_path).to eq("group_#{nested_group.id}")
      end
    end

    context 'for a deeply nested group' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup_a) { create(:group, parent: root_group) }
      let_it_be(:nested_group) { create(:group, parent: subgroup_a) }

      subject(:secrets_manager) { create(:group_secrets_manager, group: nested_group) }

      it 'returns only the group path without any ancestors' do
        expect(secrets_manager.group_path).to eq("group_#{nested_group.id}")
      end
    end
  end

  describe 'denormalized id columns persisted on create' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:nested_subgroup) { create(:group, parent: root_group) }
    let_it_be(:cached_group) { create(:group, parent: nested_subgroup) }

    subject(:secrets_manager) { create(:group_secrets_manager, group: cached_group) }

    it 'persists organization_id from the group' do
      expect(secrets_manager.organization_id).to eq(cached_group.organization_id)
    end

    it 'persists root_namespace_id from the root ancestor of the group' do
      expect(secrets_manager.root_namespace_id).to eq(root_group.id)
    end
  end

  describe '#full_group_namespace_path' do
    it 'joins org/root_namespace/group paths for a root group' do
      expect(secrets_manager.full_group_namespace_path)
        .to eq("org_#{group.organization_id}/group_#{group.id}/group_#{group.id}")
    end

    context 'for a nested group' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:nested_group) { create(:group, parent: parent_group) }

      subject(:secrets_manager) { create(:group_secrets_manager, group: nested_group) }

      it 'uses the root namespace for level 2 and the group for level 3' do
        expect(secrets_manager.full_group_namespace_path)
          .to eq("org_#{nested_group.organization_id}/group_#{parent_group.id}/group_#{nested_group.id}")
      end
    end

    context 'for a deeply nested group' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup_a) { create(:group, parent: root_group) }
      let_it_be(:subgroup_b) { create(:group, parent: subgroup_a) }

      subject(:secrets_manager) { create(:group_secrets_manager, group: subgroup_b) }

      it 'flattens subgroup depth to org/root_namespace/group' do
        expect(secrets_manager.full_group_namespace_path)
          .to eq("org_#{subgroup_b.organization_id}/group_#{root_group.id}/group_#{subgroup_b.id}")
      end
    end
  end

  describe '#ci_secrets_mount_full_path' do
    let(:path) { secrets_manager.ci_secrets_mount_full_path }

    before do
      allow(secrets_manager).to receive_messages(
        full_group_namespace_path: 'some/namespace/group_1',
        ci_secrets_mount_path: 'secrets/kv'
      )
    end

    it 'is returns full path including root namespace' do
      expect(path).to eq('some/namespace/group_1/secrets/kv')
    end
  end

  describe '#ci_auth_path' do
    let(:path) { secrets_manager.ci_auth_path }

    before do
      allow(secrets_manager).to receive_messages(
        full_group_namespace_path: 'some/namespace/group_1',
        ci_auth_mount: 'ci_auth'
      )
    end

    it 'returns full CEL auth path including root namespace' do
      expect(path).to eq('some/namespace/group_1/auth/ci_auth/cel/login')
    end
  end

  describe '#secrets_limit' do
    it 'returns the group secrets limit from application settings' do
      stub_application_setting(group_secrets_limit: 456)

      expect(secrets_manager.secrets_limit).to eq(456)
    end

    it 'falls back to the default when application setting is nil' do
      stub_application_setting(group_secrets_limit: nil)

      expect(secrets_manager.secrets_limit)
        .to eq(SecretsManagement::GroupSecretsManager::DEFAULT_SECRETS_LIMIT)
    end
  end

  describe '#namespace_id_for_secret_count' do
    it 'returns the group id (groups are namespaces)' do
      expect(secrets_manager.namespace_id_for_secret_count).to eq(group.id)
    end
  end

  describe '#ci_jwt' do
    let_it_be(:project) { create(:project, namespace: group) }
    let(:secrets_manager) { build(:group_secrets_manager, group: group) }
    let_it_be(:ci_build) { create(:ci_build, project: project) }
    let_it_be(:jwt_audience_value) { described_class.jwt_audience }

    subject(:ci_jwt) { secrets_manager.ci_jwt(ci_build) }

    before do
      allow(SecretsManagement::PipelineJwt).to receive(:for_build)
        .with(ci_build, aud: jwt_audience_value)
        .and_return("generated_jwt_id_token_for_group_secrets_manager")
    end

    it 'generates a JWT for the build' do
      expect(ci_jwt).to eq("generated_jwt_id_token_for_group_secrets_manager")
    end
  end

  describe '.build_org_path' do
    it 'returns org_<organization_id>' do
      expect(described_class.build_org_path(42)).to eq('org_42')
    end
  end

  describe '.build_root_namespace_path' do
    it 'returns group_<root_namespace_id>' do
      expect(described_class.build_root_namespace_path(7)).to eq('group_7')
    end
  end

  describe '.build_group_path' do
    it 'returns group_<group_id>' do
      expect(described_class.build_group_path(99)).to eq('group_99')
    end
  end

  describe '.build_full_group_namespace_path' do
    it 'joins the three levels with /' do
      expect(described_class.build_full_group_namespace_path(
        organization_id: 1, root_namespace_id: 2, group_id: 3
      )).to eq('org_1/group_2/group_3')
    end
  end
end
