# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }

  subject(:secrets_manager) { create(:project_secrets_manager, project: project) }

  it { is_expected.to belong_to(:project) }

  it { is_expected.to validate_presence_of(:project) }

  it_behaves_like 'a secrets manager'

  describe '#pending_deprovision_task?' do
    it 'delegates to ProjectSecretsManagerMaintenanceTask.deprovision_pending_for?' do
      expect(SecretsManagement::ProjectSecretsManagerMaintenanceTask)
        .to receive(:deprovision_pending_for?).with(secrets_manager.project_id).and_return(true)

      expect(secrets_manager.pending_deprovision_task?).to be(true)
    end
  end

  describe '#effective_status' do
    it 'returns the underlying status when no deprovision task is pending' do
      expect(secrets_manager.effective_status).to eq(secrets_manager.status)
    end

    it 'returns DEPROVISIONING when a deprovision task is pending, regardless of underlying status' do
      secrets_manager.update!(status: described_class::STATUSES[:active])
      create(:project_secrets_manager_maintenance_task, :deprovision, project: project)

      expect(secrets_manager.effective_status).to eq(described_class::STATUSES[:deprovisioning])
    end
  end

  describe '#ci_policy_name' do
    it 'returns combined policy when both environment and branch are specified' do
      expect(secrets_manager.ci_policy_name('production', 'main'))
        .to eq(secrets_manager.ci_policy_name_combined('production', 'main'))
    end

    it 'returns environment policy when only environment is specified' do
      expect(secrets_manager.ci_policy_name('production', '*'))
        .to eq(secrets_manager.ci_policy_name_env('production'))
    end

    it 'returns branch policy when only branch is specified' do
      expect(secrets_manager.ci_policy_name('*', 'main'))
        .to eq(secrets_manager.ci_policy_name_branch('main'))
    end

    it 'returns global policy when both are wildcards' do
      expect(secrets_manager.ci_policy_name('*', '*'))
        .to eq(secrets_manager.ci_policy_name_global)
    end
  end

  describe '#ci_policy_name_global' do
    it 'returns the correct global policy name' do
      expect(secrets_manager.ci_policy_name_global).to eq("pipelines/global")
    end
  end

  describe '#ci_policy_name_env' do
    it 'returns the correct environment policy name with hex-encoded environment' do
      environment = 'production'
      hex_env = environment.unpack1('H*')

      expect(secrets_manager.ci_policy_name_env(environment)).to eq("pipelines/env/#{hex_env}")
    end

    it 'handles special characters in environment names' do
      environment = 'staging/us-east-1'
      hex_env = environment.unpack1('H*')

      expect(secrets_manager.ci_policy_name_env(environment)).to eq("pipelines/env/#{hex_env}")
    end
  end

  describe '#ci_policy_name_branch' do
    it 'returns the correct branch policy name with hex-encoded branch' do
      branch = 'main'
      hex_branch = branch.unpack1('H*')

      expect(secrets_manager.ci_policy_name_branch(branch)).to eq("pipelines/branch/#{hex_branch}")
    end

    it 'handles special characters in branch names' do
      branch = 'feature/add-new-widget'
      hex_branch = branch.unpack1('H*')

      expect(secrets_manager.ci_policy_name_branch(branch)).to eq("pipelines/branch/#{hex_branch}")
    end
  end

  describe '#ci_policy_name_combined' do
    it 'returns the correct combined policy name' do
      environment = 'production'
      branch = 'main'
      hex_env = environment.unpack1('H*')
      hex_branch = branch.unpack1('H*')

      expected = "pipelines/combined/env/#{hex_env}/branch/#{hex_branch}"
      expect(secrets_manager.ci_policy_name_combined(environment, branch)).to eq(expected)
    end
  end

  describe '#org_path' do
    it 'returns org_<organization_id>' do
      expect(secrets_manager.org_path).to eq("org_#{project.organization_id}")
    end
  end

  describe '#namespace_path' do
    context 'when project belongs to a root group' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:project_in_root) { create(:project, group: root_group) }

      subject(:secrets_manager) { create(:project_secrets_manager, project: project_in_root) }

      it 'uses the root namespace id' do
        expect(secrets_manager.namespace_path).to eq("group_#{root_group.id}")
      end
    end

    context 'when project belongs to a deeply nested group' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: root_group) }
      let_it_be(:nested_subgroup) { create(:group, parent: subgroup) }
      let_it_be(:nested_project) { create(:project, group: nested_subgroup) }

      subject(:secrets_manager) { create(:project_secrets_manager, project: nested_project) }

      it 'uses the root ancestor id, not the immediate parent' do
        expect(secrets_manager.namespace_path).to eq("group_#{root_group.id}")
      end
    end
  end

  describe '#project_path' do
    it 'returns project_<project_id>' do
      expect(secrets_manager.project_path).to eq("project_#{project.id}")
    end
  end

  describe 'denormalized id columns persisted on create' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:nested_subgroup) { create(:group, parent: root_group) }
    let_it_be(:cached_project) { create(:project, group: nested_subgroup) }

    subject(:secrets_manager) { create(:project_secrets_manager, project: cached_project) }

    it 'persists organization_id from the project' do
      expect(secrets_manager.organization_id).to eq(cached_project.organization_id)
    end

    it 'persists root_namespace_id from the root ancestor of the project' do
      expect(secrets_manager.root_namespace_id).to eq(root_group.id)
    end
  end

  describe '#full_project_namespace_path' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:project_in_group) { create(:project, group: root_group) }

    subject(:secrets_manager) { create(:project_secrets_manager, project: project_in_group) }

    it 'joins org/root_namespace/project paths in order' do
      expect(secrets_manager.full_project_namespace_path)
        .to eq("org_#{project_in_group.organization_id}/group_#{root_group.id}/project_#{project_in_group.id}")
    end

    context 'for a deeply nested project' do
      let_it_be(:subgroup) { create(:group, parent: root_group) }
      let_it_be(:nested_project) { create(:project, group: subgroup) }

      subject(:secrets_manager) { create(:project_secrets_manager, project: nested_project) }

      it 'flattens to org/root_namespace/project regardless of subgroup depth' do
        expect(secrets_manager.full_project_namespace_path)
          .to eq("org_#{nested_project.organization_id}/group_#{root_group.id}/project_#{nested_project.id}")
      end
    end
  end

  describe '#ci_secrets_mount_full_path' do
    let(:path) { secrets_manager.ci_secrets_mount_full_path }

    before do
      allow(secrets_manager).to receive_messages(
        full_project_namespace_path: 'some/namespace/project_1',
        ci_secrets_mount_path: 'secrets/kv'
      )
    end

    it 'is returns full path including root namespace' do
      expect(path).to eq('some/namespace/project_1/secrets/kv')
    end
  end

  describe '#ci_auth_path' do
    let(:path) { secrets_manager.ci_auth_path }

    before do
      allow(secrets_manager).to receive_messages(
        full_project_namespace_path: 'some/namespace/project_1',
        ci_auth_mount: 'ci_auth'
      )
    end

    it 'returns CEL login path' do
      expect(path).to eq('some/namespace/project_1/auth/ci_auth/cel/login')
    end
  end

  describe '#pipeline_auth_cel_program' do
    it 'returns a CEL program hash with expected structure' do
      program = secrets_manager.pipeline_auth_cel_program(project.id)

      expect(program).to be_a(Hash)
      expect(program[:variables]).to be_an(Array)
      expect(program[:expression]).to be_a(String)

      variable_names = program[:variables].pluck(:name)
      expect(variable_names).to include(
        'expected_pid', 'pid', 'uid', 'aud', 'expected_aud', 'sub',
        'scope', 'correlation_id', 'namespace_id', 'ref_type', 'ref',
        'environment', 'env_hex', 'ref_hex', 'global_policy',
        'env_policy', 'branch_policy', 'combined_policy'
      )

      expect(program[:expression]).to include('pipeline')
      expect(program[:expression]).to include('project_id')
    end
  end

  describe '#secrets_limit' do
    it 'returns the project secrets limit from application settings' do
      stub_application_setting(project_secrets_limit: 123)

      expect(secrets_manager.secrets_limit).to eq(123)
    end

    it 'falls back to the default when application setting is nil' do
      stub_application_setting(project_secrets_limit: nil)

      expect(secrets_manager.secrets_limit)
        .to eq(SecretsManagement::ProjectSecretsManager::DEFAULT_SECRETS_LIMIT)
    end
  end

  describe '.build_org_path' do
    it 'returns org_<organization_id>' do
      expect(described_class.build_org_path(42)).to eq('org_42')
    end
  end

  describe '#namespace_id_for_secret_count' do
    it 'returns the project_namespace_id' do
      expect(secrets_manager.namespace_id_for_secret_count).to eq(project.project_namespace_id)
    end

    context 'when the project association is nil' do
      it 'returns nil' do
        secrets_manager.project = nil

        expect(secrets_manager.namespace_id_for_secret_count).to be_nil
      end
    end
  end

  describe '.build_root_namespace_path' do
    it 'returns group_<root_namespace_id>' do
      expect(described_class.build_root_namespace_path(7)).to eq('group_7')
    end
  end

  describe '.build_project_path' do
    it 'returns project_<project_id>' do
      expect(described_class.build_project_path(99)).to eq('project_99')
    end
  end

  describe '.build_full_project_namespace_path' do
    it 'joins the three levels with /' do
      expect(described_class.build_full_project_namespace_path(
        organization_id: 1, root_namespace_id: 2, project_id: 3
      )).to eq('org_1/group_2/project_3')
    end
  end
end
