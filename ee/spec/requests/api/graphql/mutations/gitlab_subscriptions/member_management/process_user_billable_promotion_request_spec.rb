# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update MemberApproval User Status', feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

  let(:group) { create(:group) }
  let(:project) { create(:project) }
  let(:project_namespace) { project.project_namespace }
  let!(:member_approval) do
    create(:gitlab_subscription_member_management_member_approval, user: user, member_namespace: group, member: nil,
      old_access_level: nil)
  end

  let(:mutation) { graphql_mutation(:process_user_billable_promotion_request, input) }
  let(:action) { 'APPROVED' }
  let(:mutation_response) { graphql_mutation_response(:process_user_billable_promotion_request) }
  let(:input) do
    {
      user_id: user.to_global_id.to_s,
      status: action
    }
  end

  before do
    allow(License).to receive(:current).and_return(license)
    stub_application_setting(enable_member_promotion_management: true)
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_member_approval do
    let(:user) { current_user }
    let(:boundary_object) { :instance }
    let(:mutation) { graphql_mutation(:process_user_billable_promotion_request, input, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  shared_examples 'returns an error' do
    it 'returns an error' do
      mutate

      expect(graphql_errors).to contain_exactly(
        hash_including(
          'message' => "The resource that you are attempting to access does not exist or you don't have " \
            'permission to perform this action'
        )
      )
    end
  end

  context 'when called by a non-admin' do
    let(:current_user) { create(:user) }

    include_examples 'returns an error'
  end

  context 'when pending request exists' do
    context 'when Approved' do
      context 'with new invited user' do
        it 'adds the user to the source' do
          expect(group.members.map(&:user_id)).not_to include(user.id)

          mutate
          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['result']).to eq("SUCCESS")
          expect(group.reload.members.map(&:user_id)).to include(user.id)
          expect(member_approval.reload.status).to eq("approved")
        end
      end

      shared_examples 'updates the access_level of the existing member' do
        it 'updates the access_level of the existing member' do
          expect(existing_member.reload.access_level).to eq(Gitlab::Access::GUEST)
          mutate
          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['result']).to eq("SUCCESS")
          expect(existing_member.reload.access_level).to eq(Gitlab::Access::DEVELOPER)
          expect(member_approval.reload.status).to eq("approved")
        end
      end

      shared_examples 'with multiple pending promotions' do
        it 'invites and updates all pending requests' do
          expect(source.reload.members.map(&:user_id)).not_to include(user.id)
          expect(existing_member_in_another_src.access_level).to eq(Gitlab::Access::GUEST)

          mutate
          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['result']).to eq("SUCCESS")
          expect(source.reload.members.map(&:user_id)).to include(user.id)
          expect(existing_member_in_another_src.reload.access_level).to eq(Gitlab::Access::DEVELOPER)
          expect(member_approval.reload.status).to eq("approved")
          expect(another_member_approval.reload.status).to eq("approved")
        end

        context 'when one promotion fails' do
          before do
            allow(Members::CreateService).to receive(:new).and_call_original

            params = member_approval.metadata.symbolize_keys
            params.merge!(
              user_id: [user.id],
              source: source,
              access_level: member_approval.new_access_level,
              invite_source: "GitlabSubscriptions::MemberManagement::ProcessUserBillablePromotionService",
              skip_authorization: false
            )

            allow_next_instance_of(Members::CreateService, current_user, params) do |instance|
              allow(instance).to receive(:execute).and_return(status: :error)
            end
          end

          it 'returns partial success' do
            expect(source.reload.members.map(&:user_id)).not_to include(user.id)
            expect(existing_member_in_another_src.access_level).to eq(Gitlab::Access::GUEST)

            mutate
            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['result']).to eq("PARTIAL_SUCCESS")
            expect(source.reload.members.map(&:user_id)).not_to include(user.id)
            expect(member_approval.reload.status).to eq("approved")
            expect(another_member_approval.reload.status).to eq("approved")
          end
        end
      end

      context 'for group' do
        let(:source) { group }

        context 'with existing member user' do
          let!(:existing_member) { create(:group_member, :guest, group: group, user: user) }

          include_examples 'updates the access_level of the existing member'
        end

        context 'with multiple pending requests' do
          let(:another_group) { create(:group) }
          let!(:existing_member_in_another_src) { create(:group_member, :guest, group: another_group, user: user) }

          let!(:another_member_approval) do
            create(:gitlab_subscription_member_management_member_approval,
              user: user,
              member_namespace: another_group,
              member: existing_member_in_another_src,
              old_access_level: 10
            )
          end

          it_behaves_like 'with multiple pending promotions'
        end
      end

      context 'for project' do
        let(:source) { project }
        let!(:member_approval) do
          create(:gitlab_subscription_member_management_member_approval, user: user,
            member_namespace: project_namespace, member: nil, old_access_level: nil)
        end

        context 'with existing member user' do
          let!(:existing_member) { create(:project_member, :guest, project: project, user: user) }

          include_examples 'updates the access_level of the existing member'
        end

        context 'with multiple pending requests' do
          let(:another_project) { create(:project) }
          let(:another_project_namespace) { another_project.project_namespace }
          let!(:existing_member_in_another_src) do
            create(:project_member, :guest, project: another_project, user: user)
          end

          let!(:another_member_approval) do
            create(:gitlab_subscription_member_management_member_approval,
              user: user,
              member_namespace: another_project_namespace,
              member: existing_member_in_another_src,
              old_access_level: 10
            )
          end

          it_behaves_like 'with multiple pending promotions'
        end
      end
    end

    context 'when DENIED' do
      let(:action) { 'DENIED' }

      it 'denies pending requests' do
        mutate

        expect(member_approval.reload.status).to eq("denied")
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['result']).to eq("SUCCESS")
      end
    end

    context 'when update! fails' do
      before do
        allow(::GitlabSubscriptions::MemberManagement::MemberApproval).to receive_message_chain(
          :pending_member_approvals_for_user, :find_each)
                                            .and_yield(member_approval)
        allow(member_approval).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'returns failed' do
        mutate

        expect(member_approval.reload.status).to eq("pending")
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['result']).to eq("FAILED")
        expect(mutation_response['errors']).to include("Failed to update member approval status to approved")
      end
    end
  end
end
