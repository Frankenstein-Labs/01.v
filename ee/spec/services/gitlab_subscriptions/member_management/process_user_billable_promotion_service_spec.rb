# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::ProcessUserBillablePromotionService, feature_category: :seat_cost_management do
  let_it_be(:current_user) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:billable_member_role) { create(:member_role, :instance, :billable) }

  let(:status) { :approved }
  let(:skip_authorization) { false }
  let(:service) do
    described_class.new(user, current_user, { status: status, skip_authorization: skip_authorization })
  end

  let(:group) { create(:group) }
  let(:project) { create(:project, group: group) }
  let(:another_group) { create(:group) }
  let!(:member_approval) do
    create(:gitlab_subscription_member_management_member_approval, :to_owner,
      member_namespace: project.project_namespace, user: user, member: nil, old_access_level: nil)
  end

  let!(:another_member_approval) do
    create(:gitlab_subscription_member_management_member_approval, :to_developer,
      member_namespace: another_group, user: user, member: nil, old_access_level: nil)
  end

  describe '#execute' do
    before do
      allow(License).to receive(:current).and_return(license)
      stub_application_setting(enable_member_promotion_management: true)
    end

    context 'when service is not allowed to execute' do
      shared_examples 'unauthorized response' do
        it 'returns an error' do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq('Unauthorized')
        end
      end

      context 'when current_user is not present' do
        let(:current_user) { nil }

        context 'with skip_authorization set to false' do
          it_behaves_like 'unauthorized response'
        end

        context 'with skip_authorization set to true' do
          let(:skip_authorization) { true }

          context 'when status is approved' do
            it 'returns success' do
              response = service.execute

              expect(response).to be_success
              expect(member_approval.reload).to be_approved
              expect(member_approval.reload.reviewed_by).to be_nil
            end
          end

          context 'when status is denied' do
            let(:status) { :denied }

            it 'returns success' do
              response = service.execute

              expect(response).to be_success
              expect(member_approval.reload).to be_denied
              expect(member_approval.reload.reviewed_by).to be_nil
            end
          end
        end
      end

      context 'when current_user is not admin' do
        let(:current_user) { create(:user) }

        it_behaves_like 'unauthorized response'
      end
    end

    context 'when current_user is admin', :enable_admin_mode do
      context 'with all possible promotion scenarios' do
        using RSpec::Parameterized::TableSyntax
        where(:source, :existing_access_level, :to_new_access_level, :member_role, :new_access_level_val) do
          :group   | nil    | :to_guest      | :billable | Gitlab::Access::GUEST
          :group   | nil    | :to_reporter   | nil       | Gitlab::Access::REPORTER
          :group   | nil    | :to_developer  | nil       | Gitlab::Access::DEVELOPER
          :group   | nil    | :to_maintainer | nil       | Gitlab::Access::MAINTAINER
          :group   | nil    | :to_owner      | nil       | Gitlab::Access::OWNER
          :group   | :guest | :to_guest      | :billable | Gitlab::Access::GUEST
          :group   | :guest | :to_reporter   | nil       | Gitlab::Access::REPORTER
          :group   | :guest | :to_developer  | nil       | Gitlab::Access::DEVELOPER
          :group   | :guest | :to_maintainer | nil       | Gitlab::Access::MAINTAINER
          :group   | :guest | :to_owner      | nil       | Gitlab::Access::OWNER
          :project | nil    | :to_guest      | :billable | Gitlab::Access::GUEST
          :project | nil    | :to_reporter   | nil       | Gitlab::Access::REPORTER
          :project | nil    | :to_developer  | nil       | Gitlab::Access::DEVELOPER
          :project | nil    | :to_maintainer | nil       | Gitlab::Access::MAINTAINER
          :project | nil    | :to_owner      | nil       | Gitlab::Access::OWNER
          :project | :guest | :to_guest      | :billable | Gitlab::Access::GUEST
          :project | :guest | :to_reporter   | nil       | Gitlab::Access::REPORTER
          :project | :guest | :to_developer  | nil       | Gitlab::Access::DEVELOPER
          :project | :guest | :to_maintainer | nil       | Gitlab::Access::MAINTAINER
          :project | :guest | :to_owner      | nil       | Gitlab::Access::OWNER
        end

        with_them do
          let(:src) { source == :group ? group : project }
          let(:member_namespace) { source == :group ? group : project.project_namespace }
          let(:member_role_id) { billable_member_role.id if member_role == :billable }
          let(:existing_member) do
            next unless existing_access_level

            if source == :group
              group.add_guest(user)
            else
              project.add_guest(user)
            end
          end

          let!(:member_approval) do
            old_access_level = Gitlab::Access::GUEST if existing_access_level == :guest

            create(
              :gitlab_subscription_member_management_member_approval,
              to_new_access_level,
              old_access_level: old_access_level,
              member_namespace: member_namespace,
              member: existing_member,
              member_role_id: member_role_id,
              user: user
            )
          end

          context 'when there are pending member approvals' do
            context 'when admin approves' do
              it 'applies all the promotions' do
                expect(another_group.reload.members).to be_empty

                response = service.execute

                expect(response).to be_success
                expect(response.message).to eq('Successfully processed request')
                expect(response.payload).to eq({ user: user, status: status, result: :success })
                expect(member_approval.reload.status).to eq('approved')
                expect(member_approval.reload.reviewed_by).to eq(current_user)
                expect(another_member_approval.reload.status).to eq('approved')
                expect(another_member_approval.reload.reviewed_by).to eq(current_user)

                member = src.reload.members.last
                expect(member.user).to eq(user)
                expect(member.access_level).to eq(new_access_level_val)
                expect(member.member_role_id).to eq(member_role_id)

                another_membership = another_group.reload.members.last
                expect(another_membership).not_to be_nil
                expect(another_membership.user).to eq(user)
                expect(another_membership.access_level).to eq(Gitlab::Access::DEVELOPER)
              end
            end

            context 'when admin denies' do
              let(:status) { :denied }

              it 'updates the approval status' do
                expect(::Members::CreateService).not_to receive(:new)
                response = service.execute

                expect(response).to be_success
                expect(response.message).to eq('Successfully processed request')
                expect(response.payload).to eq({ user: user, status: status, result: :success })
                expect(member_approval.reload.status).to eq('denied')
                expect(member_approval.reload.reviewed_by).to eq(current_user)
                expect(another_member_approval.reload.status).to eq('denied')
                expect(another_member_approval.reload.reviewed_by).to eq(current_user)
              end
            end
          end
        end
      end

      context 'when there are no pending member approvals' do
        let(:member_approval) { nil }
        let(:another_member_approval) { nil }

        it 'returns a success response' do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to eq({ user: user, status: status, result: :success })
        end
      end

      context 'when there are partial success while applying' do
        before do
          allow(Members::CreateService).to receive(:new).and_call_original

          params = member_approval.metadata.symbolize_keys
          params.merge!(
            user_id: [user.id],
            source: project,
            access_level: member_approval.new_access_level,
            invite_source: "GitlabSubscriptions::MemberManagement::ProcessUserBillablePromotionService",
            skip_authorization: skip_authorization
          )

          allow_next_instance_of(Members::CreateService, current_user, params) do |instance|
            allow(instance).to receive(:execute).and_return(status: :error)
          end
        end

        it 'returns a partial success response' do
          response = service.execute

          expect(response).to be_success
          expect(response.message).to eq('Successfully processed request')
          expect(response.payload).to eq({ user: user, status: status, result: :partial_success })
          expect(member_approval.reload.status).to eq('approved')
          expect(another_member_approval.reload.status).to eq('approved')
        end
      end

      context 'when there is all failure for already billable user' do
        let(:sub_group) { create(:group, parent: group) }

        let!(:member_approval) do
          create(:gitlab_subscription_member_management_member_approval, :to_developer,
            member_namespace: sub_group, user: user, member: nil, old_access_level: nil)
        end

        let(:another_member_approval) { nil }

        before do
          group.add_maintainer(user)
        end

        it 'returns a partial success response' do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to eq({ user: user, status: status, result: :partial_success })
        end
      end

      context 'when all promotions fail while applying' do
        before do
          allow_next_instance_of(Members::CreateService) do |instance|
            allow(instance).to receive(:execute).and_return(status: :error)
          end
        end

        it 'returns a failure response' do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq('Failed to apply promotions')
          expect(response.payload).to eq({ result: :failed })
          expect(member_approval.reload.status).to eq('pending')
          expect(another_member_approval.reload.status).to eq('pending')
        end
      end

      context 'when there is failure during update!' do
        before do
          allow(::GitlabSubscriptions::MemberManagement::MemberApproval).to receive_message_chain(
            :pending_member_approvals_for_user, :find_each)
                                              .and_yield(member_approval).and_yield(another_member_approval)
          allow(member_approval).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
        end

        it 'returns a failure response' do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq("Failed to update member approval status to #{status}")
          expect(response.payload).to eq({ result: :failed })
        end
      end

      context 'when status is neither approved or denied' do
        let(:status) { :pending }

        it 'returns a failure response' do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq("Invalid #{status}")
          expect(response.payload).to eq({ result: :failed })
        end
      end
    end

    context 'and triggers webhook', :enable_admin_mode do
      before do
        allow(Members::CreateService).to receive(:new).and_call_original
      end

      let(:params) do
        params = member_approval.metadata.symbolize_keys
        params.merge!(
          user_id: [user.id],
          source: project,
          access_level: member_approval.new_access_level,
          invite_source: "GitlabSubscriptions::MemberManagement::ProcessUserBillablePromotionService",
          skip_authorization: skip_authorization
        )
      end

      let(:another_member_approval) { nil }

      context 'when approved' do
        it 'triggers webhook when success' do
          allow_next_instance_of(Members::CreateService, current_user, params) do |instance|
            allow(instance).to receive(:execute).and_return(status: :success)
          end

          expect_member_approval_hook(event_name: 'approved', status: :success)

          service.execute
        end

        it 'triggers webhook when failed' do
          allow_next_instance_of(Members::CreateService, current_user, params) do |instance|
            allow(instance).to receive(:execute).and_return(status: :error)
          end

          expect_member_approval_hook(event_name: 'approved', status: :failed)

          service.execute
        end
      end

      context 'when denied' do
        let(:status) { :denied }

        it 'triggers webhook' do
          expect_member_approval_hook(event_name: 'denied', status: :success)

          service.execute
        end
      end
    end
  end

  private

  def expect_member_approval_hook(event_name:, status:)
    expect_next_instance_of(SystemHooksService) do |hook_service|
      expect(hook_service).to receive(:execute_hooks) do |payload, _|
        expect(payload[:action]).to eq(event_to_action_verb(event_name))
        expect(payload[:object_attributes][:status]).to eq(status)
        expect(payload[:object_kind]).to eq("gitlab_subscription_member_approvals")
      end
    end
  end

  def event_to_action_verb(event)
    case event
    when "approved"
      "approve"
    when "denied"
      "deny"
    end
  end
end
