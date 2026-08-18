# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::Projects::CreatorService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:source) { create(:project) }
  let(:existing_role) { :guest }
  let!(:existing_member) { create(:project_member, existing_role, user: user, project: source) }

  describe '.add_member' do
    context 'when inviting or promoting a member to a billable role' do
      it_behaves_like 'billable promotion management feature'
    end

    context 'with the licensed feature for disable_invite_members' do
      let_it_be(:role) { :developer }
      let_it_be(:added_user) { create(:user) }

      shared_examples 'successful member creation' do
        it 'creates a new member' do
          member = described_class.add_member(source, added_user, role, current_user: current_user)
          expect(member).to be_persisted
        end
      end

      shared_examples 'failed member creation' do
        it 'does not create a new member' do
          member = described_class.add_member(source, added_user, role, current_user: current_user)
          expect(member).not_to be_persisted
          expect(member.errors.full_messages).to include(/not authorized to create member/)
        end
      end

      context 'when the user is a project maintainer' do
        let_it_be(:current_user) { create(:user) }

        before_all do
          source.add_maintainer(current_user)
        end

        context 'and the licensed feature is available' do
          before do
            stub_licensed_features(disable_invite_members: true)
          end

          context 'and the setting disable_invite_members is ON' do
            before do
              stub_application_setting(disable_invite_members: true)
            end

            it_behaves_like 'failed member creation'

            context 'when member user is a service account with composite identity enforced' do
              let(:added_user) { create(:user, :service_account, composite_identity_enforced: true) }

              it_behaves_like 'successful member creation'
            end

            context 'when member user is a service account without composite identity enforced' do
              let(:added_user) { create(:user, :service_account, composite_identity_enforced: false) }

              it_behaves_like 'failed member creation'
            end

            context 'when inviting a member by email address' do
              let(:added_user) { 'someuseremailaddress@gitlab.com' }

              it_behaves_like 'failed member creation'
            end
          end

          context 'and the setting disable_invite_members is OFF' do
            before do
              stub_application_setting(disable_invite_members: false)
            end

            it_behaves_like 'successful member creation'
          end
        end

        context 'and the licensed feature is unavailable' do
          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(disable_invite_members: true)
          end

          it_behaves_like 'successful member creation'
        end
      end

      context 'with SAML membership lock conditions' do
        let_it_be(:group) { create(:group) }
        let_it_be(:source) { create(:project, group: group) }
        let_it_be(:current_user) { create(:user) }

        before_all do
          source.add_owner(current_user)
        end

        before do
          stub_licensed_features(saml_group_sync: true)
          stub_application_setting(lock_memberships_to_saml: true)
          create(:saml_provider, group: group.root_ancestor, enabled: true)
          create(:saml_group_link, group: group)
          allow(::Gitlab::Auth::GroupSaml::Config).to receive_messages(enabled?: true)
        end

        it_behaves_like 'failed member creation'

        context 'when member user is a service account with composite identity enforced' do
          let(:added_user) { create(:user, :service_account, composite_identity_enforced: true) }

          it_behaves_like 'successful member creation'

          context 'when current user cannot administer service account membership' do
            let_it_be(:current_user) { create(:user) }

            it_behaves_like 'failed member creation'
          end
        end

        context 'when member user is a service account without composite identity enforced' do
          let(:added_user) { create(:user, :service_account, composite_identity_enforced: false) }

          it_behaves_like 'successful member creation'

          context 'when current user cannot administer service account membership' do
            let_it_be(:current_user) { create(:user) }

            it_behaves_like 'failed member creation'
          end

          context 'when disable_invite_members is also enabled' do
            before do
              stub_licensed_features(disable_invite_members: true)
              stub_application_setting(disable_invite_members: true)
            end

            it_behaves_like 'failed member creation'
          end
        end
      end

      context 'with LDAP membership lock conditions' do
        let_it_be(:current_user) { create(:user) }

        before_all do
          source.add_owner(current_user)
        end

        before do
          stub_application_setting(lock_memberships_to_ldap: true)
        end

        context 'when member user is a service account without composite identity enforced' do
          let(:added_user) { create(:user, :service_account, composite_identity_enforced: false) }

          it_behaves_like 'successful member creation'

          context 'when current user can administer service account membership but not plain project membership' do
            before do
              # ProjectPolicy does not gate `admin_project_member` on `lock_memberships_to_ldap`
              # alone (only the SAML variant, see EE::ProjectPolicy) -- so `admin_project_member`
              # being true would pass here regardless of this exemption existing. Forcing it
              # false isolates the actual branch under test: routing through
              # `admin_service_account_member` specifically, not `admin_project_member`.
              allow(current_user).to receive(:can?).and_call_original
              allow(current_user).to receive(:can?).with(:admin_project_member, source).and_return(false)
            end

            it_behaves_like 'successful member creation'
          end

          context 'when current user cannot administer service account membership' do
            let_it_be(:current_user) { create(:user) }

            it_behaves_like 'failed member creation'
          end
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

      context 'when the creator is adding themselves as owner in their personal namespace project' do
        let_it_be(:current_user) { create(:user, :with_namespace) }
        let_it_be(:personal_project) do
          create(:project, namespace: current_user.namespace, organization: current_user.namespace.organization)
        end

        let(:added_user) { current_user }

        before do
          stub_licensed_features(disable_invite_members: true)
          stub_application_setting(disable_invite_members: true)
          personal_project.members.find_by(user_id: current_user.id)&.destroy!
        end

        it 'creates the member successfully' do
          member = described_class.add_member(personal_project, added_user, :owner, current_user: current_user)
          expect(member).to be_persisted
        end

        context 'when the user is not a member of the project organization' do
          before do
            Organizations::OrganizationUser.where(
              user_id: current_user.id,
              organization_id: personal_project.organization_id
            ).delete_all
          end

          it 'still creates the member successfully' do
            member = described_class.add_member(personal_project, added_user, :owner, current_user: current_user)
            expect(member).to be_persisted
          end
        end

        context 'when inviting a different user to the personal project' do
          let(:added_user) { create(:user) }

          it 'does not create a new member' do
            member = described_class.add_member(personal_project, added_user, role, current_user: current_user)
            expect(member).not_to be_persisted
            expect(member.errors.full_messages).to include(/not authorized to create member/)
          end
        end
      end
    end

    context 'when current user has insufficient permissions to modify the member role' do
      let_it_be(:current_user) { create(:user) }
      let(:existing_role) { :owner }

      before_all do
        source.add_maintainer(current_user)
      end

      it 'does not update the member role and returns an error' do
        member = described_class.add_member(source, user, :developer, current_user: current_user)
        expect(member.errors.full_messages)
          .to include(/the member access level can't be higher than the current user's one/)
      end
    end
  end

  describe '.add_members' do
    context 'when inviting or promoting a member to a billable role' do
      it_behaves_like 'billable promotion management for multiple users'
    end
  end

  describe 'service account membership eligibility' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:service_account_user) { create(:user, :service_account) }

    before_all do
      source.add_owner(current_user)
    end

    context 'when adding a regular user' do
      let(:added_user) { create(:user) }

      it 'creates the member successfully' do
        member = described_class.add_member(source, added_user, :developer, current_user: current_user)
        expect(member).to be_persisted
      end
    end

    context 'when adding a service account' do
      let_it_be(:project_namespace) { source.namespace }

      context 'and the service account is eligible for membership' do
        it 'creates the member successfully and calls MembershipEligibilityChecker with target_project' do
          allow(::Members::ServiceAccounts::EligibilityChecker)
            .to receive(:new).with(target_project: source).and_call_original
          expect_next_instance_of(::Members::ServiceAccounts::EligibilityChecker) do |instance|
            expect(instance).to receive(:eligible?).with(service_account_user).and_return(true)
          end

          member = described_class.add_member(source, service_account_user, :developer, current_user: current_user)
          expect(member).to be_persisted
        end
      end

      context 'and the service account is not eligible for membership' do
        it 'does not create the member' do
          expect_next_instance_of(::Members::ServiceAccounts::EligibilityChecker) do |instance|
            expect(instance).to receive(:eligible?).with(service_account_user).and_return(false)
          end

          member = described_class.add_member(source, service_account_user, :developer, current_user: current_user)
          expect(member).not_to be_persisted
          expect(member.errors.full_messages).to include(/not authorized to create member/)
        end
      end
    end

    context 'when current user lacks admin_project_member permission' do
      let(:current_user) { create(:user) }

      it 'does not create the member even if service account is eligible' do
        expect_next_instance_of(::Members::ServiceAccounts::EligibilityChecker) do |instance|
          expect(instance).to receive(:eligible?).and_return(true)
        end

        member = described_class.add_member(source, service_account_user, :developer, current_user: current_user)
        expect(member).not_to be_persisted
        expect(member.errors.full_messages).to include(/not authorized to create member/)
      end
    end
  end
end
