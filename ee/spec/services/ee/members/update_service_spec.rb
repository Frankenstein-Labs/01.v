# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::UpdateService, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:group) { create(:group, :public) }

  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let_it_be_with_refind(:group_member) { create(:group_member, :guest, group: group) }
  let_it_be_with_refind(:project_member) { create(:project_member, :guest, project: project) }

  let(:new_access_level) { Gitlab::Access::GUEST }
  let(:new_expiration) { nil }

  let(:audit_role_from) { "Default role: #{Gitlab::Access.human_access(Gitlab::Access::GUEST)}" }
  let(:audit_role_to) { "Default role: #{Gitlab::Access.human_access(new_access_level)}" }
  let(:target_member_role) { nil }

  let(:audit_role_details) do
    {
      change: 'access_level',
      from: audit_role_from,
      to: audit_role_to,
      expiry_from: nil,
      expiry_to: new_expiration,
      as: audit_role_to,
      member_id: member.id,
      member_role_id: target_member_role&.id
    }
  end

  let(:current_user) { user }
  let(:member) { group_member }
  let(:source) { group }
  let(:params) { { access_level: new_access_level, expires_at: new_expiration, source: source } }

  let(:service) { described_class.new(current_user, params) }

  subject(:update_member) { service.execute(member) }

  shared_examples_for 'logs an audit event' do
    specify do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including({
        name: "member_updated"
      })).and_call_original

      expect { update_member }.to change { AuditEventReader.count }.by(1)

      expect(AuditEventReader.last).to have_attributes(
        details: hash_including(audit_role_details)
      )
    end
  end

  shared_examples_for 'does not log an audit event' do
    specify do
      expect { update_member }.not_to change { AuditEventReader.count }
    end
  end

  shared_examples 'correct member role assignment' do
    it 'returns success' do
      expect(update_member[:status]).to eq(:success)
    end

    it 'assigns the role correctly' do
      expect { update_member }.to change { member.reload.member_role }
        .from(initial_member_role).to(target_member_role)
    end
  end

  shared_examples 'member_promotion_management scenarios' do
    context 'when current_user is an admin' do
      let(:current_user) { admin }

      it 'updates all members', :enable_admin_mode do
        expect(update_members[:status]).to eq(:success)
        expect(update_members[:members]).to match_array(members)
      end
    end

    context 'when current_user is not an admin' do
      let(:current_user) { user }

      before do
        source.add_owner(user)
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        it 'returns an error' do
          allow(::GitlabSubscriptions::MemberManagement::MemberApproval).to receive(:create_or_update_pending_approval)
                                              .and_raise(ActiveRecord::RecordInvalid)

          expect { update_members }.not_to change { ::GitlabSubscriptions::MemberManagement::MemberApproval.count }
          expect(update_members[:status]).to eq(:error)
          expect(update_members[:members].first.errors[:base].first).to eq(
            "Unable to send approval request to administrator."
          )
          expect(update_members[:members]).to contain_exactly(members.first)
        end
      end

      context 'when current_user can update the given members' do
        it 'queues members requiring promotion management for approval and updates others' do
          expect { update_members }.to change { ::GitlabSubscriptions::MemberManagement::MemberApproval.count }.by(1)
          expect(update_members[:status]).to eq(:success)
          expect(update_members[:members]).to contain_exactly(members.second)

          members.first.reload
          member_approval = ::GitlabSubscriptions::MemberManagement::MemberApproval.last
          expect(member_approval.member).to eq(members.first)
          expect(member_approval.member_namespace).to eq(members.first.member_namespace)
          expect(member_approval.old_access_level).to eq(members.first.access_level)
          expect(member_approval.new_access_level).to eq(new_access_level)
          expect(member_approval.requested_by).to eq(current_user)
          expect(update_members[:members_queued_for_approval]).to contain_exactly(members.first)
          expect(update_members[:queued_member_approvals]).to contain_exactly(member_approval)
        end
      end
    end
  end

  shared_examples 'a service raising Gitlab::Access::AccessDeniedError' do
    it 'when permission denied it raises ::Gitlab::Access::AccessDeniedError' do
      expect { update_member }.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end

  context 'when member_promotion_management feature is enabled' do
    let_it_be(:ultimate_license) { create(:license, plan: License::ULTIMATE_PLAN) }

    subject(:update_members) { described_class.new(current_user, params).execute(members) }

    before do
      allow(License).to receive(:current).and_return(ultimate_license)
      stub_application_setting(enable_member_promotion_management: true)
    end

    context 'when user does not have permission to update' do
      let(:current_user) { user }

      it_behaves_like 'a service raising Gitlab::Access::AccessDeniedError' do
        let(:members) { [project_member] }
      end

      it_behaves_like 'a service raising Gitlab::Access::AccessDeniedError' do
        let(:members) { [group_member] }
      end
    end

    context 'when user have permission to update' do
      let(:new_access_level) { Gitlab::Access::MAINTAINER }

      it_behaves_like 'member_promotion_management scenarios' do
        let(:source) { project }
        let(:members) { [project_member, create(:project_member, :developer, project: project)] }
      end

      it_behaves_like 'member_promotion_management scenarios' do
        let(:source) { group }
        let(:members) { [group_member, create(:group_member, :developer, group: group)] }
      end
    end
  end

  context 'when block seat overages is enabled', :saas do
    let_it_be_with_refind(:group) { create(:group, owners: user) }

    before_all do
      create(:gitlab_subscription, :ultimate, namespace: group, seats: 1)
      group.namespace_settings.update!(seat_control: :block_overages)
    end

    it 'rejects promoting a user in a subgroup if there is no seat available' do
      subgroup = create(:group, parent: group)
      member = subgroup.add_guest(create(:user))
      params = { access_level: ::Gitlab::Access::DEVELOPER, source: group }

      result = described_class.new(user, params).execute(member)

      expect(result[:status]).to eq(:error)
      expect(member.reload.access_level).to eq(::Gitlab::Access::GUEST)
    end

    it 'rejects multiple member promotions if there are not enough seats available' do
      group.gitlab_subscription.update!(seats: 2)
      member_a = group.add_guest(create(:user))
      member_b = group.add_guest(create(:user))
      params = { access_level: ::Gitlab::Access::DEVELOPER, source: group }

      result = described_class.new(user, params).execute([member_a, member_b])

      expect(result[:status]).to eq(:error)
      expect(member_a.reload.access_level).to eq(::Gitlab::Access::GUEST)
      expect(member_b.reload.access_level).to eq(::Gitlab::Access::GUEST)
    end

    it 'handles an empty array of members' do
      params = { access_level: ::Gitlab::Access::DEVELOPER, source: group }

      result = described_class.new(user, params).execute([])

      expect(result[:status]).to eq(:success)
    end

    it 'allows bot users updates' do
      bot_member = group.add_developer(create(:user, :bot))

      params = { access_level: ::Gitlab::Access::MAINTAINER, source: group }

      result = described_class.new(user, params).execute(bot_member)

      expect(result[:status]).to eq(:success)
      expect(bot_member.reload.access_level).to eq(::Gitlab::Access::MAINTAINER)
    end
  end

  context 'with block seat overages enabled for self-managed' do
    let_it_be(:user) { create(:user) }
    let_it_be(:owner) { create(:user) }
    let_it_be_with_refind(:group) { create(:group) }

    let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
    let(:available_seats) { 1 }
    let(:seat_control_block_overages) { 2 }
    let(:seat_control_off) { 0 }

    let_it_be(:billable_custom_role) do
      create(:member_role, :instance, :billable)
    end

    before_all do
      group.add_owner(owner)
    end

    before do
      stub_licensed_features(custom_roles: true)
      stub_application_setting(seat_control: seat_control_block_overages)
      allow(License).to receive(:current).and_return(license)
      allow(License).to receive_message_chain(:current, :seats).and_return(available_seats)
    end

    it 'allows updating billable members even if there are no seats available' do
      member = group.add_developer(create(:user))
      params = { expires_at: 1.day.from_now, source: group }

      result = described_class.new(owner, params).execute(member)

      expect(result[:status]).to eq(:success)
    end

    it 'rejects promoting members to billable roles when no seats are available' do
      member = group.add_guest(create(:user))
      params = { access_level: Gitlab::Access::DEVELOPER, source: group }

      result = described_class.new(owner, params).execute(member)

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq("Could not update role because there are no available seats in this group")
      expect(member.reload.access_level).to eq(Gitlab::Access::GUEST)
    end

    context 'with custom roles' do
      it 'rejects promoting to a billable custom role when there are no seats available' do
        member = group.add_guest(create(:user))
        params = { member_role_id: billable_custom_role.id, source: group }

        result = described_class.new(owner, params).execute(member)

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Could not update role because there are no available seats in this group")
        expect(member.reload.member_role).to be_nil
      end
    end

    context 'when setting is disabled' do
      before do
        stub_application_setting(seat_control: seat_control_off)
      end

      it 'allows promoting members even when no seats are available' do
        member = group.add_guest(create(:user))
        params = { access_level: Gitlab::Access::DEVELOPER, source: group }

        result = described_class.new(owner, params).execute(member)

        expect(result[:status]).to eq(:success)
        expect(member.reload.access_level).to eq(Gitlab::Access::DEVELOPER)
      end
    end
  end

  context 'when current user can update the given member' do
    let(:current_user) { user }

    before_all do
      project.add_maintainer(user)
      group.add_owner(user)
    end

    context 'when there are no new updates to the member' do
      it_behaves_like 'does not log an audit event' do
        let(:member) { group_member }
      end

      it_behaves_like 'does not log an audit event' do
        let(:source) { project }
        let(:member) { project_member }
      end
    end

    context 'when a member is updated' do
      let(:member) { group_member }

      context 'when expires_at is updated' do
        let(:new_expiration) { 30.days.from_now.to_date }

        it 'updates the expires_at' do
          expect { update_member }.to change { member.reload.expires_at }
        end

        it_behaves_like 'logs an audit event'
      end

      context 'when access_level is updated' do
        let(:new_access_level) { Gitlab::Access::OWNER }

        it 'updates the access_level' do
          expect { update_member }.to change { member.reload.access_level }
        end

        it_behaves_like 'logs an audit event'
      end

      describe '#after_execute' do
        let(:new_access_level) { Gitlab::Access::OWNER }

        it 'is invoked with correct args' do
          expect(service).to receive(:after_execute).with(
            action: :update,
            old_values_map: a_hash_including(
              access_level: member.access_level,
              human_access: member.human_access_labeled,
              expires_at: member.expires_at,
              member_role_id: member.member_role_id
            ),
            member: member
          )

          update_member
        end
      end
    end

    context 'when updating a member role of a member' do
      let(:member) { group_member }

      let_it_be(:member_role_guest) { create(:member_role, :guest, namespace: group) }
      let_it_be(:member_role_reporter) { create(:member_role, :reporter, namespace: group) }

      let(:params) { { member_role_id: target_member_role&.id, source: source } }

      context 'when custom_roles feature is not licensed' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        context 'when the member does not have any member role assigned yet' do
          let(:initial_member_role) { nil }
          let(:target_member_role) { member_role_guest }

          it 'does not assign the role' do
            expect { update_member }.not_to change { member.reload.member_role }
          end
        end

        context 'when downgrading to static role' do
          before do
            member.update!(member_role: initial_member_role)
          end

          let(:initial_member_role) { member_role_guest }
          let(:target_member_role) { nil }

          it_behaves_like 'correct member role assignment'
        end
      end

      context 'when custom_roles feature is licensed' do
        before do
          stub_licensed_features(custom_roles: true)
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        context 'when the member does not have any member role assigned yet' do
          let(:initial_member_role) { nil }
          let(:target_member_role) { member_role_guest }

          let(:audit_role_to) { "Custom role: #{member_role_guest.name}" }
          let(:audit_role_as) { "Custom role: #{member_role_guest.name}" }

          it_behaves_like 'correct member role assignment'

          it_behaves_like 'logs an audit event'
        end

        context 'when the user does not have access to the member role' do
          let(:initial_member_role) { nil }
          let(:target_member_role) { create(:member_role, :guest, namespace: create(:group)) }

          it 'returns not found error' do
            expect(update_member[:status]).to eq(:error)
            expect(update_member[:message]).to eq('Member role not found')
          end
        end

        context 'when assigning the user to an instance-level member role' do
          let(:current_user) { admin }
          let(:initial_member_role) { nil }
          let(:target_member_role) { create(:member_role, :guest, :instance) }

          context 'on self-managed', :enable_admin_mode do
            before do
              stub_saas_features(gitlab_com_subscriptions: false)
            end

            it_behaves_like 'correct member role assignment'
          end
        end

        context 'when the member has a member role assigned' do
          before do
            member.update!(member_role: initial_member_role)
          end

          let(:initial_member_role) { member_role_guest }
          let(:target_member_role) { member_role_reporter }

          let(:audit_role_from) { "Custom role: #{member_role_guest.name}" }
          let(:audit_role_to) { "Custom role: #{member_role_reporter.name}" }
          let(:audit_role_as) { "Custom role: #{member_role_reporter.name}" }

          it_behaves_like 'correct member role assignment'

          it_behaves_like 'logs an audit event'

          it 'changes the access level of the member accordingly' do
            update_member

            expect(member.reload.access_level).to eq(target_member_role.base_access_level)
          end

          context 'when invalid access_level is provided' do
            let(:params) do
              { member_role_id: target_member_role&.id, access_level: GroupMember::DEVELOPER, source: source }
            end

            it 'returns error' do
              expect(update_member[:status]).to eq(:error)
            end
          end
        end

        context 'when downgrading to static role' do
          before do
            member.update!(member_role: initial_member_role)
          end

          let(:initial_member_role) { member_role_guest }
          let(:target_member_role) { nil }

          it_behaves_like 'correct member role assignment'
        end

        describe 'Authz::UserGroupMemberRole records of the member' do
          let(:initial_member_role) { nil }
          let(:target_member_role) { member_role_guest }

          it_behaves_like 'correct member role assignment'

          it 'calls update_user_group_member_roles on the updated member' do
            expect_next_found_instance_of(GroupMember) do |instance|
              expect(instance).to receive(:update_user_group_member_roles)
                .with(old_values_map: a_hash_including(member_role_id: nil))
            end

            update_member
          end
        end
      end
    end
  end

  context 'when current user has admin_group_member custom permission' do
    let_it_be_with_reload(:current_user) { create(:user) }
    let_it_be_with_reload(:root_ancestor) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_ancestor) }

    let(:params) { { access_level: role, source: source } }

    shared_context 'with member role in group' do
      let_it_be_with_reload(:member_role) do
        create(:member_role, base_access_level: current_role, namespace: root_ancestor, admin_group_member: true)
      end

      let_it_be_with_reload(:current_member) do
        create(:group_member, access_level: current_role, group: root_ancestor, user: current_user,
          member_role: member_role)
      end
    end

    shared_examples 'updating members using custom permission' do
      let_it_be_with_reload(:member) do
        create(:group_member, :minimal_access, group: group)
      end

      include_context 'with member role in group'

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'when updating member to the same access role as current user' do
          let(:role) { current_role }

          it 'updates the member' do
            expect { update_member }.to change { member.access_level }.to(role)
          end
        end

        context 'when updating member to higher role than current user' do
          let(:role) { higher_role }

          it 'raises an error' do
            expect { update_member }.to raise_error { Gitlab::Access::AccessDeniedError }
          end
        end
      end

      context 'when custom_roles feature is disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        context 'when updating member to the same access role as current user' do
          let(:role) { current_role }

          it 'fails to update the member' do
            expect { update_member }.to raise_error { Gitlab::Access::AccessDeniedError }
          end
        end
      end
    end

    shared_examples 'updating members using custom permission in a group' do
      context 'for guest member role' do
        let_it_be(:current_role) { Gitlab::Access::GUEST }
        let_it_be(:higher_role) { Gitlab::Access::REPORTER }

        it_behaves_like 'updating members using custom permission'

        context 'when downgrading member role' do
          let(:member) { create(:group_member, :maintainer, group: group) }
          let(:role) { Gitlab::Access::REPORTER }

          include_context 'with member role in group'

          before do
            stub_licensed_features(custom_roles: true)
          end

          it 'raises an error' do
            expect { update_member }.to raise_error(Gitlab::Access::AccessDeniedError)
          end
        end
      end

      context 'for reporter member role' do
        let_it_be(:current_role) { Gitlab::Access::REPORTER }
        let_it_be(:higher_role) { Gitlab::Access::DEVELOPER }

        it_behaves_like 'updating members using custom permission'
      end

      context 'for developer member role' do
        let_it_be(:current_role) { Gitlab::Access::DEVELOPER }
        let_it_be(:higher_role) { Gitlab::Access::MAINTAINER }

        it_behaves_like 'updating members using custom permission'
      end

      context 'for maintainer member role' do
        let_it_be(:current_role) { Gitlab::Access::MAINTAINER }
        let_it_be(:higher_role) { Gitlab::Access::OWNER }

        it_behaves_like 'updating members using custom permission'
      end
    end

    context 'when updating a member of the root group' do
      let_it_be(:group) { root_ancestor }

      it_behaves_like 'updating members using custom permission in a group'
    end

    context 'when updating a member of the subgroup' do
      let_it_be(:group) { subgroup }

      it_behaves_like 'updating members using custom permission in a group'
    end
  end
end
