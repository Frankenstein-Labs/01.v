# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::QueueMembersApprovalService, feature_category: :seat_cost_management do
  let(:current_user) { create(:user) }
  let(:group) { create(:group) }
  let(:non_billable_users) { create_list(:user, 2) }
  let(:existing_members) { non_billable_users.map { |user| create(:group_member, :guest, user: user, source: group) } }
  let(:existing_members_hash) { existing_members.index_by(&:user_id) }
  let(:params) do
    { access_level: Gitlab::Access::DEVELOPER, source_namespace: group, existing_members_hash: existing_members_hash }
  end

  subject(:service) { described_class.new(non_billable_users, current_user, params) }

  describe '#execute' do
    context 'when users are successfully queued for approval' do
      it 'returns a success response with queued users' do
        response = service.execute

        expect(response).to be_success
        member_approvals = response.payload[:users_queued_for_approval]
        expect(member_approvals.first.metadata.keys).to match_array(%w[access_level])
        expect(member_approvals.map(&:user)).to match_array(non_billable_users)
      end

      context 'when different params are passed' do
        context 'with expires_at in params' do
          it 'saves expires_at in metadata when passed as datetime' do
            datetime_str = Time.now.utc.iso8601
            params[:expires_at] = datetime_str

            response = service.execute
            expect(response).to be_success
            member_approvals = response.payload[:users_queued_for_approval]
            expect(member_approvals.first.metadata.keys).to match_array(%w[access_level expires_at])
            expect(member_approvals.first.metadata["expires_at"]).to eq(datetime_str)
          end

          it 'saves expires_at in metadata when passed to reset' do
            params[:expires_at] = ""

            response = service.execute

            expect(response).to be_success
            member_approvals = response.payload[:users_queued_for_approval]
            expect(member_approvals.first.metadata.keys).to match_array(%w[access_level expires_at])
            expect(member_approvals.first.metadata["expires_at"]).to eq("")
          end
        end

        context 'with member_role_id in params' do
          it 'saves member_role_id in metadata when passed in params' do
            member_role = create(:member_role, :guest, namespace: nil, organization: current_user.organization,
              read_vulnerability: true)
            params[:member_role_id] = member_role.id

            response = service.execute

            expect(response).to be_success
            member_approvals = response.payload[:users_queued_for_approval]
            expect(member_approvals.first.metadata.keys).to match_array(%w[access_level member_role_id])
            expect(member_approvals.first.metadata["member_role_id"]).to eq(member_role.id)
          end

          it 'saves member_role_id in metadata when passed to reset' do
            params[:member_role_id] = nil

            response = service.execute

            expect(response).to be_success
            member_approvals = response.payload[:users_queued_for_approval]
            expect(member_approvals.first.metadata.keys).to match_array(%w[access_level member_role_id])
            expect(member_approvals.first.metadata["member_role_id"]).to be_nil
          end
        end
      end

      context 'and webhook is triggered' do
        let(:non_billable_users) { create_list(:user, 1) }
        let(:existing_members) { [] }
        let(:existing_members_hash) { {} }

        it 'triggers member approval hooks' do
          hook_service = SystemHooksService.new
          allow(hook_service).to receive(:execute_hooks).and_call_original
          allow(SystemHooksService).to receive(:new).and_return(hook_service)

          service.execute

          expect(hook_service).to have_received(:execute_hooks).with(
            a_hash_including(action: 'enqueue', object_kind: 'gitlab_subscription_member_approval'),
            anything
          )
        end
      end
    end

    context 'when non_billable_users is empty' do
      let(:non_billable_users) { [] }

      it 'returns success' do
        response = service.execute

        expect(response).to be_success
        expect(response.payload[:users_queued_for_approval]).to be_empty
      end
    end

    context 'when an exception is raised' do
      shared_examples 'it returns error' do
        it 'returns an error' do
          response = service.execute

          expect(response).to be_error
          expect(response.payload[:users_queued_for_approval]).to be_nil
          expect(response.message).to eq("Invalid record while enqueuing users for approval")
        end
      end

      context 'when RecordInvalid is raised' do
        before do
          allow(::GitlabSubscriptions::MemberManagement::MemberApproval).to receive(:create_or_update_pending_approval)
                                              .and_raise(ActiveRecord::RecordInvalid)
        end

        it_behaves_like 'it returns error'
      end

      context 'when RecordNotUnique is raised' do
        before do
          allow(::GitlabSubscriptions::MemberManagement::MemberApproval).to receive(:create_or_update_pending_approval)
                                              .and_raise(ActiveRecord::RecordNotUnique)
        end

        it_behaves_like 'it returns error'
      end
    end
  end
end
