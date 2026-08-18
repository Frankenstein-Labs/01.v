# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::GroupsController, feature_category: :onboarding do
  let_it_be_with_reload(:user) { create(:user, onboarding_in_progress: true) }
  let_it_be(:group) { create(:group) }

  let(:onboarding_enabled?) { true }

  before do
    stub_saas_features(onboarding: onboarding_enabled?)
  end

  describe 'GET #new' do
    subject(:get_new) { get :new }

    context 'with an unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'with an authenticated user' do
      before do
        sign_in(user)
      end

      context 'when onboarding feature is available' do
        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:new) }

        it 'assigns the group variable to a new Group with the default group visibility', :aggregate_failures do
          get_new

          expect(assigns(:group)).to be_a_new(Group)
          expect(assigns(:group).visibility_level).to eq(Gitlab::CurrentSettings.default_group_visibility)
        end

        it 'assigns the group and project variables with default names', :aggregate_failures do
          get_new

          expect(assigns(:group).name).to eq("#{user.username}-group")
          expect(assigns(:project).name).to eq("#{user.username}-project")
        end

        it 'builds a project object' do
          get_new

          expect(assigns(:project)).to be_a_new(Project)
        end

        context 'when form is rendered' do
          it 'tracks the new group view event' do
            get_new

            expect_snowplow_event(
              category: described_class.name,
              action: 'view_new_group_action',
              label: 'free_registration',
              user: user
            )
          end

          context 'when on trial' do
            before do
              user.update!(onboarding_status_registration_type: 'trial')
            end

            it 'tracks the new group view event' do
              get_new

              expect_snowplow_event(
                category: described_class.name,
                action: 'view_new_group_action',
                label: 'trial_registration',
                user: user
              )
            end
          end
        end

        context 'when user does not have the ability to create a group' do
          before do
            user.update!(can_create_group: false)
          end

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end
      end

      context 'when onboarding feature is not available' do
        let(:onboarding_enabled?) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      it_behaves_like 'hides email confirmation warning'
    end
  end

  describe 'POST #create' do
    subject(:post_create) { post :create, params: params }

    let(:params) { { group: group_params, project: project_params }.merge(extra_params) }
    let(:extra_params) { {} }
    let(:group_params) do
      {
        name: 'Group name',
        path: 'group-path',
        visibility_level: Gitlab::VisibilityLevel::PRIVATE.to_s
      }
    end

    let(:project_params) do
      {
        name: 'New project',
        path: 'project-path',
        visibility_level: Gitlab::VisibilityLevel::PRIVATE,
        template_name: '',
        initialize_with_readme: 'true'
      }
    end

    shared_examples 'finishing onboarding' do
      context 'when onboarding feature is not available' do
        let(:onboarding_enabled?) { false }

        it 'does not finish onboarding' do
          post_create
          user.reload

          expect(user.onboarding_in_progress).to be(true)
        end
      end

      context 'when onboarding feature is available' do
        it 'finishes onboarding' do
          post_create
          user.reload

          expect(user.onboarding_in_progress).to be(false)
        end
      end
    end

    context 'with an unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'with an authenticated user' do
      before do
        sign_in(user)
      end

      it_behaves_like 'hides email confirmation warning'
      it_behaves_like 'finishing onboarding'

      it 'creates a group and project' do
        expect { post_create }.to change { Group.count }.by(1).and change { Project.count }.by(1)
      end

      context 'when form is successfully submitted' do
        it 'tracks submission event' do
          post_create

          expect_snowplow_event(
            category: described_class.name,
            action: 'successfully_submitted_form',
            label: 'free_registration',
            user: user,
            project: an_instance_of(Project),
            namespace: an_instance_of(Group)
          )

          expect_no_snowplow_event(
            category: described_class.name,
            action: 'select_project_template_plainhtml',
            label: 'free_registration',
            user: user,
            project: an_instance_of(Project),
            namespace: an_instance_of(Group)
          )
        end

        context 'with template name' do
          let(:project_params) { super().merge(template_name: 'plainhtml') }

          it 'tracks submission event' do
            post_create

            expect_snowplow_event(
              category: described_class.name,
              action: 'successfully_submitted_form',
              label: 'free_registration',
              user: user,
              project: an_instance_of(Project),
              namespace: an_instance_of(Group)
            )

            expect_snowplow_event(
              category: described_class.name,
              action: 'select_project_template_plainhtml',
              label: 'free_registration',
              user: user,
              project: an_instance_of(Project),
              namespace: an_instance_of(Group)
            )
          end
        end

        context 'when on trial' do
          before do
            user.update!(onboarding_status_registration_type: 'trial')
          end

          it 'tracks submission event' do
            post_create

            expect_snowplow_event(
              category: described_class.name,
              action: 'successfully_submitted_form',
              label: 'trial_registration',
              user: user,
              project: an_instance_of(Project),
              namespace: an_instance_of(Group)
            )
          end
        end
      end

      context 'when there is no suggested path based from the name' do
        let(:group_params) { { name: '⛄⛄⛄', path: '' } }

        it 'creates a group' do
          expect { post_create }.to change { Group.count }.by(1)
        end
      end

      context 'when the group cannot be created' do
        let(:group_params) { { name: '', path: '' } }

        it 'does not create a group', :aggregate_failures do
          expect { post_create }.not_to change { Group.count }
          expect(assigns(:group).errors).not_to be_blank
        end

        it 'the project is not disregarded completely' do
          post_create

          expect(assigns(:project).name).to eq('New project')
        end

        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:new) }

        context 'when form is not submitted' do
          it 'tracks error event and does not track submission event' do
            post_create

            expect_no_snowplow_event(
              category: described_class.name,
              action: 'successfully_submitted_form',
              label: 'free_registration',
              user: user,
              project: an_instance_of(Project),
              namespace: an_instance_of(Group)
            )

            expect_snowplow_event(
              category: described_class.name,
              action: 'track_free_registration_error',
              label: 'failed_creating_group',
              user: user
            )
          end
        end
      end

      context 'with signup onboarding not enabled' do
        let(:onboarding_enabled?) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context "when group can be created but the project can't" do
        let(:project_params) { { name: '', path: '', visibility_level: Gitlab::VisibilityLevel::PRIVATE } }

        it 'does not create a project', :aggregate_failures do
          expect { post_create }.to change { Group.count }.and not_change { Project.count }
          expect(assigns(:project).errors).not_to be_blank
        end

        it 'tracks error event' do
          post_create

          expect_snowplow_event(
            category: described_class.name,
            action: 'track_free_registration_error',
            label: 'failed_creating_project',
            user: user
          )
        end

        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:new) }
      end

      context "when a group is already created but a project isn't" do
        before_all do
          group.add_owner(user)
        end

        let(:group_params) { { id: group.id } }

        it 'creates a project and not another group', :aggregate_failures do
          expect { post_create }.to change { Project.count }.and not_change { Group.count }
        end
      end

      context 'when redirecting' do
        before do
          allow_next_instance_of(Registrations::StandardNamespaceCreateService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.success(payload: { project: project })
            )
          end
        end

        let_it_be(:project) { create(:project) }

        context 'when remove_onboarding_tutorial_pages is enabled' do
          let(:success_path) { new_project_path(namespace_id: project.namespace_id) }

          it { is_expected.to redirect_to(success_path) }
        end

        context 'when remove_onboarding_tutorial_pages is disabled' do
          before do
            stub_feature_flags(remove_onboarding_tutorial_pages: false)
          end

          let(:success_path) { project_learn_gitlab_path(project) }

          it { is_expected.to redirect_to(success_path) }
        end
      end

      context 'with import_url in the params' do
        let(:params) { { group: group_params, import_url: new_import_github_path } }

        let(:group_params) do
          {
            name: 'Group name',
            path: 'group-path',
            visibility_level: Gitlab::VisibilityLevel::PRIVATE.to_s
          }
        end

        it_behaves_like 'hides email confirmation warning'
        it_behaves_like 'finishing onboarding'

        context "when a group can't be created" do
          before do
            allow_next_instance_of(Registrations::ImportNamespaceCreateService) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.error(message: 'failed', payload: { group: Group.new, project: Project.new })
              )
            end
          end

          it { is_expected.to render_template(:new) }
        end

        context 'when there is no suggested path based from the group name' do
          let(:group_params) { { name: '⛄⛄⛄', path: '' } }

          it 'creates a group, and redirects' do
            expect { post_create }.to change { Group.count }.by(1)
            expect(post_create).to have_gitlab_http_status(:redirect)
          end
        end

        context 'when group can be created' do
          it 'creates a group' do
            expect { post_create }.to change { Group.count }.by(1)
          end

          it 'redirects to the import url with a namespace_id parameter' do
            allow_next_instance_of(Registrations::ImportNamespaceCreateService) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.success(payload: { group: group })
              )
            end

            expect(post_create).to redirect_to(new_import_github_url(namespace_id: group.id))
          end
        end
      end
    end
  end
end
