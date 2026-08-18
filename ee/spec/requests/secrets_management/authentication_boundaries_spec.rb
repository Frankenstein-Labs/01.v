# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- This is pentest suite with so many combination scenarios
RSpec.describe 'Secrets Manager Access Control', :gitlab_secrets_manager, feature_category: :secrets_management do
  include ProjectForksHelper

  # Helper methods (shared across all contexts)
  def build_secrets_manager_jwt(user:, project:)
    SecretsManagement::ProjectSecretsManagerJwt.new(current_user: user, project: project).encoded
  end

  def build_user_jwt(user:, project:)
    SecretsManagement::ProjectUserJwt.new(current_user: user, project: project).encoded
  end

  def build_api_jwt(user:, project:)
    SecretsManagement::ProjectApiJwt.new(current_user: user, project: project, auth_via: 'PAT').encoded
  end

  def build_group_user_jwt(user:, group:)
    SecretsManagement::GroupUserJwt.new(current_user: user, group: group).encoded
  end

  def build_group_api_jwt(user:, group:)
    SecretsManagement::GroupApiJwt.new(current_user: user, group: group, auth_via: 'PAT').encoded
  end

  def build_group_secrets_manager_jwt(user:, group:)
    SecretsManagement::GroupSecretsManagerJwt.new(current_user: user, group: group).encoded
  end

  describe 'JWT Authentication Scenarios' do
    context 'with project-level authentication' do
      using RSpec::Parameterized::TableSyntax

      # Project-specific resources
      let_it_be(:namespace_one) { create(:namespace) }
      let_it_be(:namespace_two) { create(:namespace) }

      let_it_be_with_reload(:project) { create(:project, :repository, namespace: namespace_one) }
      let_it_be_with_reload(:project_in_same_namespace) { create(:project, :repository, namespace: namespace_one) }
      let_it_be_with_reload(:project_in_different_namespace) { create(:project, :repository, namespace: namespace_two) }

      let_it_be(:project_owner) { create(:user, owner_of: project) }
      let_it_be(:forked_project_owner) { project_owner }
      let_it_be(:project_developer) { create(:user, developer_of: project) }
      let_it_be(:owner_of_project_in_same_namespace) { create(:user, owner_of: project_in_same_namespace) }
      let_it_be(:owner_of_project_in_different_namespace) { create(:user, owner_of: project_in_different_namespace) }

      let_it_be(:forked_project) { fork_project(project, project_owner, repository: true) }

      let_it_be(:merge_request) do
        create(:merge_request, source_project: forked_project, source_branch: 'feature', target_project: project,
          target_branch: 'master')
      end

      let_it_be_with_refind(:project_secrets_manager) { create(:project_secrets_manager, project: project) }
      let_it_be_with_refind(:secrets_manager_of_project_in_same_namespace) do
        create(:project_secrets_manager, project: project_in_same_namespace)
      end

      let_it_be_with_refind(:secrets_manager_of_project_in_different_namespace) do
        create(:project_secrets_manager, project: project_in_different_namespace)
      end

      let_it_be_with_refind(:secrets_manager_of_forked_project) do
        create(:project_secrets_manager, project: forked_project)
      end

      let_it_be_with_refind(:project_pipeline) do
        create(
          :ci_pipeline,
          project: project,
          sha: project.commit.id,
          ref: project.default_branch,
          status: 'success',
          user: project_developer
        )
      end

      let_it_be_with_refind(:pipeline_of_project_in_same_namespace) do
        create(
          :ci_pipeline,
          project: project_in_same_namespace,
          sha: project_in_same_namespace.commit.id,
          ref: project_in_same_namespace.default_branch,
          status: 'success',
          user: owner_of_project_in_same_namespace
        )
      end

      let_it_be_with_refind(:pipeline_of_project_in_different_namespace) do
        create(
          :ci_pipeline,
          project: project_in_different_namespace,
          sha: project_in_different_namespace.commit.id,
          ref: project_in_different_namespace.default_branch,
          status: 'success',
          user: owner_of_project_in_different_namespace
        )
      end

      let_it_be_with_refind(:merge_request_pipeline_from_forked_project_running_in_original_project) do
        create(
          :ci_pipeline,
          source: :merge_request_event,
          merge_request: merge_request,
          project: project,
          ref: merge_request.ref_path,
          status: 'success',
          user: project_owner
        )
      end

      let_it_be_with_refind(:merge_request_pipeline_from_forked_project_running_in_forked_project) do
        create(
          :ci_pipeline,
          source: :merge_request_event,
          merge_request: merge_request,
          project: forked_project,
          ref: merge_request.ref_path,
          status: 'success',
          user: project_owner
        )
      end

      let(:project_build) { create(:ee_ci_build, pipeline: project_pipeline, user: project_developer) }
      let(:build_of_project_in_same_namespace) do
        create(:ee_ci_build, pipeline: pipeline_of_project_in_same_namespace, user: owner_of_project_in_same_namespace)
      end

      let(:build_of_project_in_different_namespace) do
        create(:ee_ci_build, pipeline: pipeline_of_project_in_different_namespace,
          user: owner_of_project_in_different_namespace)
      end

      let(:forked_project_build_running_in_original_project) do
        create(:ee_ci_build, pipeline: merge_request_pipeline_from_forked_project_running_in_original_project,
          user: project_owner)
      end

      let(:forked_project_build_running_in_forked_project) do
        create(:ee_ci_build, pipeline: merge_request_pipeline_from_forked_project_running_in_forked_project,
          user: project_owner)
      end

      before do
        clean_all_kv_secrets_engines
        provision_project_secrets_manager(project_secrets_manager, project_owner)
        provision_project_secrets_manager(secrets_manager_of_project_in_same_namespace,
          owner_of_project_in_same_namespace)
        provision_project_secrets_manager(secrets_manager_of_project_in_different_namespace,
          owner_of_project_in_different_namespace)
        provision_project_secrets_manager(secrets_manager_of_forked_project, forked_project_owner)
      end

      where(:jwt_type, :jwt_scope, :auth_mount, :expected_result, :errror_message) do
        # rubocop:disable Layout/LineLength -- Test Matrix table is too long
        # JWT Type | JWT Scope                        | Auth Mount | Expected Result | Error Message
        # ---------+----------------------------------+------------+-----------------|------------------------------------------------------------------------------------------------
        :global    | :same_project                    | :global    | :success        | nil
        :global    | :same_project                    | :user      | :rejected       | 'blocked authorization with message: invalid subject for user authentication'
        :global    | :same_project                    | :pipeline  | :rejected       | 'blocked authorization with message: invalid subject for pipeline authentication'
        # ---------+----------------------------------+------------+-----------------|-----------------------------------------------------------------------------------------------
        # ---------+----------------------------------+------------+-----------------|-----------------------------------------------------------------------------------------------
        :user      | :same_project                    | :user      | :success        | nil
        :user      | :same_project                    | :global    | :rejected       | 'error validating token: invalid subject (sub) claim'
        :user      | :same_project                    | :pipeline  | :rejected       | 'blocked authorization with message: invalid subject for pipeline authentication'
        :user      | :project_in_same_namespace       | :user      | :rejected       | 'blocked authorization with message: token project_id does not match role base'
        :user      | :project_in_different_namespace  | :user      | :rejected       | 'blocked authorization with message: token project_id does not match role base'
        :user      | :forked_project                  | :user      | :rejected       | 'blocked authorization with message: token project_id does not match role base'
        # ---------+----------------------------------+------------+-----------------|------------------------------------------------------------------------------------------------
        # CEL Pipeline Authentication
        :pipeline  | :same_project                    | :pipeline  | :success        | nil
        :pipeline  | :same_project                    | :global    | :rejected       | 'error validating token: invalid subject (sub) claim'
        :pipeline  | :same_project                    | :user      | :rejected       | 'blocked authorization with message: invalid subject for user authentication'
        :pipeline  | :project_in_same_namespace       | :pipeline  | :rejected       | 'blocked authorization with message: token project_id does not match project'
        :pipeline  | :project_in_different_namespace  | :pipeline  | :rejected       | 'blocked authorization with message: token project_id does not match project'
        :pipeline  | :forked_project                  | :pipeline  | :rejected       | 'blocked authorization with message: token project_id does not match project'
        :pipeline  | :forked_project_with_pipeline_running_in_parent_project | :pipeline | :rejected | 'blocked authorization with message: token project_id does not match project'
        # ---------+----------------------------------+------------+-----------------|-----------------------------------------------------------------------------------------------
        # CEL API Authentication
        :api       | :same_project                    | :api       | :success        | nil
        :api       | :same_project                    | :user      | :rejected       | 'blocked authorization with message: invalid secrets_manager_scope'
        :api       | :same_project                    | :pipeline  | :rejected       | 'blocked authorization with message: invalid subject for pipeline authentication'
        :api       | :project_in_same_namespace       | :api       | :rejected       | 'blocked authorization with message: token project_id does not match role base'
        :api       | :project_in_different_namespace  | :api       | :rejected       | 'blocked authorization with message: token project_id does not match role base'
        :user      | :same_project                    | :api       | :rejected       | 'blocked authorization with message: invalid secrets_manager_scope'
        :pipeline  | :same_project                    | :api       | :rejected       | 'blocked authorization with message: invalid subject for user authentication'
        # rubocop:enable Layout/LineLength
      end

      with_them do
        let(:jwt) do
          case jwt_scope
          when :same_project
            case jwt_type
            when :user
              build_user_jwt(user: project_owner, project: project)
            when :api
              build_api_jwt(user: project_owner, project: project)
            when :pipeline
              project_secrets_manager.ci_jwt(project_build)
            when :global
              build_secrets_manager_jwt(user: project_owner, project: project)
            end
          when :project_in_same_namespace
            case jwt_type
            when :user
              build_user_jwt(user: project_owner, project: project_in_same_namespace)
            when :api
              build_api_jwt(user: project_owner, project: project_in_same_namespace)
            when :pipeline
              secrets_manager_of_project_in_same_namespace.ci_jwt(build_of_project_in_same_namespace)
            when :global
              build_secrets_manager_jwt(user: project_owner, project: project_in_same_namespace)
            end
          when :project_in_different_namespace
            case jwt_type
            when :user
              build_user_jwt(user: project_owner, project: project_in_different_namespace)
            when :api
              build_api_jwt(user: project_owner, project: project_in_different_namespace)
            when :pipeline
              secrets_manager_of_project_in_different_namespace.ci_jwt(build_of_project_in_different_namespace)
            when :global
              build_secrets_manager_jwt(user: project_owner, project: project_in_different_namespace)
            end
          when :forked_project
            case jwt_type
            when :user
              build_user_jwt(user: project_owner, project: forked_project)
            when :pipeline
              secrets_manager_of_forked_project.ci_jwt(forked_project_build_running_in_forked_project)
            when :global
              build_secrets_manager_jwt(user: project_owner, project: forked_project)
            end
          when :forked_project_with_pipeline_running_in_parent_project
            case jwt_type
            when :pipeline
              secrets_manager_of_forked_project.ci_jwt(forked_project_build_running_in_original_project)
            end
          end
        end

        let(:client) do
          mount_config = case auth_mount
                         when :global
                           { auth_mount: 'gitlab_rails_jwt' }
                         when :user
                           {
                             auth_mount: project_secrets_manager.user_auth_mount,
                             role: project_secrets_manager.user_auth_role,
                             use_cel_auth: true,
                             auth_namespace: project_secrets_manager.full_project_namespace_path,
                             namespace: project_secrets_manager.full_project_namespace_path
                           }
                         when :api
                           {
                             auth_mount: project_secrets_manager.api_auth_mount,
                             role: project_secrets_manager.api_auth_role,
                             use_cel_auth: true,
                             auth_namespace: project_secrets_manager.full_project_namespace_path,
                             namespace: project_secrets_manager.full_project_namespace_path
                           }
                         when :pipeline
                           {
                             auth_mount: project_secrets_manager.ci_auth_mount,
                             role: project_secrets_manager.ci_auth_role,
                             use_cel_auth: true,
                             namespace: project_secrets_manager.full_project_namespace_path,
                             auth_namespace: project_secrets_manager.full_project_namespace_path
                           }
                         end

          SecretsManagement::TestClient.new(jwt: jwt, **mount_config)
        end

        it "validates authentication boundary" do
          result = client.jwt_login

          if expected_result == :success
            expect(result[:success]).to be(true)
            expect(result[:token]).to be_present
          else
            expect(result[:success]).to be(false)
            expect(result[:error]).to include(errror_message)
          end
        end
      end
    end

    context 'with group-level authentication' do
      using RSpec::Parameterized::TableSyntax

      # Group-specific resources
      # Group hierarchy:
      #
      # root_group
      #   - subgroup
      #       - project_in_subgroup
      #       - child_subgroup
      #         - project_in_child_subgroup
      #   - sibling_group
      #       - project_in_sibling_group
      #
      # unrelated_group
      #   - project_in_unrelated_group

      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: root_group) }
      let_it_be(:child_subgroup) { create(:group, parent: subgroup) }
      let_it_be(:sibling_group) { create(:group, parent: root_group) }
      let_it_be(:unrelated_group) { create(:group) }

      let_it_be(:project_in_root_group) { create(:project, :repository, namespace: root_group) }
      let_it_be(:project_in_subgroup) { create(:project, :repository, namespace: subgroup) }
      let_it_be(:project_in_child_subgroup) { create(:project, :repository, namespace: child_subgroup) }
      let_it_be(:project_in_sibling_group) { create(:project, :repository, namespace: sibling_group) }
      let_it_be(:project_in_unrelated_group) { create(:project, :repository, namespace: unrelated_group) }
      let_it_be(:forked_project_from_subgroup) { fork_project(project_in_subgroup, subgroup_owner, repository: true) }

      let_it_be(:root_group_owner) { create(:user, owner_of: root_group) }
      let_it_be(:subgroup_owner) { create(:user, owner_of: subgroup) }
      let_it_be(:child_subgroup_owner) { create(:user, owner_of: child_subgroup) }
      let_it_be(:unrelated_group_user) { create(:user, owner_of: unrelated_group) }

      let_it_be_with_reload(:root_group_secrets_manager) { create(:group_secrets_manager, group: root_group) }
      let_it_be_with_reload(:subgroup_secrets_manager) { create(:group_secrets_manager, group: subgroup) }

      # Group pipelines
      let_it_be(:pipeline_in_root_group_project) do
        create(:ci_pipeline, project: project_in_root_group, sha: project_in_root_group.commit.id,
          ref: project_in_root_group.default_branch, status: 'success', user: root_group_owner)
      end

      let_it_be(:pipeline_in_subgroup_project) do
        create(:ci_pipeline, project: project_in_subgroup, sha: project_in_subgroup.commit.id,
          ref: project_in_subgroup.default_branch, status: 'success', user: subgroup_owner)
      end

      let_it_be(:pipeline_in_child_subgroup_project) do
        create(:ci_pipeline, project: project_in_child_subgroup, sha: project_in_child_subgroup.commit.id,
          ref: project_in_child_subgroup.default_branch, status: 'success', user: child_subgroup_owner)
      end

      let_it_be(:pipeline_in_sibling_group_project) do
        create(:ci_pipeline, project: project_in_sibling_group, sha: project_in_sibling_group.commit.id,
          ref: project_in_sibling_group.default_branch, status: 'success', user: root_group_owner)
      end

      let_it_be(:pipeline_in_unrelated_group_project) do
        create(:ci_pipeline, project: project_in_unrelated_group, sha: project_in_unrelated_group.commit.id,
          ref: project_in_unrelated_group.default_branch, status: 'success', user: root_group_owner)
      end

      let_it_be(:forked_project_pipeline) do
        create(:ci_pipeline, project: forked_project_from_subgroup, sha: forked_project_from_subgroup.commit.id,
          ref: forked_project_from_subgroup.default_branch, status: 'success', user: subgroup_owner)
      end

      # Group builds
      let(:build_in_root_group_project) do
        create(:ee_ci_build, pipeline: pipeline_in_root_group_project, user: root_group_owner)
      end

      let(:build_in_subgroup_project) do
        create(:ee_ci_build, pipeline: pipeline_in_subgroup_project, user: subgroup_owner)
      end

      let(:build_in_child_subgroup_project) do
        create(:ee_ci_build, pipeline: pipeline_in_child_subgroup_project, user: child_subgroup_owner)
      end

      let(:build_in_sibling_group_project) do
        create(:ee_ci_build, pipeline: pipeline_in_sibling_group_project, user: root_group_owner)
      end

      let(:build_in_unrelated_group_project) do
        create(:ee_ci_build, pipeline: pipeline_in_unrelated_group_project, user: root_group_owner)
      end

      let(:forked_project_build) do
        create(:ee_ci_build, pipeline: forked_project_pipeline, user: subgroup_owner)
      end

      before do
        clean_all_kv_secrets_engines
        provision_group_secrets_manager(root_group_secrets_manager, root_group_owner)
        provision_group_secrets_manager(subgroup_secrets_manager, subgroup_owner)
      end

      where(:jwt_type, :jwt_scope, :auth_mount, :expected_result, :errror_message) do
        # rubocop:disable Layout/LineLength -- Test Matrix table is too long
        # JWT Type        | JWT Scope                          | Auth Mount      | Expected Result | Error Message
        # ----------------+------------------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Group Secrets - Global JWT
        :group_global     | :same_group                        | :group_global   | :success        | nil
        :group_global     | :same_group                        | :group_user     | :rejected       | 'blocked authorization with message: invalid subject for user authentication'
        :group_global     | :same_group                        | :group_pipeline | :rejected       | 'blocked authorization with message: invalid subject for pipeline authentication'
        # ----------------+------------------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Group Secrets - User JWT
        :group_user       | :user_in_group                     | :group_user     | :success        | nil
        :group_user       | :user_in_subgroup_via_inheritance  | :group_user     | :success        | nil
        :group_user       | :same_group                        | :group_global   | :rejected       | 'error validating token: invalid subject (sub) claim'
        :group_user       | :same_group                        | :group_pipeline | :rejected       | 'blocked authorization with message: invalid subject for pipeline authentication'
        :group_user       | :user_in_unrelated_group           | :group_user     | :rejected       | 'blocked authorization with message: token group_id does not match group'
        # ----------------+------------------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Group Secrets - Pipeline JWT (project_group_ids validation)
        :group_pipeline   | :project_in_own_group              | :group_pipeline | :success        | nil
        :group_pipeline   | :project_in_child_group            | :group_pipeline | :success        | nil
        :group_pipeline   | :project_in_grandchild_group       | :group_pipeline | :success        | nil
        :group_pipeline   | :project_in_own_group              | :group_global   | :rejected       | 'error validating token: invalid subject (sub) claim'
        :group_pipeline   | :project_in_own_group              | :group_user     | :rejected       | 'blocked authorization with message: invalid subject for user authentication'
        :group_pipeline   | :project_in_sibling_group          | :group_pipeline | :rejected       | 'blocked authorization with message: project does not belong to group'
        :group_pipeline   | :project_in_unrelated_group        | :group_pipeline | :rejected       | 'blocked authorization with message: project does not belong to group'
        :group_pipeline   | :project_in_parent_group           | :group_pipeline | :rejected       | 'blocked authorization with message: project does not belong to group'
        :group_pipeline   | :forked_project_to_group           | :group_pipeline | :rejected       | 'blocked authorization with message: project does not belong to group'
        :group_pipeline   | :project_missing_group_ids_claim   | :group_pipeline | :rejected       | 'blocked authorization with message: missing project_group_ids claim'
        # ----------------+------------------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Group Secrets - API JWT
        :group_api        | :same_group                        | :group_api      | :success        | nil
        :group_api        | :same_group                        | :group_user     | :rejected       | 'blocked authorization with message: invalid secrets_manager_scope'
        :group_user       | :same_group                        | :group_api      | :rejected       | 'blocked authorization with message: invalid secrets_manager_scope'
        :group_api        | :user_in_unrelated_group           | :group_api      | :rejected       | 'blocked authorization with message: token group_id does not match group'
        # rubocop:enable Layout/LineLength
      end

      with_them do
        let(:jwt) do
          case jwt_scope
          when :same_group
            case jwt_type
            when :group_user
              build_group_user_jwt(user: root_group_owner, group: root_group)
            when :group_pipeline
              root_group_secrets_manager.ci_jwt(build_in_root_group_project)
            when :group_global
              build_group_secrets_manager_jwt(user: root_group_owner, group: root_group)
            when :group_api
              build_group_api_jwt(user: root_group_owner, group: root_group)
            end
          when :project_in_own_group
            root_group_secrets_manager.ci_jwt(build_in_root_group_project)
          when :project_in_child_group
            root_group_secrets_manager.ci_jwt(build_in_subgroup_project)
          when :project_in_grandchild_group
            root_group_secrets_manager.ci_jwt(build_in_child_subgroup_project)
          when :project_in_sibling_group
            subgroup_secrets_manager.ci_jwt(build_in_sibling_group_project)
          when :project_in_unrelated_group
            root_group_secrets_manager.ci_jwt(build_in_unrelated_group_project)
          when :project_in_parent_group
            subgroup_secrets_manager.ci_jwt(build_in_root_group_project)
          when :forked_project_to_group
            subgroup_secrets_manager.ci_jwt(forked_project_build)
          when :project_missing_group_ids_claim
            JWT.encode(
              {
                iss: SecretsManagement::GroupSecretsManager.jwt_issuer,
                aud: SecretsManagement::GroupSecretsManager.jwt_audience,
                iat: Time.now.to_i,
                exp: Time.now.to_i + 600,
                user_id: root_group_owner.id.to_s,
                project_id: project_in_subgroup.id.to_s,
                namespace_id: subgroup.id.to_s,
                sub: "project_path:#{project_in_subgroup.full_path}:ref_type:branch:ref:main",
                secrets_manager_scope: 'pipeline'
              },
              OpenSSL::PKey::RSA.new(Gitlab::CurrentSettings.ci_jwt_signing_key),
              'RS256'
            )
          when :user_in_group
            build_group_user_jwt(user: root_group_owner, group: root_group)
          when :user_in_subgroup_via_inheritance
            build_group_user_jwt(user: root_group_owner, group: subgroup)
          when :user_in_unrelated_group
            if jwt_type == :group_api
              build_group_api_jwt(user: unrelated_group_user, group: unrelated_group)
            else
              build_group_user_jwt(user: unrelated_group_user, group: unrelated_group)
            end
          end
        end

        let(:client) do
          mount_config = case auth_mount
                         when :group_global
                           { auth_mount: 'gitlab_rails_jwt' }
                         when :group_user
                           secrets_mgr = if jwt_scope == :user_in_subgroup_via_inheritance
                                           subgroup_secrets_manager
                                         else
                                           root_group_secrets_manager
                                         end

                           {
                             auth_mount: secrets_mgr.user_auth_mount,
                             role: secrets_mgr.user_auth_role,
                             use_cel_auth: true,
                             auth_namespace: secrets_mgr.full_group_namespace_path,
                             namespace: secrets_mgr.full_group_namespace_path
                           }
                         when :group_pipeline
                           # Use subgroup for most tests, but switch based on scope
                           secrets_mgr = case jwt_scope
                                         when :project_in_own_group, :project_in_child_group,
                                           :project_in_grandchild_group, :project_in_unrelated_group
                                           root_group_secrets_manager
                                         else
                                           subgroup_secrets_manager
                                         end
                           {
                             auth_mount: secrets_mgr.ci_auth_mount,
                             role: secrets_mgr.ci_auth_role,
                             use_cel_auth: true,
                             auth_namespace: secrets_mgr.full_group_namespace_path,
                             namespace: secrets_mgr.full_group_namespace_path
                           }
                         when :group_api
                           {
                             auth_mount: root_group_secrets_manager.api_auth_mount,
                             role: root_group_secrets_manager.api_auth_role,
                             use_cel_auth: true,
                             auth_namespace: root_group_secrets_manager.full_group_namespace_path,
                             namespace: root_group_secrets_manager.full_group_namespace_path
                           }
                         end

          SecretsManagement::TestClient.new(jwt: jwt, **mount_config)
        end

        it "validates authentication boundary" do
          result = client.jwt_login

          if expected_result == :success
            expect(result[:success]).to be(true)
            expect(result[:token]).to be_present
          else
            expect(result[:success]).to be(false)
            expect(result[:error]).to include(errror_message)
          end
        end
      end
    end

    context 'with cross-type authentication (project vs group isolation)' do
      using RSpec::Parameterized::TableSyntax

      # Cross-type resources (minimal setup for isolation tests)
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:project) { create(:project, :repository, namespace: namespace) }
      let_it_be(:project_owner) { create(:user, owner_of: project) }
      let_it_be_with_refind(:project_secrets_manager) { create(:project_secrets_manager, project: project) }

      let_it_be(:root_group) { create(:group) }
      let_it_be(:project_in_root_group) { create(:project, :repository, namespace: root_group) }
      let_it_be(:root_group_owner) { create(:user, owner_of: root_group) }
      let_it_be_with_reload(:root_group_secrets_manager) { create(:group_secrets_manager, group: root_group) }

      let_it_be_with_refind(:project_pipeline) do
        create(
          :ci_pipeline,
          project: project,
          sha: project.commit.id,
          ref: project.default_branch,
          status: 'success',
          user: project_owner
        )
      end

      let_it_be(:pipeline_in_root_group_project) do
        create(:ci_pipeline, project: project_in_root_group, sha: project_in_root_group.commit.id,
          ref: project_in_root_group.default_branch, status: 'success', user: root_group_owner)
      end

      let(:project_build) { create(:ee_ci_build, pipeline: project_pipeline, user: project_owner) }
      let(:build_in_root_group_project) do
        create(:ee_ci_build, pipeline: pipeline_in_root_group_project, user: root_group_owner)
      end

      before do
        clean_all_kv_secrets_engines
        # Provision both project and group secrets managers
        provision_project_secrets_manager(project_secrets_manager, project_owner)
        provision_group_secrets_manager(root_group_secrets_manager, root_group_owner)
      end

      where(:jwt_type, :jwt_scope, :auth_mount, :expected_result, :errror_message) do
        # rubocop:disable Layout/LineLength -- Test Matrix table is too long
        # JWT Type        | JWT Scope             | Auth Mount      | Expected Result | Error Message
        # ----------------+-----------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Group JWTs trying to access Project mounts
        :group_pipeline   | :project_in_own_group | :pipeline       | :rejected       | 'blocked authorization with message: token project_id does not match project'
        :group_user       | :user_in_group        | :user           | :rejected       | 'blocked authorization with message: missing project_id'
        :group_global     | :same_group           | :global         | :success        | nil
        # ----------------+-----------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------
        # Project JWTs trying to access Group mounts
        :pipeline         | :same_project         | :group_pipeline | :rejected       | 'blocked authorization with message: missing project_group_ids claim'
        :user             | :same_project         | :group_user     | :rejected       | 'blocked authorization with message: missing group_id'
        :global           | :same_project         | :group_global   | :success        | nil
        # rubocop:enable Layout/LineLength
      end

      with_them do
        let(:jwt) do
          case jwt_scope
          when :same_project
            case jwt_type
            when :user
              build_user_jwt(user: project_owner, project: project)
            when :pipeline
              project_secrets_manager.ci_jwt(project_build)
            when :global
              build_secrets_manager_jwt(user: project_owner, project: project)
            end
          when :same_group, :user_in_group
            case jwt_type
            when :group_user
              build_group_user_jwt(user: root_group_owner, group: root_group)
            when :group_global
              build_group_secrets_manager_jwt(user: root_group_owner, group: root_group)
            end
          when :project_in_own_group
            root_group_secrets_manager.ci_jwt(build_in_root_group_project)
          end
        end

        let(:client) do
          mount_config = case auth_mount
                         when :global, :group_global
                           { auth_mount: 'gitlab_rails_jwt' }
                         when :user
                           {
                             auth_mount: project_secrets_manager.user_auth_mount,
                             role: project_secrets_manager.user_auth_role,
                             use_cel_auth: true,
                             auth_namespace: project_secrets_manager.full_project_namespace_path,
                             namespace: project_secrets_manager.full_project_namespace_path
                           }
                         when :pipeline
                           {
                             auth_mount: project_secrets_manager.ci_auth_mount,
                             role: project_secrets_manager.ci_auth_role,
                             use_cel_auth: true,
                             namespace: project_secrets_manager.full_project_namespace_path,
                             auth_namespace: project_secrets_manager.full_project_namespace_path
                           }
                         when :group_user
                           {
                             auth_mount: root_group_secrets_manager.user_auth_mount,
                             role: root_group_secrets_manager.user_auth_role,
                             use_cel_auth: true,
                             auth_namespace: root_group_secrets_manager.full_group_namespace_path,
                             namespace: root_group_secrets_manager.full_group_namespace_path
                           }
                         when :group_pipeline
                           {
                             auth_mount: root_group_secrets_manager.ci_auth_mount,
                             role: root_group_secrets_manager.ci_auth_role,
                             use_cel_auth: true,
                             auth_namespace: root_group_secrets_manager.full_group_namespace_path,
                             namespace: root_group_secrets_manager.full_group_namespace_path
                           }
                         end

          SecretsManagement::TestClient.new(jwt: jwt, **mount_config)
        end

        it "validates authentication boundary" do
          result = client.jwt_login

          if expected_result == :success
            expect(result[:success]).to be(true)
            expect(result[:token]).to be_present
          else
            expect(result[:success]).to be(false)
            expect(result[:error]).to include(errror_message)
          end
        end
      end
    end

    context 'with group pipeline authentication using environment and protected ref claims' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:project_in_root_group) { create(:project, :repository, namespace: root_group) }
      let_it_be(:root_group_owner) { create(:user, owner_of: root_group) }
      let_it_be_with_reload(:root_group_secrets_manager) { create(:group_secrets_manager, group: root_group) }
      let_it_be(:environment) { create(:environment, project: project_in_root_group, name: 'production') }

      let_it_be(:pipeline_in_root_group_project) do
        create(:ci_pipeline, project: project_in_root_group, sha: project_in_root_group.commit.id,
          ref: project_in_root_group.default_branch, status: 'success', user: root_group_owner)
      end

      let(:build_with_environment) do
        create(:ee_ci_build, :with_deployment, pipeline: pipeline_in_root_group_project,
          user: root_group_owner, environment: environment.name)
      end

      before do
        clean_all_kv_secrets_engines
        provision_group_secrets_manager(root_group_secrets_manager, root_group_owner)
      end

      it 'authenticates and returns environment-based policy when environment claim is present' do
        jwt = root_group_secrets_manager.ci_jwt(build_with_environment)

        client = secrets_manager_client.with_namespace(root_group_secrets_manager.full_group_namespace_path)
        resp = client.cel_login_jwt(
          mount_path: root_group_secrets_manager.ci_auth_mount,
          role: root_group_secrets_manager.ci_auth_role,
          jwt: jwt
        )

        expect(resp.dig('auth', 'client_token')).to be_present

        policies = resp.dig('auth', 'policies')
        expect(policies).to include('pipelines/combined/unprotected/global')

        env_hex = 'production'.unpack1('H*')
        expect(policies).to include("pipelines/combined/unprotected/env/#{env_hex}")
      end

      it 'authenticates and returns both protected and unprotected global policies when build is protected' do
        protected_build = create(:ee_ci_build, :protected, pipeline: pipeline_in_root_group_project,
          user: root_group_owner)
        jwt = root_group_secrets_manager.ci_jwt(protected_build)

        client = secrets_manager_client.with_namespace(root_group_secrets_manager.full_group_namespace_path)
        resp = client.cel_login_jwt(
          mount_path: root_group_secrets_manager.ci_auth_mount,
          role: root_group_secrets_manager.ci_auth_role,
          jwt: jwt
        )

        expect(resp.dig('auth', 'client_token')).to be_present

        policies = resp.dig('auth', 'policies')
        expect(policies).to include('pipelines/combined/protected/global')
        expect(policies).to include('pipelines/combined/unprotected/global')
      end

      it 'authenticates and returns protected and unprotected global+env policies when both claims are present' do
        protected_build_with_env = create(:ee_ci_build, :protected, :with_deployment,
          pipeline: pipeline_in_root_group_project, user: root_group_owner, environment: environment.name)
        jwt = root_group_secrets_manager.ci_jwt(protected_build_with_env)

        client = secrets_manager_client.with_namespace(root_group_secrets_manager.full_group_namespace_path)
        resp = client.cel_login_jwt(
          mount_path: root_group_secrets_manager.ci_auth_mount,
          role: root_group_secrets_manager.ci_auth_role,
          jwt: jwt
        )

        expect(resp.dig('auth', 'client_token')).to be_present

        env_hex = 'production'.unpack1('H*')
        policies = resp.dig('auth', 'policies')
        expect(policies).to include('pipelines/combined/protected/global')
        expect(policies).to include('pipelines/combined/unprotected/global')
        expect(policies).to include("pipelines/combined/protected/env/#{env_hex}")
        expect(policies).to include("pipelines/combined/unprotected/env/#{env_hex}")
      end
    end
  end

  describe 'JWT Authorization Scenarios' do
    # Project authorization resources
    let_it_be(:namespace) { create(:namespace) }
    let_it_be_with_reload(:project) { create(:project, :repository, namespace: namespace) }
    let_it_be(:project_in_same_namespace) { create(:project, :repository, namespace: namespace) }
    let_it_be(:project_owner) { create(:user, owner_of: project) }
    let_it_be(:forked_project_owner) { project_owner }
    let_it_be(:project_developer) { create(:user, developer_of: project) }
    let_it_be(:owner_of_project_in_same_namespace) { create(:user, owner_of: project_in_same_namespace) }

    let_it_be(:forked_project) { fork_project(project, project_owner, repository: true) }

    let_it_be_with_refind(:project_secrets_manager) { create(:project_secrets_manager, project: project) }
    let_it_be_with_refind(:secrets_manager_of_project_in_same_namespace) do
      create(:project_secrets_manager, project: project_in_same_namespace)
    end

    let_it_be_with_refind(:secrets_manager_of_forked_project) do
      create(:project_secrets_manager, project: forked_project)
    end

    let_it_be(:merge_request) do
      create(:merge_request, source_project: forked_project, source_branch: 'feature', target_project: project,
        target_branch: 'master')
    end

    let_it_be_with_refind(:project_pipeline) do
      create(
        :ci_pipeline,
        project: project,
        sha: project.commit.id,
        ref: project.default_branch,
        status: 'success',
        user: project_developer
      )
    end

    let_it_be_with_refind(:pipeline_of_project_in_same_namespace) do
      create(
        :ci_pipeline,
        project: project_in_same_namespace,
        sha: project_in_same_namespace.commit.id,
        ref: project_in_same_namespace.default_branch,
        status: 'success',
        user: owner_of_project_in_same_namespace
      )
    end

    let_it_be_with_refind(:merge_request_pipeline_from_forked_project_running_in_original_project) do
      create(
        :ci_pipeline,
        source: :merge_request_event,
        merge_request: merge_request,
        project: project,
        ref: merge_request.ref_path,
        status: 'success',
        user: project_owner
      )
    end

    let_it_be_with_refind(:merge_request_pipeline_from_forked_project_running_in_forked_project) do
      create(
        :ci_pipeline,
        source: :merge_request_event,
        merge_request: merge_request,
        project: forked_project,
        ref: merge_request.ref_path,
        status: 'success',
        user: project_owner
      )
    end

    let(:project_build) { create(:ee_ci_build, pipeline: project_pipeline, user: project_developer) }
    let(:build_of_project_in_same_namespace) do
      create(:ee_ci_build, pipeline: pipeline_of_project_in_same_namespace, user: owner_of_project_in_same_namespace)
    end

    let(:forked_project_build_running_in_original_project) do
      create(:ee_ci_build, pipeline: merge_request_pipeline_from_forked_project_running_in_original_project,
        user: project_owner)
    end

    let(:forked_project_build_running_in_forked_project) do
      create(:ee_ci_build, pipeline: merge_request_pipeline_from_forked_project_running_in_forked_project,
        user: project_owner)
    end

    let(:project_owner_client) do
      SecretsManagement::TestClient.new(
        jwt: build_user_jwt(user: project_owner, project: project),
        auth_mount: project_secrets_manager.user_auth_mount,
        role: project_secrets_manager.user_auth_role,
        use_cel_auth: true,
        auth_namespace: project_secrets_manager.full_project_namespace_path,
        namespace: project_secrets_manager.full_project_namespace_path
      )
    end

    let(:project_developer_client) do
      SecretsManagement::TestClient.new(
        jwt: build_user_jwt(user: project_developer, project: project),
        auth_mount: project_secrets_manager.user_auth_mount,
        role: project_secrets_manager.user_auth_role,
        use_cel_auth: true,
        auth_namespace: project_secrets_manager.full_project_namespace_path,
        namespace: project_secrets_manager.full_project_namespace_path
      )
    end

    let(:project_pipeline_client) do
      SecretsManagement::TestClient.new(
        jwt: project_secrets_manager.ci_jwt(project_build),
        auth_mount: project_secrets_manager.ci_auth_mount,
        role: project_secrets_manager.ci_auth_role,
        use_cel_auth: true,
        auth_namespace: project_secrets_manager.full_project_namespace_path,
        namespace: project_secrets_manager.full_project_namespace_path
      )
    end

    let(:project_pipeline_client_with_user_defined_jwt) do
      SecretsManagement::TestClient.new(
        jwt: Gitlab::Ci::JwtV2.for_build(project_build, aud: project_secrets_manager.class.jwt_audience),
        auth_mount: project_secrets_manager.ci_auth_mount,
        role: project_secrets_manager.ci_auth_role,
        use_cel_auth: true,
        auth_namespace: project_secrets_manager.full_project_namespace_path,
        namespace: project_secrets_manager.full_project_namespace_path
      )
    end

    let(:pipeline_client_of_project_in_same_namespace) do
      SecretsManagement::TestClient.new(
        jwt: secrets_manager_of_project_in_same_namespace.ci_jwt(build_of_project_in_same_namespace),
        auth_mount: secrets_manager_of_project_in_same_namespace.ci_auth_mount,
        role: secrets_manager_of_project_in_same_namespace.ci_auth_role,
        use_cel_auth: true,
        auth_namespace: secrets_manager_of_project_in_same_namespace.full_project_namespace_path,
        namespace: secrets_manager_of_project_in_same_namespace.full_project_namespace_path
      )
    end

    let(:pipeline_client_of_forked_project_running_in_forked_project) do
      SecretsManagement::TestClient.new(
        jwt: secrets_manager_of_forked_project.ci_jwt(forked_project_build_running_in_forked_project),
        auth_mount: secrets_manager_of_forked_project.ci_auth_mount,
        role: secrets_manager_of_forked_project.ci_auth_role,
        use_cel_auth: true,
        auth_namespace: secrets_manager_of_forked_project.full_project_namespace_path,
        namespace: secrets_manager_of_forked_project.full_project_namespace_path
      )
    end

    let(:pipeline_client_of_forked_project_running_in_original_project) do
      SecretsManagement::TestClient.new(
        jwt: secrets_manager_of_forked_project.ci_jwt(forked_project_build_running_in_original_project),
        auth_mount: secrets_manager_of_forked_project.ci_auth_mount,
        role: secrets_manager_of_forked_project.ci_auth_role,
        use_cel_auth: true,
        auth_namespace: secrets_manager_of_forked_project.full_project_namespace_path,
        namespace: secrets_manager_of_forked_project.full_project_namespace_path
      )
    end

    let(:base_secrets_manager_client) do
      SecretsManagement::SecretsManagerClient.new(
        jwt: build_secrets_manager_jwt(user: project_owner, project: project)
      )
    end

    shared_examples 'permission denied' do
      it 'raises permission denied error' do
        expect { subject }.to raise_error { |error|
          expect(error).to be_a SecretsManagement::SecretsManagerClient::ApiError
          expect(error.message).to include("permission denied")
        }
      end
    end

    context 'for actions that can only be done by secrets_manager_jwt' do
      before do
        clean_all_kv_secrets_engines
        provision_project_secrets_manager(project_secrets_manager, project_owner)
      end

      it 'enables reading project policies using ProjectSecretsManagerJwt' do
        expect(base_secrets_manager_client.list_project_policies(project_id: project.id)).to be_an(Array)
      end

      context 'when using pipeline_jwt' do
        subject do
          project_pipeline_client.list_project_policies(project_id: project.id)
        end

        it_behaves_like 'permission denied'
      end

      context 'when using user_jwt' do
        subject do
          project_owner_client.list_project_policies(project_id: project.id)
        end

        it_behaves_like 'permission denied'
      end
    end
  end

  describe 'Group JWT Authorization Scenarios' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project_in_group) { create(:project, :repository, namespace: group) }
    let_it_be(:group_owner) { create(:user, owner_of: group) }
    let_it_be_with_reload(:group_secrets_manager) { create(:group_secrets_manager, group: group) }

    let_it_be(:pipeline_in_group_project) do
      create(:ci_pipeline, project: project_in_group, sha: project_in_group.commit.id,
        ref: project_in_group.default_branch, status: 'success', user: group_owner)
    end

    let(:group_build) { create(:ee_ci_build, pipeline: pipeline_in_group_project, user: group_owner) }

    let(:group_secrets_manager_jwt_client) do
      jwt = build_group_secrets_manager_jwt(user: group_owner, group: group)
      SecretsManagement::TestClient.new(
        jwt: jwt,
        namespace: group_secrets_manager.full_group_namespace_path
      )
    end

    let(:group_pipeline_client) do
      SecretsManagement::TestClient.new(
        jwt: group_secrets_manager.ci_jwt(group_build),
        auth_mount: group_secrets_manager.ci_auth_mount,
        role: group_secrets_manager.ci_auth_role,
        use_cel_auth: true,
        auth_namespace: group_secrets_manager.full_group_namespace_path,
        namespace: group_secrets_manager.full_group_namespace_path
      )
    end

    let(:group_user_client) do
      jwt = build_group_user_jwt(user: group_owner, group: group)
      SecretsManagement::TestClient.new(
        jwt: jwt,
        auth_mount: group_secrets_manager.user_auth_mount,
        role: group_secrets_manager.user_auth_role,
        use_cel_auth: true,
        auth_namespace: group_secrets_manager.full_group_namespace_path,
        namespace: group_secrets_manager.full_group_namespace_path
      )
    end

    before_all do
      group.add_owner(group_owner)
    end

    shared_examples 'group permission denied' do
      it 'raises permission denied error' do
        expect { subject }.to raise_error { |error|
          expect(error).to be_a SecretsManagement::SecretsManagerClient::ApiError
          expect(error.message).to include("permission denied")
        }
      end
    end

    context 'for actions that can only be done by group_secrets_manager_jwt' do
      before do
        clean_all_kv_secrets_engines
        provision_group_secrets_manager(group_secrets_manager, group_owner)
      end

      it 'enables listing policies using GroupSecretsManagerJwt' do
        policies = group_secrets_manager_jwt_client.list_policies

        expect(policies).to be_an(Array)
      end

      context 'when using pipeline_jwt' do
        subject do
          group_pipeline_client.list_policies
        end

        it_behaves_like 'group permission denied'
      end

      context 'when using user_jwt' do
        subject do
          group_user_client.list_policies
        end

        it_behaves_like 'group permission denied'
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
