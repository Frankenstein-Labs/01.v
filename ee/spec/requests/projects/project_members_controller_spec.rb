# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProjectMembersController, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, :public, owners: user) }
  let_it_be(:project) { create(:project, :public, namespace: group) }

  before do
    sign_in(user)
  end

  describe 'GET /*namespace_id/:project_id/-/project_members' do
    let_it_be(:project_member) { create(:project_member, source: project) }
    let(:param) { {} }

    subject(:make_request) do
      get namespace_project_project_members_path(group, project), params: param
    end

    context 'with member pending promotions' do
      let_it_be(:pending_member_approvals) do
        create_list(:gitlab_subscription_member_management_member_approval, 2, :for_project_member,
          member_namespace: project.project_namespace)
      end

      let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

      let(:feature_settings) { true }

      before do
        stub_application_setting(enable_member_promotion_management: feature_settings)
        allow(License).to receive(:current).and_return(license)
      end

      context 'with member_promotion management feature enabled' do
        context 'when user can admin project' do
          it 'assigns @pending_promotion_members_count' do
            make_request

            expect(assigns(:pending_promotion_members_count)).to eq(2)
          end
        end

        context 'when user cannot admin project' do
          it 'does not assigns @pending_promotion_members_count' do
            user = create(:user)
            sign_in(user)
            project.add_developer(user)

            make_request

            expect(assigns(:pending_promotion_members_count)).to be_nil
          end
        end
      end

      shared_examples "empty response" do
        it 'assigns @pending_promotion_members_count be be 0' do
          make_request

          expect(assigns(:pending_promotion_members_count)).to eq(0)
        end
      end

      context 'with member_promotion management feature setting disabled' do
        let(:feature_settings) { false }

        it_behaves_like "empty response"
      end

      context 'when license is not Ultimate' do
        let(:license) { create(:license, plan: License::STARTER_PLAN) }

        it_behaves_like "empty response"
      end
    end

    context 'when requesting JSON (lazy direct members fetch)' do
      subject(:make_json_request) do
        get namespace_project_project_members_path(group, project, format: :json), params: param
      end

      it 'returns only direct project members, not inherited members' do
        make_json_request

        expect(response).to have_gitlab_http_status(:ok)

        member_ids = json_response['members'].map { |member| member['id'] }
        expect(member_ids).to contain_exactly(project_member.id)
      end

      it 'does not assign @pending_promotion_members_count' do
        make_json_request

        expect(assigns(:pending_promotion_members_count)).to be_nil
      end
    end
  end

  describe 'PUT /*namespace_id/:project_id/-/project_members/:id' do
    context 'with block seat overages enabled', :saas do
      before_all do
        create(:gitlab_subscription, :ultimate, namespace: group, seats: 1)
        group.namespace_settings.update!(seat_control: :block_overages)
      end

      it 'rejects promoting a member if there is no billable seat available' do
        member = project.add_guest(create(:user))
        params = { project_member: { access_level: ::Gitlab::Access::DEVELOPER } }

        put namespace_project_project_member_path(namespace_id: group, project_id: project, id: member.id), xhr: true,
          params: params

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq(
          'Could not update role because there are no available seats in this group'
        )
        expect(member.reload.access_level).to eq(::Gitlab::Access::GUEST)
      end

      it 'promotes a member if there is a billable seat available' do
        group.gitlab_subscription.update!(seats: 2)
        member = project.add_guest(create(:user))
        params = { project_member: { access_level: ::Gitlab::Access::DEVELOPER } }

        put namespace_project_project_member_path(namespace_id: group, project_id: project, id: member.id), xhr: true,
          params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).not_to include('message')
        expect(member.reload.access_level).to eq(::Gitlab::Access::DEVELOPER)
      end
    end
  end
end
