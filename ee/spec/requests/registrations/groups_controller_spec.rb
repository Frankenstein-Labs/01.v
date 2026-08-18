# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project creation via Registrations::GroupsController',
  :with_current_organization, type: :request, feature_category: :onboarding do
  let_it_be_with_reload(:user) { create(:user, onboarding_in_progress: true, organizations: [current_organization]) }

  shared_examples 'user not in onboarding' do
    before do
      user.update!(onboarding_in_progress: false)
    end

    it { is_expected.to redirect_to(root_path) }
  end

  describe 'GET #new' do
    before do
      stub_saas_features(onboarding: true)
      sign_in(user)
    end

    subject { get new_users_sign_up_group_path }

    it_behaves_like 'user not in onboarding'
  end

  describe 'POST #create' do
    let(:params) { { group: group_params, project: project_params } }
    let(:group_params) do
      {
        name: 'Group name',
        path: 'group-path',
        visibility_level: Gitlab::VisibilityLevel::PRIVATE.to_s,
        setup_for_company: nil
      }
    end

    let(:project_params) do
      {
        name: 'New project',
        path: 'project-path',
        visibility_level: Gitlab::VisibilityLevel::PRIVATE,
        initialize_with_readme: 'true'
      }
    end

    subject(:post_create) { post users_sign_up_groups_path, params: params }

    context 'with an authenticated user' do
      before do
        # Stubbed not to break query budget. Should be safe as the query only happens on SaaS and the result is cached
        allow(Gitlab::Com).to receive(:gitlab_com_group_member?).and_return(nil)
        stub_saas_features(onboarding: true)

        sign_in(user)
      end

      it_behaves_like 'user not in onboarding'

      context 'with redirection on success' do
        before do
          allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(157)
        end

        context 'when remove_onboarding_tutorial_pages is enabled' do
          it { is_expected.to redirect_to(new_project_path(namespace_id: Project.last.namespace_id)) }
        end

        context 'when remove_onboarding_tutorial_pages is disabled' do
          before do
            stub_feature_flags(remove_onboarding_tutorial_pages: false)
          end

          context 'for free' do
            it { is_expected.to redirect_to(project_learn_gitlab_path(Project.last)) }
          end

          context 'for trials' do
            before do
              user.update!(onboarding_status_registration_type: 'trial')
            end

            it { is_expected.to redirect_to(project_get_started_path(Project.last)) }
          end
        end
      end

      context 'when group and project can be created' do
        it 'creates a group' do
          # 204 before creating learn gitlab in worker
          allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(157)

          expect { post_create }.to change { Group.count }.by(1)
        end
      end

      context 'when group already exists and project can be created' do
        let_it_be(:group) { create(:group, organization: current_organization, owners: user) }
        let(:group_params) { { id: group.id } }

        it 'creates a project' do
          # queries: core project is 78 and learn gitlab is 76, which is now in background
          allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(101)
          expect { post_create }.to change { Project.count }.by(1)
        end
      end
    end
  end
end
