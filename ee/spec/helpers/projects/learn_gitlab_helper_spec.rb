# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::LearnGitlabHelper, feature_category: :onboarding do
  describe '#learn_gitlab_data' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { build_stubbed(:project, namespace: namespace) }

    let(:onboarding_actions_data) { Gitlab::Json.parse(learn_gitlab_data[:actions]).deep_symbolize_keys }
    let(:onboarding_sections_data) { Gitlab::Json.parse(learn_gitlab_data[:sections], symbolize_names: true) }
    let(:onboarding_project_data) { Gitlab::Json.parse(learn_gitlab_data[:project]).deep_symbolize_keys }

    before do
      ::Onboarding::Progress.onboard(namespace)
      ::Onboarding::Progress.register(namespace, :user_added)
      allow(helper).to receive(:current_user).and_return(user)
    end

    subject(:learn_gitlab_data) { helper.learn_gitlab_data(project) }

    shared_examples 'has all data' do
      it 'has all actions' do
        expected_keys = [
          :issue_created,
          :created,
          :pipeline_created,
          :merge_request_created,
          :user_added,
          :trial_started,
          :required_mr_approvals_enabled,
          :code_owners_enabled,
          :license_scanning_run,
          :secure_dependency_scanning_run,
          :secure_dast_run,
          :code_added
        ]

        expect(onboarding_actions_data.keys).to match_array(expected_keys)
      end

      it 'has all section data', :aggregate_failures do
        expect(onboarding_sections_data.map(&:keys)).to match_array([[:code], [:workspace, :plan, :deploy]])
        expect(onboarding_sections_data.first.values.map(&:keys)).to match_array([[:svg]])
        expect(onboarding_sections_data.second.values.map(&:keys)).to match_array([[:svg]] * 3)
      end

      it 'has all project data', :aggregate_failures do
        expect(onboarding_project_data.keys)
          .to contain_exactly(:name)

        expect(onboarding_project_data.values).to match_array([project.name])
      end

      it 'has the learn gitlab end path' do
        expect(learn_gitlab_data[:learn_gitlab_end_path])
          .to eq(end_tutorial_project_learn_gitlab_path(project))
      end
    end

    it_behaves_like 'has all data'

    it 'sets correct paths' do
      result = {
        trial_started: a_hash_including(url: %r{/#{project.path}/-/project_members\z}),
        pipeline_created: a_hash_including(url: %r{/#{project.path}/-/pipelines\z}),
        issue_created: a_hash_including(url: %r{/#{project.path}/-/work_items\z}),
        created: a_hash_including(url: %r{/#{project.path}\z}),
        user_added: a_hash_including(url: %r{#\z}),
        merge_request_created: a_hash_including(url: %r{/#{project.path}/-/merge_requests\z}),
        code_added: a_hash_including(url: %r{/-/ide/project/#{project.full_path}/edit\z}),
        code_owners_enabled: a_hash_including(url: %r{/user/project/codeowners/_index.md#set-up-code-owners\z}),
        required_mr_approvals_enabled: a_hash_including(
          url: %r{/ci/testing/code_coverage/coverage_reporting.md#add-a-coverage-check-approval-rule\z}
        ),
        license_scanning_run: a_hash_including(
          url: help_page_path('user/compliance/license_scanning_of_cyclonedx_files/_index.md')
        ),
        secure_dependency_scanning_run: a_hash_including(
          url: project_security_configuration_path(project, anchor: 'dependency-scanning')
        ),
        secure_dast_run: a_hash_including(
          url: project_security_configuration_path(project, anchor: 'dast')
        )
      }

      expect(onboarding_actions_data).to match(result)
    end

    context 'for trial and subscription-related actions' do
      let(:disabled_message) { s_('LearnGitlab|Contact your administrator to start a free Ultimate trial.') }

      context 'when namespace has free or no subscription' do
        before do
          allow(namespace).to receive(:has_free_or_no_subscription?).and_return(true)
        end

        it 'provides URLs to start a trial to namespace admins' do
          namespace.add_owner(user)
          result = {
            trial_started: a_hash_including(
              url: new_trial_path(
                namespace_id: namespace.id, glm_source: 'gitlab.com', glm_content: 'onboarding-start-trial'
              ),
              enabled: true
            ),
            code_owners_enabled: a_hash_including(
              url: new_trial_path(
                namespace_id: namespace.id, glm_source: 'gitlab.com', glm_content: 'onboarding-code-owners'
              ),
              enabled: true
            ),
            required_mr_approvals_enabled: a_hash_including(
              url: new_trial_path(
                namespace_id: namespace.id, glm_source: 'gitlab.com', glm_content: 'onboarding-require-merge-approvals'
              ),
              enabled: true
            )
          }

          expect(onboarding_actions_data).to include(result)
        end

        it 'provides URLs to Gitlab docs to namespace non-admins' do
          result = {
            trial_started: a_hash_including(
              url: project_project_members_path(project),
              enabled: false,
              message: disabled_message
            ),
            code_owners_enabled: a_hash_including(
              url: help_page_path('user/project/codeowners/_index.md', anchor: 'set-up-code-owners'),
              enabled: true
            ),
            required_mr_approvals_enabled: a_hash_including(
              url: help_page_path('ci/testing/code_coverage/coverage_reporting.md',
                anchor: 'add-a-coverage-check-approval-rule'),
              enabled: true
            )
          }

          expect(onboarding_actions_data).to include(result)
        end
      end

      context 'when namespace has paid subscription' do
        before do
          allow(namespace).to receive(:has_free_or_no_subscription?).and_return(false)
        end

        it 'provides URLs to Gitlab docs to namespace admins' do
          namespace.add_owner(user)
          result = {
            trial_started: a_hash_including(
              url: project_project_members_path(project),
              enabled: false,
              message: disabled_message
            ),
            code_owners_enabled: a_hash_including(
              url: help_page_path('user/project/codeowners/_index.md', anchor: 'set-up-code-owners'),
              enabled: true
            ),
            required_mr_approvals_enabled: a_hash_including(
              url: help_page_path('ci/testing/code_coverage/coverage_reporting.md',
                anchor: 'add-a-coverage-check-approval-rule'),
              enabled: true
            )
          }

          expect(onboarding_actions_data).to include(result)
        end

        it 'provides URLs to Gitlab docs to namespace non-admins' do
          result = {
            trial_started: a_hash_including(
              url: project_project_members_path(project),
              enabled: false,
              message: disabled_message
            ),
            code_owners_enabled: a_hash_including(
              url: help_page_path('user/project/codeowners/_index.md', anchor: 'set-up-code-owners'),
              enabled: true
            ),
            required_mr_approvals_enabled: a_hash_including(
              url: help_page_path('ci/testing/code_coverage/coverage_reporting.md',
                anchor: 'add-a-coverage-check-approval-rule'),
              enabled: true
            )
          }

          expect(onboarding_actions_data).to include(result)
        end
      end
    end

    context 'for duo seat assignment' do
      using RSpec::Parameterized::TableSyntax

      let(:url) { group_settings_gitlab_duo_seat_utilization_index_path(namespace) }

      where(:active_duo_addon?, :can_read_usage_quotas?, :result, :expected_url) do
        true  | true  | true  | ref(:url)
        true  | false | false | nil
        false | true  | false | nil
        false | false | false | nil
      end

      with_them do
        before do
          allow(GitlabSubscriptions::Duo)
            .to receive(:any_active_add_on_purchase_for_namespace?).with(namespace).and_return(active_duo_addon?)
          allow(helper).to receive(:can?).and_call_original
          allow(helper)
            .to receive(:can?).with(user, :read_usage_quotas, namespace).and_return(can_read_usage_quotas?)
        end

        subject(:onboarding_actions_data) do
          Gitlab::Json.parse(helper.learn_gitlab_data(project)[:actions]).deep_symbolize_keys
        end

        it 'has expected results' do
          expect(onboarding_actions_data.key?(:duo_seat_assigned)).to be(result)
          expect(onboarding_actions_data.dig(:duo_seat_assigned, :url)).to eq(expected_url)
        end
      end
    end
  end
end
