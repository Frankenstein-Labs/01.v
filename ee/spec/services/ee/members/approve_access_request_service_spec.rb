# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ApproveAccessRequestService, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project, :public) }
  let_it_be_with_reload(:group) { create(:group, :public) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:access_requester_user) { create(:user, name: "John Wick") }
  let(:access_requester) { source.requesters.find_by!(user_id: access_requester_user.id) }
  let(:opts) { {} }
  let(:params) { {} }
  let(:access_level_label) { 'Default role: Developer' }
  let(:details) do
    {
      add: 'user_access',
      as: access_level_label,
      member_id: access_requester.id
    }
  end

  shared_examples "auditor with context" do
    it "creates audit event with name" do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: "member_created", target_details: "John Wick", additional_details: details)
      ).and_call_original

      described_class.new(current_user, params).execute(access_requester, **opts)
    end
  end

  context "with auditing" do
    context "for project access" do
      let(:source) { project }

      before do
        project.add_maintainer(current_user)
        project.request_access(access_requester_user)
      end

      it_behaves_like "auditor with context"
    end

    context "for group access" do
      let(:source) { group }

      before do
        group.add_owner(current_user)
        group.request_access(access_requester_user)
      end

      it_behaves_like "auditor with context"
    end
  end

  context 'when current user has admin_group_member custom permission' do
    let_it_be(:current_user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:access_requester_user) { create(:user) }

    let(:params) { { access_level: role } }

    let(:access_requester) { group.requesters.find_by!(user_id: access_requester_user.id) }

    before do
      group.request_access(access_requester_user)
      stub_licensed_features(custom_roles: true)
    end

    subject(:approve_access_request) do
      described_class.new(current_user, params).execute(access_requester)
    end

    shared_context 'with member role in group' do
      let_it_be(:member_role) do
        create(:member_role, base_access_level: current_role, namespace: group, admin_group_member: true)
      end

      let_it_be(:current_member) do
        create(:group_member, access_level: current_role, group: group, user: current_user, member_role: member_role)
      end
    end

    shared_examples 'updating members using custom permission' do
      context 'when updating member to the same access role as current user' do
        let(:role) { current_role }

        before do
          access_requester.update!(access_level: current_role)
        end

        it 'approves the request' do
          expect { approve_access_request }.to change { access_requester.reload.requested_at }.to(nil)
        end

        context 'when the custom_roles feature is disabled' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it 'raises an error' do
            expect { approve_access_request }.to raise_error { Gitlab::Access::AccessDeniedError }
          end
        end
      end

      context 'when updating member to higher role than current user' do
        let(:role) { higher_role }

        it 'raises an error' do
          expect { approve_access_request }.to raise_error { Gitlab::Access::AccessDeniedError }
        end
      end
    end

    context 'for guest member role' do
      let_it_be(:current_role) { Gitlab::Access::GUEST }
      let_it_be(:higher_role) { Gitlab::Access::REPORTER }

      include_context 'with member role in group'

      it_behaves_like 'updating members using custom permission'

      context 'with the default (developer) role of the requester' do
        let(:params) { {} }

        it 'raises an error' do
          expect { approve_access_request }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end
    end

    context 'for planner member role' do
      let_it_be(:current_role) { Gitlab::Access::PLANNER }
      let_it_be(:higher_role) { Gitlab::Access::REPORTER }

      include_context 'with member role in group'

      it_behaves_like 'updating members using custom permission'

      context 'with the default (developer) role of the requester' do
        let(:params) { {} }

        it 'raises an error' do
          expect { approve_access_request }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end
    end

    context 'for reporter member role' do
      let_it_be(:current_role) { Gitlab::Access::REPORTER }
      let_it_be(:higher_role) { Gitlab::Access::DEVELOPER }

      include_context 'with member role in group'

      it_behaves_like 'updating members using custom permission'

      context 'with the default (developer) role of the requester' do
        let(:params) { {} }

        it 'raises an error' do
          expect { approve_access_request }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end
    end

    context 'for developer member role' do
      let_it_be(:current_role) { Gitlab::Access::DEVELOPER }
      let_it_be(:higher_role) { Gitlab::Access::MAINTAINER }

      include_context 'with member role in group'

      it_behaves_like 'updating members using custom permission'

      context 'with the default (developer) role of the requester' do
        let(:params) { {} }

        it 'approves the request' do
          expect { approve_access_request }.to change { access_requester.reload.requested_at }.to(nil)
        end
      end
    end

    context 'for maintainer member role' do
      let_it_be(:current_role) { Gitlab::Access::MAINTAINER }
      let_it_be(:higher_role) { Gitlab::Access::OWNER }

      include_context 'with member role in group'

      it_behaves_like 'updating members using custom permission'

      context 'with the default (developer) role of the requester' do
        let(:params) { {} }

        it 'approves the request' do
          expect { approve_access_request }.to change { access_requester.reload.requested_at }.to(nil)
        end
      end
    end
  end

  context 'when billable promotion is restricted' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:current_user) { create(:user) }
    let_it_be(:access_requester_user) { create(:user) }
    let(:access_requester) { group.requesters.find_by!(user_id: access_requester_user.id) }
    let(:params) { { access_level: Gitlab::Access::DEVELOPER } }

    before do
      group.add_owner(current_user)
      group.request_access(access_requester_user)

      allow_next_instance_of(described_class) do |service|
        allow(service).to receive_messages(member_promotion_management_enabled?: true,
          promotion_management_required_for_role?: true)
      end
    end

    subject(:approve_access_request) do
      described_class.new(current_user, params).execute(access_requester)
    end

    context 'when user is non-billable and being promoted to billable role' do
      before do
        allow(User).to receive(:non_billable_users_for_billable_management)
                         .with([access_requester_user.id])
                         .and_return([access_requester_user])
      end

      it 'limits access level to Guest' do
        approve_access_request

        expect(access_requester.reload.access_level).to eq(Gitlab::Access::GUEST)
      end
    end

    context 'when user is billable' do
      before do
        allow(User).to receive(:non_billable_users_for_billable_management)
                         .with([access_requester_user.id])
                         .and_return([])
      end

      it 'does not limit access level' do
        approve_access_request

        expect(access_requester.reload.access_level).to eq(Gitlab::Access::DEVELOPER)
      end
    end

    context 'when current user is admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      before do
        allow(User).to receive(:non_billable_users_for_billable_management)
                         .with([access_requester_user.id])
                         .and_return([access_requester_user])
      end

      it 'does not limit access level' do
        approve_access_request

        expect(access_requester.reload.access_level).to eq(Gitlab::Access::DEVELOPER)
      end
    end

    context 'when promotion management is not enabled' do
      before do
        allow_next_instance_of(described_class) do |service|
          allow(service).to receive(:member_promotion_management_enabled?).and_return(false)
        end

        allow(User).to receive(:non_billable_users_for_billable_management)
                         .with([access_requester_user.id])
                         .and_return([access_requester_user])
      end

      it 'does not limit access level' do
        approve_access_request

        expect(access_requester.reload.access_level).to eq(Gitlab::Access::DEVELOPER)
      end
    end

    context 'when role does not require promotion management' do
      before do
        allow_next_instance_of(described_class) do |service|
          allow(service).to receive(:promotion_management_required_for_role?).and_return(false)
        end

        allow(User).to receive(:non_billable_users_for_billable_management)
                         .with([access_requester_user.id])
                         .and_return([access_requester_user])
      end

      it 'does not limit access level' do
        approve_access_request

        expect(access_requester.reload.access_level).to eq(Gitlab::Access::DEVELOPER)
      end
    end
  end

  context 'when block seat overages is enabled for the group', :saas do
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let(:access_requester) { group.requesters.find_by!(user_id: access_requester_user.id) }

    before_all do
      group.add_owner(current_user)
      group.request_access(access_requester_user)
      group.namespace_settings.update!(seat_control: :block_overages)
    end

    it 'does not approve the request when there are not enough seats' do
      group.gitlab_subscription.update!(seats: 1)

      described_class.new(current_user).execute(access_requester)

      expect(access_requester.reload.requested_at).not_to be_nil
    end

    it 'approves the request when there are enough seats' do
      group.gitlab_subscription.update!(seats: 2)

      described_class.new(current_user).execute(access_requester)

      expect(access_requester.reload.requested_at).to be_nil
    end

    it 'respects a provided access level' do
      group.gitlab_subscription.update!(seats: 1)

      described_class.new(current_user, { access_level: ::Gitlab::Access::GUEST }).execute(access_requester)

      expect(access_requester.reload.requested_at).to be_nil
    end
  end

  context 'when block seat overages is enabled for the instance' do
    let(:access_requester) { group.requesters.find_by!(user_id: access_requester_user.id) }

    before do
      stub_application_setting(seat_control: ::EE::ApplicationSetting::SEAT_CONTROL_BLOCK_OVERAGES)
    end

    before_all do
      group.add_owner(current_user)
      group.request_access(access_requester_user)
    end

    it 'does not approve the request when there are not enough seats' do
      create_current_license(plan: License::ULTIMATE_PLAN, seats: 1)

      described_class.new(current_user).execute(access_requester)

      expect(access_requester.reload.requested_at).not_to be_nil
    end

    it 'approves the request when there are enough seats' do
      create_current_license(plan: License::ULTIMATE_PLAN, seats: 3)

      described_class.new(current_user).execute(access_requester)

      expect(access_requester.reload.requested_at).to be_nil
    end
  end

  context 'when membership is locked' do
    let_it_be_with_refind(:locked_group) { create(:group, :public, membership_lock: true) }
    let_it_be_with_refind(:locked_project) { create(:project, :public, group: locked_group) }
    let_it_be_with_refind(:unlocked_group) { create(:group, :public, membership_lock: false) }
    let_it_be_with_refind(:unlocked_project) { create(:project, :public, group: unlocked_group) }

    before_all do
      locked_group.add_owner(current_user)
      unlocked_group.add_owner(current_user)
    end

    context 'for a project with locked group membership' do
      let(:access_requester) do
        locked_project.requesters.create!(
          user: access_requester_user,
          access_level: Gitlab::Access::DEVELOPER,
          requested_at: Time.current
        )
      end

      it 'returns an error when trying to approve' do
        result = described_class.new(current_user, params).execute(access_requester, **opts)

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include('Membership is locked')
      end

      it 'does not approve the access request' do
        described_class.new(current_user, params).execute(access_requester, **opts)

        expect(access_requester.reload.request_accepted_at).to be_nil
      end
    end

    context 'for a group with locked membership' do
      let(:access_requester) { locked_group.requesters.find_by!(user_id: access_requester_user.id) }

      before do
        locked_group.request_access(access_requester_user)
      end

      it 'successfully approves the access request' do
        expect do
          described_class.new(current_user, params).execute(access_requester, **opts)
        end.to change { access_requester.reload.request_accepted_at }.from(nil)
      end

      it 'creates an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: "member_created")
        ).and_call_original

        described_class.new(current_user, params).execute(access_requester, **opts)
      end
    end

    context 'for a project without locked group membership' do
      let(:access_requester) { unlocked_project.requesters.find_by!(user_id: access_requester_user.id) }

      before do
        unlocked_project.request_access(access_requester_user)
      end

      it 'successfully approves the access request' do
        expect do
          described_class.new(current_user, params).execute(access_requester, **opts)
        end.to change { unlocked_project.requesters.count }.by(-1)
      end
    end
  end
end
