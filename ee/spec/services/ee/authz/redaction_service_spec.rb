# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::RedactionService, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:private_group_with_access) { create(:group, :private) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:private_project) { create(:project, :private, group: private_group) }
  let_it_be(:private_project_with_access) { create(:project, :private, group: private_group_with_access) }

  before_all do
    private_group_with_access.add_developer(user)
  end

  before do
    stub_licensed_features(epics: true, security_dashboard: true)
  end

  describe '.supported_types' do
    it 'includes EE resource types' do
      expect(described_class.supported_types).to include(
        'epic', 'vulnerability', 'ci_pipeline', 'ci_stage', 'ci_build', 'ci_runner',
        'label', 'note', 'security_scan', 'security_finding',
        'vulnerability_scanner', 'vulnerability_occurrence', 'vulnerability_identifier',
        'deployment', 'environment', 'package', 'package_file', 'dependency', 'container_repository'
      )
    end

    it 'includes CE resource types' do
      expect(described_class.supported_types).to include(
        'issue', 'merge_request', 'project', 'milestone', 'snippet', 'user', 'group'
      )
    end
  end

  describe '#execute' do
    subject(:result) { service.execute }

    let(:service) { described_class.new(user: user, resources_by_type: resources_by_type, source: 'test') }

    context 'with epics' do
      let_it_be(:public_epic) { create(:epic, group: group) }
      let_it_be(:private_epic) { create(:epic, group: private_group) }
      let_it_be(:accessible_epic) { create(:epic, group: private_group_with_access) }
      let_it_be(:confidential_epic) { create(:epic, :confidential, group: private_group_with_access) }

      context 'when user can access public epic' do
        let(:resources_by_type) { { 'epic' => { 'ids' => [public_epic.id], 'ability' => 'read_epic' } } }

        it 'allows access' do
          expect(result).to eq({ 'epic' => { public_epic.id => true } })
        end
      end

      context 'when user cannot access private epic' do
        let(:resources_by_type) { { 'epic' => { 'ids' => [private_epic.id], 'ability' => 'read_epic' } } }

        it 'denies access' do
          expect(result).to eq({ 'epic' => { private_epic.id => false } })
        end
      end

      context 'when user has group access' do
        let(:resources_by_type) { { 'epic' => { 'ids' => [accessible_epic.id], 'ability' => 'read_epic' } } }

        it 'allows access' do
          expect(result).to eq({ 'epic' => { accessible_epic.id => true } })
        end
      end

      context 'when user has group access to confidential epic' do
        let(:resources_by_type) { { 'epic' => { 'ids' => [confidential_epic.id], 'ability' => 'read_epic' } } }

        it 'allows access for group member' do
          expect(result).to eq({ 'epic' => { confidential_epic.id => true } })
        end
      end

      context 'when checking multiple epics at once' do
        let(:resources_by_type) do
          { 'epic' => { 'ids' => [public_epic.id, private_epic.id, accessible_epic.id],
                        'ability' => 'read_epic' } }
        end

        it 'returns correct authorization for each epic' do
          expect(result).to eq({
            'epic' => {
              public_epic.id => true,
              private_epic.id => false,
              accessible_epic.id => true
            }
          })
        end
      end

      context 'with non-existent epic' do
        let(:resources_by_type) { { 'epic' => { 'ids' => [non_existing_record_id], 'ability' => 'read_epic' } } }

        it 'denies access' do
          expect(result).to eq({ 'epic' => { non_existing_record_id => false } })
        end
      end
    end

    context 'with vulnerabilities' do
      let_it_be(:accessible_vulnerability) { create(:vulnerability, project: private_project_with_access) }
      let_it_be(:inaccessible_vulnerability) { create(:vulnerability, project: private_project) }

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'vulnerability' => { 'ids' => [accessible_vulnerability.id], 'ability' => 'read_vulnerability' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'vulnerability' => { accessible_vulnerability.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'vulnerability' => { 'ids' => [inaccessible_vulnerability.id], 'ability' => 'read_vulnerability' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'vulnerability' => { inaccessible_vulnerability.id => false } })
        end
      end

      context 'when checking multiple vulnerabilities at once' do
        let(:resources_by_type) do
          { 'vulnerability' => { 'ids' => [accessible_vulnerability.id, inaccessible_vulnerability.id],
                                 'ability' => 'read_vulnerability' } }
        end

        it 'returns correct authorization for each vulnerability' do
          expect(result).to eq({
            'vulnerability' => {
              accessible_vulnerability.id => true,
              inaccessible_vulnerability.id => false
            }
          })
        end
      end

      context 'with non-existent vulnerability' do
        let(:resources_by_type) do
          { 'vulnerability' => { 'ids' => [non_existing_record_id], 'ability' => 'read_vulnerability' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'vulnerability' => { non_existing_record_id => false } })
        end
      end
    end

    context 'with ci_pipelines' do
      let_it_be(:accessible_pipeline) { create(:ci_pipeline, project: private_project_with_access) }
      let_it_be(:inaccessible_pipeline) { create(:ci_pipeline, project: private_project) }

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'ci_pipeline' => { 'ids' => [accessible_pipeline.id], 'ability' => 'read_pipeline' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'ci_pipeline' => { accessible_pipeline.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'ci_pipeline' => { 'ids' => [inaccessible_pipeline.id], 'ability' => 'read_pipeline' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'ci_pipeline' => { inaccessible_pipeline.id => false } })
        end
      end
    end

    context 'with packages' do
      let_it_be(:accessible_package) { create(:generic_package, project: private_project_with_access) }
      let_it_be(:inaccessible_package) { create(:generic_package, project: private_project) }

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'package' => { 'ids' => [accessible_package.id], 'ability' => 'read_package' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'package' => { accessible_package.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'package' => { 'ids' => [inaccessible_package.id], 'ability' => 'read_package' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'package' => { inaccessible_package.id => false } })
        end
      end

      context 'with non-existent package' do
        let(:resources_by_type) do
          { 'package' => { 'ids' => [non_existing_record_id], 'ability' => 'read_package' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'package' => { non_existing_record_id => false } })
        end
      end
    end

    context 'with package_files' do
      let_it_be(:accessible_package) { create(:generic_package, project: private_project_with_access) }
      let_it_be(:inaccessible_package) { create(:generic_package, project: private_project) }
      let_it_be(:accessible_package_file) { create(:package_file, package: accessible_package) }
      let_it_be(:inaccessible_package_file) { create(:package_file, package: inaccessible_package) }

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'package_file' => { 'ids' => [accessible_package_file.id], 'ability' => 'read_package' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'package_file' => { accessible_package_file.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'package_file' => { 'ids' => [inaccessible_package_file.id], 'ability' => 'read_package' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'package_file' => { inaccessible_package_file.id => false } })
        end
      end

      context 'with non-existent package_file' do
        let(:resources_by_type) do
          { 'package_file' => { 'ids' => [non_existing_record_id], 'ability' => 'read_package' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'package_file' => { non_existing_record_id => false } })
        end
      end

      it 'preloads both the direct project and the package the policy delegates to' do
        # collect_policy_subjects preseeds the ProjectPolicyPreloader via resource.project, so the
        # direct project must be preloaded. PackageFilePolicy then delegates to the file's package,
        # which delegates to its project, so package_file -> package -> project is also preloaded.
        expect(EE::Authz::RedactionService::EE_PRELOAD_ASSOCIATIONS[:package_file]).to eq(
          [
            { project: [:namespace, :project_feature, :group, :organization] },
            { package: { project: [:namespace, :project_feature, :group, :organization] } }
          ]
        )
      end
    end

    context 'with dependencies' do
      let_it_be(:accessible_dependency) { create(:packages_dependency, project: private_project_with_access) }
      let_it_be(:inaccessible_dependency) { create(:packages_dependency, project: private_project) }

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'dependency' => { 'ids' => [accessible_dependency.id], 'ability' => 'read_package' } }
        end

        it 'allows access via the dependency project' do
          expect(result).to eq({ 'dependency' => { accessible_dependency.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'dependency' => { 'ids' => [inaccessible_dependency.id], 'ability' => 'read_package' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'dependency' => { inaccessible_dependency.id => false } })
        end
      end

      context 'with non-existent dependency' do
        let(:resources_by_type) do
          { 'dependency' => { 'ids' => [non_existing_record_id], 'ability' => 'read_package' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'dependency' => { non_existing_record_id => false } })
        end
      end
    end

    context 'with container_repositories' do
      let_it_be(:accessible_repository) { create(:container_repository, project: private_project_with_access) }
      let_it_be(:inaccessible_repository) { create(:container_repository, project: private_project) }

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'container_repository' => { 'ids' => [accessible_repository.id], 'ability' => 'read_container_image' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'container_repository' => { accessible_repository.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'container_repository' => { 'ids' => [inaccessible_repository.id], 'ability' => 'read_container_image' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'container_repository' => { inaccessible_repository.id => false } })
        end
      end

      context 'with non-existent container_repository' do
        let(:resources_by_type) do
          { 'container_repository' => { 'ids' => [non_existing_record_id], 'ability' => 'read_container_image' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'container_repository' => { non_existing_record_id => false } })
        end
      end
    end

    context 'with ci_stages' do
      let_it_be(:accessible_pipeline) { create(:ci_pipeline, project: private_project_with_access) }
      let_it_be(:inaccessible_pipeline) { create(:ci_pipeline, project: private_project) }
      let_it_be(:accessible_stage) do
        create(:ci_stage, pipeline: accessible_pipeline, project: accessible_pipeline.project)
      end

      let_it_be(:inaccessible_stage) do
        create(:ci_stage, pipeline: inaccessible_pipeline, project: inaccessible_pipeline.project)
      end

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'ci_stage' => { 'ids' => [accessible_stage.id], 'ability' => 'read_build' } }
        end

        it 'allows access via pipeline delegation' do
          expect(result).to eq({ 'ci_stage' => { accessible_stage.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'ci_stage' => { 'ids' => [inaccessible_stage.id], 'ability' => 'read_build' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'ci_stage' => { inaccessible_stage.id => false } })
        end
      end
    end

    context 'with ci_runners' do
      let_it_be(:maintained_group) { create(:group, :private) }
      let_it_be(:maintained_subgroup) { create(:group, :private, parent: maintained_group) }
      let_it_be(:maintained_project) { create(:project, :private, group: maintained_subgroup) }
      let_it_be(:other_private_group) { create(:group, :private) }

      let_it_be(:instance_runner) { create(:ci_runner, :instance) }
      let_it_be(:group_runner_at_parent) { create(:ci_runner, :group, groups: [maintained_group]) }
      let_it_be(:inaccessible_group_runner) { create(:ci_runner, :group, groups: [other_private_group]) }
      let_it_be(:project_runner) { create(:ci_runner, :project, projects: [maintained_project]) }
      let_it_be(:inaccessible_project_runner) { create(:ci_runner, :project, projects: [private_project]) }

      before_all do
        maintained_group.add_maintainer(user)
      end

      context 'when the runner is an instance runner' do
        let(:resources_by_type) do
          { 'ci_runner' => { 'ids' => [instance_runner.id], 'ability' => 'read_runner' } }
        end

        it 'allows access for any authenticated user' do
          expect(result).to eq({ 'ci_runner' => { instance_runner.id => true } })
        end
      end

      context 'when user is a maintainer of the runner group' do
        let(:resources_by_type) do
          { 'ci_runner' => { 'ids' => [group_runner_at_parent.id], 'ability' => 'read_runner' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'ci_runner' => { group_runner_at_parent.id => true } })
        end
      end

      context 'when the runner is registered at a parent group and the user owns a project that inherits it' do
        let(:resources_by_type) do
          { 'ci_runner' => { 'ids' => [group_runner_at_parent.id], 'ability' => 'read_runner' } }
        end

        it 'allows access via the subgroup project that inherits group runners' do
          expect(maintained_project.group_runners_enabled).to be true
          expect(result).to eq({ 'ci_runner' => { group_runner_at_parent.id => true } })
        end
      end

      context 'when user has no access to the runner group' do
        let(:resources_by_type) do
          { 'ci_runner' => { 'ids' => [inaccessible_group_runner.id], 'ability' => 'read_runner' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'ci_runner' => { inaccessible_group_runner.id => false } })
        end
      end

      context 'when user is a maintainer of the runner project' do
        let(:resources_by_type) do
          { 'ci_runner' => { 'ids' => [project_runner.id], 'ability' => 'read_runner' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'ci_runner' => { project_runner.id => true } })
        end
      end

      context 'when user cannot read the project runner' do
        let(:resources_by_type) do
          { 'ci_runner' => { 'ids' => [inaccessible_project_runner.id], 'ability' => 'read_runner' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'ci_runner' => { inaccessible_project_runner.id => false } })
        end
      end

      context 'when the runner id does not exist' do
        let(:resources_by_type) do
          { 'ci_runner' => { 'ids' => [non_existing_record_id], 'ability' => 'read_runner' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'ci_runner' => { non_existing_record_id => false } })
        end
      end

      context 'when the request mixes accessible and inaccessible runners' do
        let(:resources_by_type) do
          {
            'ci_runner' => {
              'ids' => [instance_runner.id, group_runner_at_parent.id, inaccessible_group_runner.id],
              'ability' => 'read_runner'
            }
          }
        end

        it 'permits the accessible ids and denies the rest' do
          expect(result).to eq({
            'ci_runner' => {
              instance_runner.id => true,
              group_runner_at_parent.id => true,
              inaccessible_group_runner.id => false
            }
          })
        end
      end
    end

    context 'with labels' do
      let_it_be(:accessible_label) { create(:label, project: private_project_with_access) }
      let_it_be(:inaccessible_label) { create(:label, project: private_project) }

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'label' => { 'ids' => [accessible_label.id], 'ability' => 'read_label' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'label' => { accessible_label.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'label' => { 'ids' => [inaccessible_label.id], 'ability' => 'read_label' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'label' => { inaccessible_label.id => false } })
        end
      end
    end

    context 'with notes' do
      let_it_be(:accessible_issue) { create(:issue, project: private_project_with_access) }
      let_it_be(:inaccessible_issue) { create(:issue, project: private_project) }
      let_it_be(:accessible_note) { create(:note, noteable: accessible_issue, project: private_project_with_access) }
      let_it_be(:inaccessible_note) { create(:note, noteable: inaccessible_issue, project: private_project) }

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'note' => { 'ids' => [accessible_note.id], 'ability' => 'read_note' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'note' => { accessible_note.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'note' => { 'ids' => [inaccessible_note.id], 'ability' => 'read_note' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'note' => { inaccessible_note.id => false } })
        end
      end
    end

    context 'with deployments' do
      let_it_be(:deploy_project_with_access) do
        create(:project, :repository, :private, group: private_group_with_access)
      end

      let_it_be(:deploy_project_without_access) do
        create(:project, :repository, :private, group: private_group)
      end

      let_it_be(:accessible_deployment) do
        create(:deployment, :success, project: deploy_project_with_access)
      end

      let_it_be(:inaccessible_deployment) do
        create(:deployment, :success, project: deploy_project_without_access)
      end

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'deployment' => { 'ids' => [accessible_deployment.id], 'ability' => 'read_deployment' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'deployment' => { accessible_deployment.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'deployment' => { 'ids' => [inaccessible_deployment.id], 'ability' => 'read_deployment' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'deployment' => { inaccessible_deployment.id => false } })
        end
      end
    end

    context 'with environments' do
      let_it_be(:accessible_environment) { create(:environment, project: private_project_with_access) }
      let_it_be(:inaccessible_environment) { create(:environment, project: private_project) }

      context 'when user has project access' do
        let(:resources_by_type) do
          { 'environment' => { 'ids' => [accessible_environment.id], 'ability' => 'read_environment' } }
        end

        it 'allows access' do
          expect(result).to eq({ 'environment' => { accessible_environment.id => true } })
        end
      end

      context 'when user does not have project access' do
        let(:resources_by_type) do
          { 'environment' => { 'ids' => [inaccessible_environment.id], 'ability' => 'read_environment' } }
        end

        it 'denies access' do
          expect(result).to eq({ 'environment' => { inaccessible_environment.id => false } })
        end
      end
    end

    context 'with deployments and environments via shared group' do
      let_it_be(:shared_group) { create(:group, :private) }
      let_it_be(:shared_project) { create(:project, :repository, :private, group: shared_group) }
      let_it_be(:shared_environment) { create(:environment, project: shared_project) }
      let_it_be(:shared_deployment) { create(:deployment, :success, project: shared_project) }

      before_all do
        create(:project_group_link, project: shared_project, group: private_group_with_access)
      end

      context 'when user has access via shared group link' do
        let(:resources_by_type) do
          {
            'deployment' => { 'ids' => [shared_deployment.id], 'ability' => 'read_deployment' },
            'environment' => { 'ids' => [shared_environment.id], 'ability' => 'read_environment' }
          }
        end

        it 'allows access through group link' do
          expect(result).to eq({
            'deployment' => { shared_deployment.id => true },
            'environment' => { shared_environment.id => true }
          })
        end
      end
    end

    context 'with deployments and environments via group-to-group link' do
      let_it_be(:target_group) { create(:group, :private) }
      let_it_be(:target_project) { create(:project, :repository, :private, group: target_group) }
      let_it_be(:target_environment) { create(:environment, project: target_project) }
      let_it_be(:target_deployment) { create(:deployment, :success, project: target_project) }

      before_all do
        create(:group_group_link, shared_group: target_group, shared_with_group: private_group_with_access)
      end

      before do
        user.refresh_authorized_projects
      end

      context 'when user has access via group-to-group share' do
        let(:resources_by_type) do
          {
            'deployment' => { 'ids' => [target_deployment.id], 'ability' => 'read_deployment' },
            'environment' => { 'ids' => [target_environment.id], 'ability' => 'read_environment' }
          }
        end

        it 'allows access through group-to-group link' do
          expect(result).to eq({
            'deployment' => { target_deployment.id => true },
            'environment' => { target_environment.id => true }
          })
        end
      end
    end

    context 'when user has no group-to-group link access' do
      let_it_be(:isolated_group) { create(:group, :private) }
      let_it_be(:isolated_project) { create(:project, :repository, :private, group: isolated_group) }
      let_it_be(:isolated_environment) { create(:environment, project: isolated_project) }
      let_it_be(:isolated_deployment) { create(:deployment, :success, project: isolated_project) }

      let(:resources_by_type) do
        {
          'deployment' => { 'ids' => [isolated_deployment.id], 'ability' => 'read_deployment' },
          'environment' => { 'ids' => [isolated_environment.id], 'ability' => 'read_environment' }
        }
      end

      it 'denies access without group-to-group link' do
        expect(result).to eq({
          'deployment' => { isolated_deployment.id => false },
          'environment' => { isolated_environment.id => false }
        })
      end
    end

    context 'with deployments and environments mixed authorization' do
      let_it_be(:deploy_project) { create(:project, :repository, :private, group: private_group_with_access) }
      let_it_be(:no_access_project) { create(:project, :repository, :private, group: private_group) }
      let_it_be(:accessible_deploy) { create(:deployment, :success, project: deploy_project) }
      let_it_be(:inaccessible_deploy) { create(:deployment, :success, project: no_access_project) }
      let_it_be(:accessible_env) { create(:environment, project: private_project_with_access) }
      let_it_be(:inaccessible_env) { create(:environment, project: private_project) }

      let(:resources_by_type) do
        {
          'deployment' => {
            'ids' => [accessible_deploy.id, inaccessible_deploy.id, non_existing_record_id],
            'ability' => 'read_deployment'
          },
          'environment' => {
            'ids' => [accessible_env.id, inaccessible_env.id, non_existing_record_id],
            'ability' => 'read_environment'
          }
        }
      end

      it 'returns correct authorization for each resource' do
        expect(result).to eq({
          'deployment' => {
            accessible_deploy.id => true,
            inaccessible_deploy.id => false,
            non_existing_record_id => false
          },
          'environment' => {
            accessible_env.id => true,
            inaccessible_env.id => false,
            non_existing_record_id => false
          }
        })
      end
    end

    context 'with mixed CE and EE resource types' do
      let_it_be(:public_issue) { create(:issue, project: project) }
      let_it_be(:public_epic) { create(:epic, group: group) }
      let_it_be(:accessible_vulnerability) { create(:vulnerability, project: private_project_with_access) }
      let_it_be(:private_mr) { create(:merge_request, source_project: private_project) }

      let(:resources_by_type) do
        {
          'issue' => { 'ids' => [public_issue.id], 'ability' => 'read_issue' },
          'epic' => { 'ids' => [public_epic.id], 'ability' => 'read_epic' },
          'vulnerability' => { 'ids' => [accessible_vulnerability.id], 'ability' => 'read_vulnerability' },
          'merge_request' => { 'ids' => [private_mr.id], 'ability' => 'read_merge_request' }
        }
      end

      it 'handles both CE and EE resource types correctly' do
        expect(result).to eq({
          'issue' => { public_issue.id => true },
          'epic' => { public_epic.id => true },
          'vulnerability' => { accessible_vulnerability.id => true },
          'merge_request' => { private_mr.id => false }
        })
      end
    end

    context 'with empty arrays for EE types' do
      let(:resources_by_type) do
        {
          'epic' => { 'ids' => [], 'ability' => 'read_epic' },
          'vulnerability' => { 'ids' => [], 'ability' => 'read_vulnerability' }
        }
      end

      it 'returns empty hashes for those types' do
        expect(result).to eq({ 'epic' => {}, 'vulnerability' => {} })
      end
    end

    context 'with missing ability (fail-closed)' do
      let_it_be(:public_epic) { create(:epic, group: group) }
      let_it_be(:private_epic) { create(:epic, group: private_group) }

      context 'when no ability is provided for EE type' do
        let(:resources_by_type) do
          { 'epic' => { 'ids' => [public_epic.id, private_epic.id] } }
        end

        it 'denies access for all resources when ability is not specified' do
          expect(result).to eq({
            'epic' => {
              public_epic.id => false,
              private_epic.id => false
            }
          })
        end
      end
    end
  end

  describe 'load_resources_for_type behavior' do
    context 'when EE resource type has no preload associations defined' do
      let_it_be(:public_epic) { create(:epic, group: group) }
      let(:resources_by_type) { { 'epic' => { 'ids' => [public_epic.id], 'ability' => 'read_epic' } } }
      let(:service) { described_class.new(user: user, resources_by_type: resources_by_type, source: 'test') }

      before do
        stub_const(
          "EE::Authz::RedactionService::EE_PRELOAD_ASSOCIATIONS",
          EE::Authz::RedactionService::EE_PRELOAD_ASSOCIATIONS.except(:epic)
        )
      end

      it 'does not raise an error when preloads are not defined' do
        expect { service.execute }.not_to raise_error
      end

      it 'still performs authorization correctly' do
        result = service.execute
        expect(result).to eq({ 'epic' => { public_epic.id => true } })
      end
    end

    context 'when group is handled as EE resource type' do
      let_it_be(:public_group) { create(:group, :public) }
      let(:service) { described_class.new(user: user, resources_by_type: resources_by_type, source: 'test') }

      context 'with valid group ids' do
        let(:resources_by_type) { { 'group' => { 'ids' => [public_group.id], 'ability' => 'read_group' } } }

        it 'loads and authorizes groups with EE-specific preloads' do
          result = service.execute
          expect(result).to eq({ 'group' => { public_group.id => true } })
        end
      end

      context 'with empty ids' do
        let(:resources_by_type) { { 'group' => { 'ids' => [], 'ability' => 'read_group' } } }

        it 'returns empty hash' do
          result = service.execute
          expect(result).to eq({ 'group' => {} })
        end
      end

      it 'includes group in EE_RESOURCE_CLASSES' do
        expect(EE::Authz::RedactionService::EE_RESOURCE_CLASSES[:group]).to eq(::Group)
      end

      it 'includes saml_provider in EE preload associations for group' do
        expect(EE::Authz::RedactionService::EE_PRELOAD_ASSOCIATIONS[:group]).to include(:saml_provider)
      end

      it 'includes system_note_metadata in EE preload associations for notes' do
        expect(EE::Authz::RedactionService::EE_PRELOAD_ASSOCIATIONS[:note]).to include(:system_note_metadata)
      end
    end
  end
end
