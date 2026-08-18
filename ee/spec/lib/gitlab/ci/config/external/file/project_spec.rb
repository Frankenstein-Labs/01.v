# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::External::File::Project, feature_category: :pipeline_composition do
  include RepoHelpers

  let_it_be(:context_project) { create(:project) }
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:context_user) { user }
  let(:context) { Gitlab::Ci::Config::External::Context.new(**context_params) }
  let(:project_file) { described_class.new(params, context) }
  let(:pipeline_policy_context) { nil }
  let(:context_params) do
    {
      project: context_project,
      sha: project.commit.sha,
      user: context_user,
      pipeline_policy_context: pipeline_policy_context
    }
  end

  before do
    allow_next_instance_of(Gitlab::Ci::Config::External::Context) do |instance|
      allow(instance).to receive(:check_execution_time!)
    end
  end

  describe '#valid?' do
    subject(:valid?) do
      Gitlab::Ci::Config::External::Mapper::Verifier.new(context).process([project_file])
      project_file.valid?
    end

    describe 'security_policy_management_project_access_allowed?' do
      include_context 'with pipeline policy context'

      let(:params) { { file: 'pipeline-execution-policy.yml', project: project.full_path } }
      let(:creating_policy_pipeline) { true }

      around do |example|
        create_and_delete_files(project,
          { '/pipeline-execution-policy.yml' => { compliance_job: { script: 'test' } }.to_yaml }) do
          example.run
        end
      end

      shared_examples_for 'user has no access to the project' do
        it 'returns false' do
          expect(valid?).to be(false)
          expect(project_file.error_message).to include("Project `#{project.full_path}` not found or access denied!")
        end
      end

      shared_examples_for 'user has access to the project' do
        it 'returns true' do
          expect(valid?).to be(true)
        end
      end

      context 'when user does not have permission to access file' do
        let(:context_user) { create(:user) }

        it_behaves_like 'user has no access to the project'

        context 'and project is a security policy project' do
          let_it_be_with_reload(:security_orchestration_policy_configuration) do
            create(:security_orchestration_policy_configuration, security_policy_management_project: project,
              project: context_project)
          end

          it_behaves_like 'user has access to the project'

          context 'and project is linked to the context project as a security policy project' do
            before_all do
              security_orchestration_policy_configuration.update!(project: context_project)
            end

            it_behaves_like 'user has access to the project'

            context 'when user is authenticated via CI_JOB_TOKEN', :request_store do
              let(:parent_project) { build_stubbed(:project) }
              let(:job) { build_stubbed(:ci_build, project: parent_project, user: context_user) }

              before do
                context_user.set_ci_job_token_scope!(job)
              end

              it_behaves_like 'user has access to the project'
            end

            context 'when creating_policy_pipeline? is false' do
              let(:creating_policy_pipeline) { false }

              it_behaves_like 'user has no access to the project'
            end

            context 'when project forbids SPP repository access via project settings' do
              before do
                project.project_setting.update!(spp_repository_pipeline_access: false)
              end

              it_behaves_like 'user has no access to the project'
            end
          end
        end
      end
    end

    describe 'pipeline_execution_policy_file_access_allowed?' do
      include_context 'with pipeline policy context'

      let_it_be(:root_group) { create(:group) }
      let_it_be_with_reload(:target_project) { create(:project, :small_repo, group: root_group) }
      let_it_be(:requesting_project) { create(:project, group: root_group) }
      let_it_be(:requesting_project_policy_project) { create(:project, :small_repo, group: root_group) }
      let_it_be(:regular_user) { create(:user) }

      let_it_be(:requesting_project_policy_configuration) do
        create(:security_orchestration_policy_configuration,
          project: requesting_project,
          security_policy_management_project: requesting_project_policy_project)
      end

      # The requesting project must have a PEP policy linked to be in valid PEP context
      let_it_be(:requesting_project_pep_policy) do
        create(:security_policy, :pipeline_execution_policy,
          security_orchestration_policy_configuration: requesting_project_policy_configuration,
          linked_projects: [requesting_project])
      end

      let(:params) { { file: 'ci/policy.yml', project: target_project.full_path } }
      let(:creating_policy_pipeline) { true }
      let(:context_user) { regular_user }
      let(:context_project) { requesting_project }

      around do |example|
        create_and_delete_files(target_project,
          { '/ci/policy.yml' => { compliance_job: { script: 'test' } }.to_yaml }) do
          example.run
        end
      end

      shared_examples_for 'user has no access to the target project' do
        it 'is invalid and includes an access denied error', :aggregate_failures do
          expect(valid?).to be(false)
          expect(project_file.error_message).to include(
            "Project `#{target_project.full_path}` not found or access denied!"
          )
        end
      end

      shared_examples_for 'user has access to the target project' do
        specify { expect(valid?).to be(true) }
      end

      context 'when policy file access is not enabled' do
        it_behaves_like 'user has no access to the target project'
      end

      context 'when policy file access is enabled' do
        before do
          target_project.project_setting.update!(
            pipeline_execution_policy_bot_access_enabled: true,
            pipeline_execution_policy_bot_access_file_patterns: ['ci/**/*.yml']
          )
        end

        context 'with regular user' do
          it_behaves_like 'user has access to the target project'
        end

        context 'when validating multiple includes in the same request', :request_store do
          let(:additional_project_file) { described_class.new(params, context) }

          it 'caches access checks in SafeRequestStore' do
            Gitlab::Ci::Config::External::Mapper::Verifier.new(context).process([
              project_file,
              additional_project_file
            ])

            expect(project_file).to be_valid
            expect(additional_project_file).to be_valid

            # Verify caching by checking the SafeRequestStore contains the cached result
            cache_key = [
              'Ci::Config::External::File::Project',
              'pipeline_execution_policy_file_access_allowed',
              target_project.id,
              requesting_project.id,
              params[:file].to_s
            ]
            expect(Gitlab::SafeRequestStore.exist?(cache_key)).to be(true)
          end
        end

        context 'when context project is nil' do
          let(:context_project) { nil }

          it_behaves_like 'user has no access to the target project'
        end

        context 'when file does not match pattern' do
          let(:params) { { file: 'other/policy.yml', project: target_project.full_path } }

          around do |example|
            create_and_delete_files(target_project,
              { '/other/policy.yml' => { compliance_job: { script: 'test' } }.to_yaml }) do
              example.run
            end
          end

          it_behaves_like 'user has no access to the target project'
        end

        context 'when context project is outside allowed group hierarchy' do
          let_it_be(:other_group) { create(:group) }
          let_it_be(:outside_project, freeze: true) { create(:project, group: other_group) }

          let(:context_project) { outside_project }

          it_behaves_like 'user has no access to the target project'
        end

        context 'when user is a security policy bot' do
          let_it_be(:bot_user, freeze: true) { create(:user, :security_policy_bot) }

          let(:context_user) { bot_user }

          it_behaves_like 'user has access to the target project'
        end

        context 'when user has no membership in the requesting project' do
          let_it_be(:unrelated_user, freeze: true) { create(:user) }

          let(:context_user) { unrelated_user }

          it_behaves_like 'user has access to the target project'
        end

        context 'when creating_policy_pipeline? is false' do
          let(:creating_policy_pipeline) { false }

          it_behaves_like 'user has no access to the target project'
        end

        context 'when target project has internal visibility' do
          let_it_be_with_reload(:target_project) do
            create(:project, :small_repo, :internal, group: root_group)
          end

          it_behaves_like 'user has access to the target project'

          context 'when user is a security policy bot' do
            let_it_be(:bot_user) { create(:user, :security_policy_bot) }

            let(:context_user) { bot_user }

            it_behaves_like 'user has access to the target project'

            context 'when policy file access is not enabled' do
              before do
                target_project.project_setting.update!(pipeline_execution_policy_bot_access_enabled: false)
              end

              it_behaves_like 'user has no access to the target project'
            end
          end
        end
      end
    end
  end
end
