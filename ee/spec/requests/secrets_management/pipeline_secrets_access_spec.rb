# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Secrets Manager Secret Access', :gitlab_secrets_manager, feature_category: :secrets_management do
  include ProjectForksHelper

  def build_user_jwt(user:, project:)
    SecretsManagement::ProjectUserJwt.new(current_user: user, project: project).encoded
  end

  shared_examples 'project pipeline secret access' do
    describe 'reading secrets' do
      before do
        create_project_secret(user: project_owner, project: project, name: 'my_secret', branch: 'master',
          environment: '*', value: 'my_value')
      end

      it 'can read secret with pipeline_jwt of same project' do
        value = read_project_secret_as_pipeline(project_secrets_manager, project_build, 'my_secret')

        expect(value).to eq('my_value')
      end

      it 'cannot read secret with pipeline_jwt of project in same namespace' do
        build = create(:ee_ci_build, pipeline: pipeline_of_project_in_same_namespace,
          user: owner_of_project_in_same_namespace)

        expect do
          read_project_secret_as_pipeline(project_secrets_manager, build, 'my_secret')
        end.to raise_error(SecretsManagement::SecretsManagerClient::AuthenticationError)
      end

      it 'cannot read secret with pipeline_jwt of forked project' do
        build = create(:ee_ci_build, pipeline: forked_project_pipeline, user: project_owner)

        expect do
          read_project_secret_as_pipeline(project_secrets_manager, build, 'my_secret')
        end.to raise_error(SecretsManagement::SecretsManagerClient::AuthenticationError)
      end

      it 'cannot read secret with user_jwt' do
        expect do
          read_project_secret_as_user(project_secrets_manager, project_owner, 'my_secret')
        end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
      end
    end

    describe 'branch and environment scoped secrets' do
      let_it_be(:production_environment) { create(:environment, project: project, name: 'production') }
      let_it_be(:staging_environment) { create(:environment, project: project, name: 'staging') }

      let_it_be(:pipeline) do
        create(:ci_pipeline, project: project, sha: project.commit.id,
          ref: project.default_branch, status: 'success', user: project_owner)
      end

      context 'with global secret (branch: *, environment: *)' do
        before do
          create_project_secret(user: project_owner, project: project, name: 'GLOBAL_SECRET',
            branch: '*', environment: '*', value: 'global-value')
        end

        it 'can access from pipeline without environment' do
          build = create(:ee_ci_build, pipeline: pipeline, user: project_owner)
          value = read_project_secret_as_pipeline(project_secrets_manager, build, 'GLOBAL_SECRET')

          expect(value).to eq('global-value')
        end

        it 'can access from pipeline with any environment' do
          build = create(:ee_ci_build, :with_deployment, pipeline: pipeline,
            user: project_owner, environment: production_environment.name)
          value = read_project_secret_as_pipeline(project_secrets_manager, build, 'GLOBAL_SECRET')

          expect(value).to eq('global-value')
        end
      end

      context 'with environment-scoped secret (branch: *, environment: production)' do
        before do
          create_project_secret(user: project_owner, project: project, name: 'PROD_SECRET',
            branch: '*', environment: 'production', value: 'prod-value')
        end

        it 'can access when pipeline has matching environment' do
          build = create(:ee_ci_build, :with_deployment, pipeline: pipeline,
            user: project_owner, environment: production_environment.name)
          value = read_project_secret_as_pipeline(project_secrets_manager, build, 'PROD_SECRET')

          expect(value).to eq('prod-value')
        end

        it 'cannot access when pipeline has different environment' do
          build = create(:ee_ci_build, :with_deployment, pipeline: pipeline,
            user: project_owner, environment: staging_environment.name)

          expect do
            read_project_secret_as_pipeline(project_secrets_manager, build, 'PROD_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end

        it 'cannot access when pipeline has no environment' do
          build = create(:ee_ci_build, pipeline: pipeline, user: project_owner)

          expect do
            read_project_secret_as_pipeline(project_secrets_manager, build, 'PROD_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end
      end

      context 'with branch-scoped secret (branch: master, environment: *)' do
        before do
          create_project_secret(user: project_owner, project: project, name: 'MASTER_SECRET',
            branch: 'master', environment: '*', value: 'master-value')
        end

        it 'can access when pipeline ref matches branch' do
          build = create(:ee_ci_build, pipeline: pipeline, user: project_owner)
          value = read_project_secret_as_pipeline(project_secrets_manager, build, 'MASTER_SECRET')

          expect(value).to eq('master-value')
        end

        it 'cannot access when pipeline ref does not match branch' do
          feature_pipeline = create(:ci_pipeline, project: project, sha: project.commit.id,
            ref: 'feature-branch', status: 'success', user: project_owner)
          build = create(:ee_ci_build, pipeline: feature_pipeline, user: project_owner)

          expect do
            read_project_secret_as_pipeline(project_secrets_manager, build, 'MASTER_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end
      end

      context 'with branch and environment-scoped secret (branch: master, environment: production)' do
        before do
          create_project_secret(user: project_owner, project: project, name: 'MASTER_PROD',
            branch: 'master', environment: 'production', value: 'master-prod-value')
        end

        it 'can access when pipeline ref and environment both match' do
          build = create(:ee_ci_build, :with_deployment, pipeline: pipeline,
            user: project_owner, environment: production_environment.name)
          value = read_project_secret_as_pipeline(project_secrets_manager, build, 'MASTER_PROD')

          expect(value).to eq('master-prod-value')
        end

        it 'cannot access when pipeline ref matches but environment does not' do
          build = create(:ee_ci_build, :with_deployment, pipeline: pipeline,
            user: project_owner, environment: staging_environment.name)

          expect do
            read_project_secret_as_pipeline(project_secrets_manager, build, 'MASTER_PROD')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end

        it 'cannot access when pipeline ref matches but has no environment' do
          build = create(:ee_ci_build, pipeline: pipeline, user: project_owner)

          expect do
            read_project_secret_as_pipeline(project_secrets_manager, build, 'MASTER_PROD')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end

        it 'cannot access when environment matches but ref does not' do
          feature_pipeline = create(:ci_pipeline, project: project, sha: project.commit.id,
            ref: 'feature-branch', status: 'success', user: project_owner)
          build = create(:ee_ci_build, :with_deployment, pipeline: feature_pipeline,
            user: project_owner, environment: production_environment.name)

          expect do
            read_project_secret_as_pipeline(project_secrets_manager, build, 'MASTER_PROD')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end
      end
    end
  end

  describe 'Project Secrets Manager pipeline access' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:project) { create(:project, :repository, namespace: namespace) }
    let_it_be(:project_in_same_namespace) { create(:project, :repository, namespace: namespace) }
    let_it_be(:project_owner) { create(:user, owner_of: project) }
    let_it_be(:project_developer) { create(:user, developer_of: project) }
    let_it_be(:owner_of_project_in_same_namespace) { create(:user, owner_of: project_in_same_namespace) }

    let_it_be(:forked_project) { fork_project(project, project_owner, repository: true) }

    let_it_be_with_reload(:project_secrets_manager) { create(:project_secrets_manager, project: project) }
    let_it_be_with_reload(:secrets_manager_of_project_in_same_namespace) do
      create(:project_secrets_manager, project: project_in_same_namespace)
    end

    let_it_be_with_reload(:secrets_manager_of_forked_project) do
      create(:project_secrets_manager, project: forked_project)
    end

    let_it_be(:project_pipeline) do
      create(:ci_pipeline, project: project, sha: project.commit.id,
        ref: project.default_branch, status: 'success', user: project_owner)
    end

    let_it_be(:pipeline_of_project_in_same_namespace) do
      create(:ci_pipeline, project: project_in_same_namespace, sha: project_in_same_namespace.commit.id,
        ref: project_in_same_namespace.default_branch, status: 'success', user: owner_of_project_in_same_namespace)
    end

    let_it_be(:forked_project_pipeline) do
      create(:ci_pipeline, project: forked_project, sha: forked_project.commit.id,
        ref: forked_project.default_branch, status: 'success', user: project_owner)
    end

    let(:project_build) { create(:ee_ci_build, pipeline: project_pipeline, user: project_owner) }

    before do
      clean_all_kv_secrets_engines
      provision_project_secrets_manager(project_secrets_manager, project_owner)
      provision_project_secrets_manager(secrets_manager_of_project_in_same_namespace,
        owner_of_project_in_same_namespace)
      provision_project_secrets_manager(secrets_manager_of_forked_project, project_owner)
    end

    it_behaves_like 'project pipeline secret access'

    describe 'CEL-specific validation' do
      before do
        create_project_secret(user: project_owner, project: project, name: 'my_secret', branch: 'master',
          environment: '*', value: 'my_value')
      end

      it 'can read secret with pipeline_jwt of same project' do
        value = read_project_secret_as_pipeline(project_secrets_manager, project_build, 'my_secret')

        expect(value).to eq('my_value')
      end

      it 'cannot read secret with pipeline_jwt missing secrets_manager_scope claim' do
        jwt = Gitlab::Ci::JwtV2.for_build(project_build, aud: project_secrets_manager.class.jwt_audience)

        expect do
          read_project_secret_with_jwt(project_secrets_manager, jwt, 'my_secret')
        end.to raise_error(SecretsManagement::SecretsManagerClient::AuthenticationError,
          /missing secrets_manager_scope/)
      end

      it 'cannot read secret with pipeline_jwt of project in same namespace' do
        build = create(:ee_ci_build, pipeline: pipeline_of_project_in_same_namespace,
          user: owner_of_project_in_same_namespace)

        expect do
          read_project_secret_as_pipeline(project_secrets_manager, build, 'my_secret')
        end.to raise_error(SecretsManagement::SecretsManagerClient::AuthenticationError,
          /token project_id does not match project/)
      end

      it 'rejects pipeline_jwt of forked project with CEL error' do
        build = create(:ee_ci_build, pipeline: forked_project_pipeline, user: project_owner)

        expect do
          read_project_secret_as_pipeline(project_secrets_manager, build, 'my_secret')
        end.to raise_error(SecretsManagement::SecretsManagerClient::AuthenticationError,
          /token project_id does not match project/)
      end
    end
  end

  describe 'Group Secrets Manager pipeline access' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, namespace: group) }
    let_it_be(:owner) { create(:user, owner_of: group) }
    let_it_be_with_reload(:group_secrets_manager) { create(:group_secrets_manager, group: group) }

    let_it_be(:production_environment) { create(:environment, project: project, name: 'production') }
    let_it_be(:staging_environment) { create(:environment, project: project, name: 'staging') }

    before_all do
      group.add_owner(owner)
    end

    before do
      clean_all_kv_secrets_engines
      provision_group_secrets_manager(group_secrets_manager, owner)
    end

    describe 'unprotected pipeline accessing secrets' do
      let_it_be(:pipeline) do
        create(:ci_pipeline, project: project, sha: project.commit.id,
          ref: project.default_branch, status: 'success', user: owner)
      end

      context 'with global secret (environment: "*")' do
        let!(:global_secret) do
          create_group_secret(
            user: owner,
            group: group,
            name: 'GLOBAL_SECRET',
            value: 'global-value',
            protected: false,
            environment: '*'
          )
        end

        it 'can access the secret from unprotected pipeline without environment' do
          build = create(:ee_ci_build, pipeline: pipeline, user: owner)
          secret_value = read_group_secret_as_pipeline(group_secrets_manager, build, 'GLOBAL_SECRET')

          expect(secret_value).to eq('global-value')
        end

        it 'can access the secret from pipeline with any environment' do
          build = create(:ee_ci_build, :with_deployment, pipeline: pipeline,
            user: owner, environment: production_environment.name)
          secret_value = read_group_secret_as_pipeline(group_secrets_manager, build, 'GLOBAL_SECRET')

          expect(secret_value).to eq('global-value')
        end
      end

      context 'with environment-scoped secret' do
        let!(:production_secret) do
          create_group_secret(
            user: owner,
            group: group,
            name: 'PROD_SECRET',
            value: 'prod-value',
            protected: false,
            environment: 'production'
          )
        end

        it 'can access the secret when pipeline has matching environment' do
          build = create(:ee_ci_build, :with_deployment, pipeline: pipeline,
            user: owner, environment: production_environment.name)
          secret_value = read_group_secret_as_pipeline(group_secrets_manager, build, 'PROD_SECRET')

          expect(secret_value).to eq('prod-value')
        end

        it 'cannot access the secret when pipeline has different environment' do
          build = create(:ee_ci_build, :with_deployment, pipeline: pipeline,
            user: owner, environment: staging_environment.name)

          expect do
            read_group_secret_as_pipeline(group_secrets_manager, build, 'PROD_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end

        it 'cannot access the secret when pipeline has no environment' do
          build = create(:ee_ci_build, pipeline: pipeline, user: owner)

          expect do
            read_group_secret_as_pipeline(group_secrets_manager, build, 'PROD_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end
      end

      context 'with protected global secret' do
        let!(:protected_secret) do
          create_group_secret(
            user: owner,
            group: group,
            name: 'PROTECTED_SECRET',
            value: 'protected-value',
            protected: true,
            environment: '*'
          )
        end

        it 'cannot access protected secret from unprotected pipeline' do
          build = create(:ee_ci_build, pipeline: pipeline, user: owner)

          expect do
            read_group_secret_as_pipeline(group_secrets_manager, build, 'PROTECTED_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end
      end

      context 'with protected environment-scoped secret (environment: "production", protected: true)' do
        let!(:protected_prod_secret) do
          create_group_secret(
            user: owner,
            group: group,
            name: 'PROTECTED_PROD_SECRET',
            value: 'protected-prod-value',
            protected: true,
            environment: 'production'
          )
        end

        it 'cannot access protected env secret from unprotected pipeline with matching environment' do
          build = create(:ee_ci_build, :with_deployment, pipeline: pipeline,
            user: owner, environment: production_environment.name)

          expect do
            read_group_secret_as_pipeline(group_secrets_manager, build, 'PROTECTED_PROD_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end
      end
    end

    describe 'protected pipeline accessing secrets' do
      let_it_be(:pipeline) do
        create(:ci_pipeline, project: project, sha: project.commit.id,
          ref: project.default_branch, status: 'success', user: owner)
      end

      context 'with unprotected global secret (environment: "*", protected: false)' do
        let!(:unprotected_global_secret) do
          create_group_secret(
            user: owner,
            group: group,
            name: 'UNPROTECTED_GLOBAL_SECRET',
            value: 'unprotected-global-value',
            protected: false,
            environment: '*'
          )
        end

        it 'can access unprotected global secret from protected pipeline' do
          build = create(:ee_ci_build, :protected, pipeline: pipeline, user: owner)
          secret_value = read_group_secret_as_pipeline(group_secrets_manager, build, 'UNPROTECTED_GLOBAL_SECRET')

          expect(secret_value).to eq('unprotected-global-value')
        end
      end

      context 'with unprotected environment-scoped secret (environment: "production", protected: false)' do
        let!(:unprotected_prod_secret) do
          create_group_secret(
            user: owner,
            group: group,
            name: 'UNPROTECTED_PROD_SECRET',
            value: 'unprotected-prod-value',
            protected: false,
            environment: 'production'
          )
        end

        it 'can access unprotected env secret from protected pipeline with matching environment' do
          build = create(:ee_ci_build, :protected, :with_deployment, pipeline: pipeline,
            user: owner, environment: production_environment.name)
          secret_value = read_group_secret_as_pipeline(group_secrets_manager, build, 'UNPROTECTED_PROD_SECRET')

          expect(secret_value).to eq('unprotected-prod-value')
        end

        it 'cannot access unprotected env secret from protected pipeline with wrong environment' do
          build = create(:ee_ci_build, :protected, :with_deployment, pipeline: pipeline,
            user: owner, environment: staging_environment.name)

          expect do
            read_group_secret_as_pipeline(group_secrets_manager, build, 'UNPROTECTED_PROD_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end

        it 'cannot access unprotected env secret from protected pipeline with no environment' do
          build = create(:ee_ci_build, :protected, pipeline: pipeline, user: owner)

          expect do
            read_group_secret_as_pipeline(group_secrets_manager, build, 'UNPROTECTED_PROD_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end
      end

      context 'with protected global secret' do
        let!(:protected_secret) do
          create_group_secret(
            user: owner,
            group: group,
            name: 'PROTECTED_SECRET',
            value: 'protected-value',
            protected: true,
            environment: '*'
          )
        end

        it 'can access protected secret from protected pipeline' do
          build = create(:ee_ci_build, :protected, pipeline: pipeline, user: owner)
          secret_value = read_group_secret_as_pipeline(group_secrets_manager, build, 'PROTECTED_SECRET')

          expect(secret_value).to eq('protected-value')
        end
      end

      context 'with protected and environment-scoped secret' do
        let!(:protected_prod_secret) do
          create_group_secret(
            user: owner,
            group: group,
            name: 'PROTECTED_PROD_SECRET',
            value: 'protected-prod-value',
            protected: true,
            environment: 'production'
          )
        end

        it 'can access the secret when pipeline is protected and has matching environment' do
          build = create(:ee_ci_build, :protected, :with_deployment, pipeline: pipeline,
            user: owner, environment: production_environment.name)
          secret_value = read_group_secret_as_pipeline(group_secrets_manager, build, 'PROTECTED_PROD_SECRET')

          expect(secret_value).to eq('protected-prod-value')
        end

        it 'cannot access the secret when pipeline is protected but has wrong environment' do
          build = create(:ee_ci_build, :protected, :with_deployment, pipeline: pipeline,
            user: owner, environment: staging_environment.name)

          expect do
            read_group_secret_as_pipeline(group_secrets_manager, build, 'PROTECTED_PROD_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end

        it 'cannot access the secret when pipeline is protected but has no environment' do
          build = create(:ee_ci_build, :protected, pipeline: pipeline, user: owner)

          expect do
            read_group_secret_as_pipeline(group_secrets_manager, build, 'PROTECTED_PROD_SECRET')
          end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError, /permission denied/)
        end
      end
    end

    describe 'user access to pipeline secrets' do
      let!(:global_secret) do
        create_group_secret(
          user: owner,
          group: group,
          name: 'PIPELINE_SECRET',
          value: 'pipeline-value',
          protected: false,
          environment: '*'
        )
      end

      it 'cannot read pipeline secret with user_jwt - login fails' do
        expect do
          read_group_secret_as_user(group_secrets_manager, owner, 'PIPELINE_SECRET')
        end.to raise_error(SecretsManagement::SecretsManagerClient::AuthenticationError,
          /invalid subject for user authentication/)
      end
    end
  end

  describe 'Group Secrets Manager pipeline access from subgroup project' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:child_group) { create(:group, parent: root_group) }
    let_it_be(:project) { create(:project, :repository, namespace: child_group) }
    let_it_be(:owner) { create(:user, owner_of: root_group) }
    let_it_be_with_reload(:root_group_secrets_manager) { create(:group_secrets_manager, group: root_group) }

    before do
      clean_all_kv_secrets_engines
      provision_group_secrets_manager(root_group_secrets_manager, owner)
    end

    context 'when project in subgroup reads a secret from ancestor group' do
      let_it_be(:pipeline) do
        create(:ci_pipeline, project: project, sha: project.commit.id,
          ref: project.default_branch, status: 'success', user: owner)
      end

      before do
        create_group_secret(
          user: owner,
          group: root_group,
          name: 'ANCESTOR_SECRET',
          value: 'ancestor-value',
          protected: false,
          environment: '*'
        )
      end

      it 'can read ancestor group secret using pipeline jwt from subgroup project' do
        build = create(:ee_ci_build, pipeline: pipeline, user: owner)
        secret_value = read_group_secret_as_pipeline(root_group_secrets_manager, build, 'ANCESTOR_SECRET')

        expect(secret_value).to eq('ancestor-value')
      end

      it 'cannot read ancestor group secret with pipeline jwt from unrelated project' do
        unrelated_group = create(:group)
        unrelated_project = create(:project, :repository, namespace: unrelated_group)
        unrelated_pipeline = create(:ci_pipeline, project: unrelated_project,
          sha: unrelated_project.commit.id, ref: unrelated_project.default_branch,
          status: 'success', user: owner)
        build = create(:ee_ci_build, pipeline: unrelated_pipeline, user: owner)

        expect do
          read_group_secret_as_pipeline(root_group_secrets_manager, build, 'ANCESTOR_SECRET')
        end.to raise_error(SecretsManagement::SecretsManagerClient::AuthenticationError)
      end
    end
  end

  private

  def read_project_secret_as_pipeline(secrets_manager, build, secret_name)
    jwt = secrets_manager.ci_jwt(build)

    client = SecretsManagement::TestClient.new(
      jwt: jwt,
      role: secrets_manager.ci_auth_role,
      auth_mount: secrets_manager.ci_auth_mount,
      use_cel_auth: true,
      auth_namespace: secrets_manager.full_project_namespace_path,
      namespace: secrets_manager.full_project_namespace_path
    )

    client.read_kv_secret_value(
      secrets_manager.ci_secrets_mount_path,
      secrets_manager.ci_data_path(secret_name)
    )
  end

  def read_project_secret_with_jwt(secrets_manager, jwt, secret_name)
    client = SecretsManagement::TestClient.new(
      jwt: jwt,
      role: secrets_manager.ci_auth_role,
      auth_mount: secrets_manager.ci_auth_mount,
      use_cel_auth: true,
      auth_namespace: secrets_manager.full_project_namespace_path,
      namespace: secrets_manager.full_project_namespace_path
    )

    client.read_kv_secret_value(
      secrets_manager.ci_secrets_mount_path,
      secrets_manager.ci_data_path(secret_name)
    )
  end

  def read_project_secret_as_user(secrets_manager, user, secret_name)
    client = build_user_client(secrets_manager, user)

    client.read_kv_secret_value(
      secrets_manager.ci_secrets_mount_path,
      secrets_manager.ci_data_path(secret_name)
    )
  end

  def build_user_client(secrets_manager, user)
    jwt = build_user_jwt(user: user, project: secrets_manager.project)

    SecretsManagement::TestClient.new(
      jwt: jwt,
      role: secrets_manager.user_auth_role,
      auth_mount: secrets_manager.user_auth_mount,
      use_cel_auth: true,
      auth_namespace: secrets_manager.full_project_namespace_path,
      namespace: secrets_manager.full_project_namespace_path
    )
  end

  def read_group_secret_as_pipeline(secrets_manager, build, secret_name)
    jwt = secrets_manager.ci_jwt(build)

    client = SecretsManagement::TestClient.new(
      jwt: jwt,
      role: secrets_manager.ci_auth_role,
      auth_mount: secrets_manager.ci_auth_mount,
      auth_namespace: secrets_manager.full_group_namespace_path,
      use_cel_auth: true,
      namespace: secrets_manager.full_group_namespace_path
    )

    client.read_kv_secret_value(
      secrets_manager.ci_secrets_mount_path,
      "#{secrets_manager.ci_data_root_path}/#{secret_name}"
    )
  end

  def read_group_secret_as_user(secrets_manager, user, secret_name)
    jwt = SecretsManagement::GroupSecretsManagerJwt.new(
      current_user: user,
      group: secrets_manager.group
    ).encoded

    client = SecretsManagement::TestClient.new(
      jwt: jwt,
      role: secrets_manager.user_auth_role,
      auth_mount: secrets_manager.user_auth_mount,
      use_cel_auth: true,
      auth_namespace: secrets_manager.full_group_namespace_path,
      namespace: secrets_manager.full_group_namespace_path
    )

    client.read_kv_secret_value(
      secrets_manager.ci_secrets_mount_path,
      "#{secrets_manager.ci_data_root_path}/#{secret_name}"
    )
  end
end
