# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::Groups::CreatorService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }

  describe '.add_member' do
    context 'when the current user has permission via a group link' do
      let_it_be(:current_user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:other_group) { create(:group) }
      let_it_be(:group_link) { create(:group_group_link, :owner, shared_group: group, shared_with_group: other_group) }
      let_it_be(:invitee_user) { create(:user) }

      before_all do
        other_group.add_owner(current_user)
      end

      where(:role, :access_level) do
        [
          [:guest, Gitlab::Access::GUEST],
          [:reporter, Gitlab::Access::REPORTER],
          [:developer, Gitlab::Access::DEVELOPER],
          [:maintainer, Gitlab::Access::MAINTAINER],
          [:owner, Gitlab::Access::OWNER]
        ]
      end

      with_them do
        subject(:member) do
          described_class.add_member(
            group,
            invitee_user,
            role,
            current_user: current_user
          )
        end

        it "adds member with role: #{params[:role]}" do
          expect(member).to be_persisted
          expect(member.access_level).to eq(access_level)
        end
      end

      context 'with a custom role' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'with a single group link' do
          let_it_be(:role) { create(:member_role, :developer, :admin_vulnerability, namespace: group) }
          let_it_be(:invited_user) { create(:user) }

          subject(:member) do
            described_class.add_member(
              group,
              invited_user,
              :developer,
              current_user: current_user,
              member_role_id: role.id
            )
          end

          it 'creates the membership' do
            expect(member).to be_present
            expect(member).to be_persisted
            expect(member.user).to eq(invited_user)
            expect(member.member_role).to eq(role)
            expect(member.access_level).to eq(Member::DEVELOPER)
          end
        end

        context 'with multiple group links in a complex nested group hierarchy' do
          let_it_be(:gitlab) { create(:group, name: "gitlab-org") }
          let_it_be(:secure) { create(:group, parent: gitlab, name: "secure") }
          let_it_be(:managers) { create(:group, parent: secure, name: "managers") }
          let_it_be(:security_products) { create(:group, parent: gitlab, name: "security products") }
          let_it_be(:analyzers) { create(:group, parent: security_products, name: "analyzers") }

          let_it_be(:manager) { create(:user) }
          let_it_be(:developer) { create(:user) }
          let_it_be(:gitlab_member) { create(:group_member, :developer, user: manager, source: gitlab) }
          let_it_be(:managers_member) { create(:group_member, :owner, user: manager, source: managers) }
          let_it_be(:role) { create(:member_role, :developer, :admin_vulnerability, namespace: gitlab) }

          subject(:member) do
            described_class.add_member(
              analyzers,
              developer,
              :developer,
              current_user: manager,
              member_role_id: role.id
            )
          end

          before_all do
            create(:group_group_link, {
              shared_group: managers,
              shared_with_group: gitlab,
              group_access: Gitlab::Access::DEVELOPER
            })
            create(:group_group_link, {
              shared_group: analyzers,
              shared_with_group: managers,
              group_access: Gitlab::Access::OWNER
            })
          end

          it 'creates the membership', :aggregate_failures do
            expect(member).to be_present
            expect(member).to be_valid
            expect(member.errors.full_messages).to be_empty
            expect(member).to be_persisted
            expect(member.user).to eq(developer)
            expect(member.member_role).to eq(role)
            expect(member.access_level).to eq(Member::DEVELOPER)
          end
        end
      end
    end

    context 'for free user limit considerations', :saas do
      let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        stub_ee_application_setting(dashboard_limit: 1)
        stub_ee_application_setting(dashboard_limit_enabled: true)
        create(:group_member, source: group)
      end

      context 'when ignore_user_limits is not passed and uses default' do
        it 'fails to add the member' do
          member = described_class.add_member(group, user, :owner)

          expect(member).not_to be_persisted
          expect(group).not_to have_user(user)
          expect(member.errors.full_messages).to include(/cannot be added since you've reached/)
        end
      end

      context 'when ignore_user_limits is passed as true' do
        it 'adds the member' do
          member = described_class.add_member(group, user, :owner, ignore_user_limits: true)

          expect(member).to be_persisted
        end
      end

      context 'when current user has admin_group_member custom permission' do
        let_it_be(:current_user) { create(:user) }
        let_it_be(:root_ancestor) { create(:group) }
        let_it_be(:subgroup) { create(:group, parent: root_ancestor) }

        let(:params) { { member_role_id: member_role.id, current_user: current_user } }

        shared_examples 'adding members using custom permission' do
          let_it_be(:member_role) do
            create(:member_role, base_access_level: current_role, namespace: root_ancestor, admin_group_member: true)
          end

          let_it_be(:member) do
            create(:group_member, access_level: current_role, group: root_ancestor, user: current_user,
              member_role: member_role)
          end

          subject(:add_member) do
            described_class.add_member(group, user, role, **params)
          end

          context 'when custom_roles feature is enabled' do
            before do
              stub_licensed_features(custom_roles: true)
            end

            context 'when adding members with the same access role as current user' do
              let(:role) { current_role }

              it 'adds members' do
                expect { add_member }.to change { group.members.count }.by(1)
              end
            end

            context 'when adding members with higher role than current user' do
              let(:role) { higher_role }

              it 'fails to add the member' do
                member = add_member

                expect(member).not_to be_persisted
                expect(group).not_to have_user(user)
                expect(member.errors.full_messages)
                  .to include(/the member access level can't be higher than the current user's one/)
              end
            end
          end

          context 'when custom_roles feature is disabled' do
            before do
              stub_licensed_features(custom_roles: false)
            end

            context 'when adding members with the same access role as current user' do
              let(:role) { current_role }

              it 'does not add members' do
                expect { add_member }.not_to change { group.members.count }
              end
            end
          end
        end

        shared_examples 'adding members using custom permission to a group' do
          context 'for guest member role' do
            let_it_be(:current_role) { Gitlab::Access::GUEST }
            let_it_be(:higher_role) { Gitlab::Access::REPORTER }

            it_behaves_like 'adding members using custom permission'
          end

          context 'for reporter member role' do
            let_it_be(:current_role) { Gitlab::Access::REPORTER }
            let_it_be(:higher_role) { Gitlab::Access::DEVELOPER }

            it_behaves_like 'adding members using custom permission'
          end

          context 'for developer member role' do
            let_it_be(:current_role) { Gitlab::Access::DEVELOPER }
            let_it_be(:higher_role) { Gitlab::Access::MAINTAINER }

            it_behaves_like 'adding members using custom permission'
          end

          context 'for maintainer member role' do
            let_it_be(:current_role) { Gitlab::Access::MAINTAINER }
            let_it_be(:higher_role) { Gitlab::Access::OWNER }

            it_behaves_like 'adding members using custom permission'
          end
        end

        context 'when adding a member to the root group' do
          let(:group) { root_ancestor }

          it_behaves_like 'adding members using custom permission to a group'
        end

        context 'when adding a member to the subgroup' do
          let(:group) { subgroup }

          it_behaves_like 'adding members using custom permission to a group'
        end
      end
    end

    context 'when a `member_role_id` is passed', feature_category: :permissions do
      let_it_be(:group) { create(:group) }
      let_it_be(:member_role) { create(:member_role, :developer, namespace: group) }

      subject(:member) { described_class.add_member(group, user, :developer, member_role_id: member_role.id) }

      context 'when custom roles are enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'saves the `member_role`' do
          expect(member).to be_persisted
          expect(member.member_role).to eq(member_role)
        end

        it 'calls update_user_group_member_roles on the new member with correct args' do
          expect_next_instance_of(GroupMember) do |instance|
            expect(instance).to receive(:update_user_group_member_roles).with(old_values_map: a_hash_including(
              access_level: nil, member_role_id: nil))
          end

          member
        end

        context 'when user is an existing member of the group' do
          it 'calls update_user_group_member_roles on the member with correct args' do
            # Initial addition to the group
            expect_next_instance_of(GroupMember) do |instance|
              expect(instance).to receive(:update_user_group_member_roles)
                .with(old_values_map: a_hash_including(access_level: nil, member_role_id: nil))
            end

            existing_member = member

            # Update existing membership
            expect_next_found_instance_of(GroupMember) do |instance|
              expect(instance).to receive(:update_user_group_member_roles)
                .with(old_values_map: a_hash_including(access_level: existing_member.access_level,
                  member_role_id: existing_member.member_role_id))
            end

            described_class.add_member(group, user, :owner)
          end
        end
      end

      context 'when custom roles are not enabled' do
        it 'does not save the `member_role`' do
          expect(member.member_role).to eq(nil)
        end
      end
    end

    context 'when adding a service_account member' do
      let_it_be(:source) { create(:group) }
      let_it_be(:group_owner) { create(:user) }

      before_all do
        source.add_owner(group_owner)
      end

      context 'when service account is a regular service account' do
        let_it_be(:user) { create(:user, :service_account) }

        before do
          allow(group_owner).to receive(:can?).and_return(false)
          allow(group_owner).to receive(:can?).with(:admin_service_account_member, anything).and_return(true)
        end

        it 'checks the appropriate permission' do
          member = described_class.add_member(source, user, :maintainer, current_user: group_owner)

          expect(member).to be_a GroupMember
          expect(member).to be_persisted
        end

        it 'calls MembershipEligibilityChecker to check eligibility' do
          checker_instance = instance_double(::Members::ServiceAccounts::EligibilityChecker)
          allow(::Members::ServiceAccounts::EligibilityChecker)
            .to receive(:new).with(target_group: source).and_return(checker_instance)
          allow(checker_instance).to receive(:eligible?).and_return(true)

          described_class.add_member(source, user, :maintainer, current_user: group_owner)

          expect(::Members::ServiceAccounts::EligibilityChecker)
            .to have_received(:new).with(target_group: source)
          expect(checker_instance).to have_received(:eligible?).with(user)
        end
      end

      context 'with composite identity service accounts' do
        let_it_be(:subgroup) { create(:group, parent: source) }
        let_it_be(:other_group) { create(:group) }

        context 'when feature is available' do
          before do
            stub_saas_features(service_accounts_invite_restrictions: true)
          end

          context 'when service account is provisioned in the same group hierarchy' do
            let_it_be(:user) do
              create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: source)
            end

            before do
              allow(group_owner).to receive(:can?).and_return(false)
              allow(group_owner).to receive(:can?).with(:admin_service_account_member, anything).and_return(true)
            end

            it 'allows adding the service account' do
              member = described_class.add_member(source, user, :maintainer, current_user: group_owner)

              expect(member).to be_a GroupMember
              expect(member).to be_persisted
            end
          end

          context 'when service account is provisioned in a parent group' do
            let_it_be(:user) do
              create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: source)
            end

            before do
              allow(group_owner).to receive(:can?).and_return(false)
              allow(group_owner).to receive(:can?).with(:admin_service_account_member, anything).and_return(true)
            end

            it 'allows adding the service account to a subgroup' do
              subgroup.add_owner(group_owner)
              member = described_class.add_member(subgroup, user, :maintainer, current_user: group_owner)

              expect(member).to be_a GroupMember
              expect(member).to be_persisted
            end
          end

          context 'when service account is provisioned outside the group hierarchy' do
            let_it_be(:user) do
              create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
            end

            before do
              allow(group_owner).to receive(:can?).and_return(false)
              allow(group_owner).to receive(:can?).with(:admin_service_account_member, anything).and_return(true)
            end

            it 'prevents adding the service account' do
              member = described_class.add_member(source, user, :maintainer, current_user: group_owner)

              expect(member).not_to be_persisted
              expect(member.errors.full_messages).to include(/not authorized to create member/)
            end
          end

          context 'when service account is provisioned in a subgroup' do
            let_it_be(:user) do
              create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup)
            end

            before do
              allow(group_owner).to receive(:can?).and_return(false)
              allow(group_owner).to receive(:can?).with(:admin_service_account_member, anything).and_return(true)
            end

            it 'prevents adding the service account to parent group' do
              member = described_class.add_member(source, user, :maintainer, current_user: group_owner)

              expect(member).not_to be_persisted
              expect(member.errors.full_messages).to include(/not authorized to create member/)
            end
          end

          context 'when service account is instance-wide' do
            let_it_be(:user) do
              create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)
            end

            before do
              allow(group_owner).to receive(:can?).and_return(false)
              allow(group_owner).to receive(:can?).with(:admin_service_account_member, anything).and_return(true)
            end

            it 'allows adding the service account' do
              member = described_class.add_member(source, user, :maintainer, current_user: group_owner)

              expect(member).to be_a GroupMember
              expect(member).to be_persisted
            end
          end
        end

        context 'when feature is not available' do
          let_it_be(:user) do
            create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
          end

          before do
            stub_saas_features(service_accounts_invite_restrictions: false)
            allow(group_owner).to receive(:can?).and_return(false)
            allow(group_owner).to receive(:can?).with(:admin_service_account_member, anything).and_return(true)
          end

          it 'allows adding the service account from outside hierarchy' do
            member = described_class.add_member(source, user, :maintainer, current_user: group_owner)

            expect(member).to be_a GroupMember
            expect(member).to be_persisted
          end
        end
      end
    end

    context 'when inviting or promoting a member to a billable role' do
      let_it_be(:source) { create(:group) }
      let(:existing_role) { :guest }
      let!(:existing_member) { create(:group_member, existing_role, user: user, group: source) }

      it_behaves_like 'billable promotion management feature'
    end

    context 'with the licensed feature for disable_invite_members' do
      let_it_be(:group) { create(:group) }
      let_it_be(:user) { create(:user) }
      let_it_be(:access_level) { :maintainer }

      shared_examples 'successful member creation' do
        it 'creates a new member' do
          member = described_class.add_member(group, user, access_level, current_user: current_user)
          expect(member).to be_persisted
        end
      end

      shared_examples 'failed member creation' do
        it 'does not create a new member' do
          member = described_class.add_member(group, user, access_level, current_user: current_user)
          expect(member).not_to be_persisted
          expect(member.errors.full_messages).to include(/not authorized to create member/)
        end
      end

      context 'when the user is a group owner' do
        let_it_be(:current_user) { create(:user) }

        before_all do
          group.add_owner(current_user)
        end

        context 'when the licensed feature for disable_invite_members is available' do
          before do
            stub_licensed_features(disable_invite_members: true)
          end

          context 'when the setting disable_invite_members is ON' do
            before do
              stub_application_setting(disable_invite_members: true)
            end

            it_behaves_like 'failed member creation'
          end

          context 'when the setting disable_invite_members is OFF' do
            before do
              stub_application_setting(disable_invite_members: false)
            end

            it_behaves_like 'successful member creation'
          end
        end

        context 'when the licensed feature for disable_invite_members is unavailable' do
          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(disable_invite_members: true)
          end

          it_behaves_like 'successful member creation'
        end
      end

      context 'when the user is an admin and the setting disable_invite_members is ON' do
        let_it_be(:current_user) { create(:admin) }

        before do
          stub_licensed_features(disable_invite_members: true)
          stub_application_setting(disable_invite_members: true)
        end

        context 'with admin mode enabled', :enable_admin_mode do
          it_behaves_like 'successful member creation'
        end

        it_behaves_like 'failed member creation'
      end
    end
  end

  describe '.add_members' do
    context 'when inviting or promoting a member to a billable role' do
      let_it_be(:source) { create(:group) }
      let(:existing_role) { :guest }
      let!(:existing_member) { create(:group_member, existing_role, user: user, group: source) }

      it_behaves_like 'billable promotion management for multiple users'
    end
  end
end
