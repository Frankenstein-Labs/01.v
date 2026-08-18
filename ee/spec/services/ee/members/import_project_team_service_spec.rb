# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ImportProjectTeamService, feature_category: :groups_and_projects do
  describe '#execute' do
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:source_project) { create(:project, guests: user) }
    let_it_be_with_refind(:target_project) { create(:project, group: group, maintainers: user) }

    let(:source_project_id) { source_project.id }
    let(:target_project_id) { target_project.id }

    subject(:import) { described_class.new(user, { id: target_project_id, project_id: source_project_id }) }

    context 'when the project team import fails' do
      context 'when the target project has locked their membership' do
        context 'for locking via the parent group' do
          before do
            target_project.group.update!(membership_lock: true)
          end

          it 'returns unsuccessful response' do
            result = import.execute

            expect(result).to be_a(ServiceResponse)
            expect(result.error?).to be(true)
            expect(result.message).to eq('Forbidden')
            expect(result.reason).to eq(:import_project_team_forbidden_error)
          end
        end

        context 'for locking via LDAP' do
          before do
            stub_application_setting(lock_memberships_to_ldap: true)
          end

          it 'returns unsuccessful response' do
            result = import.execute

            expect(result).to be_a(ServiceResponse)
            expect(result.error?).to be(true)
            expect(result.message).to eq('Forbidden')
            expect(result.reason).to eq(:import_project_team_forbidden_error)
          end
        end
      end
    end

    context 'when block seat overages is disabled', :saas do
      let_it_be(:subscription) { create(:gitlab_subscription, :ultimate, namespace: group, seats: 1) }

      before_all do
        group.namespace_settings.update!(seat_control: :off)
      end

      it 'imports additional members even if there are no seats left in the subscription' do
        group.add_developer(create(:user))

        result = import.execute

        expect(result.success?).to be(true)
        expect(result.message).to eq('Successfully imported')
        expect(target_project.reload.members.map(&:user_id)).to contain_exactly(user.id, source_project.owner.id)
      end
    end

    context 'when block seat overages is enabled', :saas, :use_clean_rails_memory_store_caching do
      let_it_be(:subscription) { create(:gitlab_subscription, :ultimate, namespace: group, seats: 2) }

      let(:owner_message) { s_('AddMember|There are not enough available seats to invite this many users.') }
      let(:maintainer_message) do
        s_('AddMember|There are not enough available seats to invite this many users. ' \
           'Ask a user with the Owner role to purchase more seats.')
      end

      before_all do
        group.namespace_settings.update!(seat_control: :block_overages)
      end

      context 'when there are no seats left in the subscription' do
        before_all do
          group.add_developer(create(:user))
        end

        it 'rejects the additional members' do
          result = import.execute

          expect(result.error?).to be(true)
          expect(result.message).to eq(maintainer_message)
          expect(result.reason).to eq(:seat_limit_exceeded_error)
          expect(target_project.reload.members.map(&:user_id)).to contain_exactly(user.id)
        end

        context 'when the user is a group owner' do
          before_all do
            group.add_owner(user)
          end

          it 'rejects the additional members with a message for the owner' do
            result = import.execute

            expect(result.error?).to be(true)
            expect(result.message).to eq(owner_message)
            expect(result.reason).to eq(:seat_limit_exceeded_error)
            expect(target_project.reload.members.map(&:user_id)).to contain_exactly(user.id)
          end
        end
      end

      context 'when there are seats left in the subscription' do
        it 'imports the additional members' do
          result = import.execute

          expect(result.success?).to be(true)
          expect(result.message).to eq('Successfully imported')
          expect(target_project.reload.members.map(&:user_id)).to contain_exactly(user.id, source_project.owner.id)
        end

        context 'when importing more members than there are seats remaining' do
          before_all do
            source_project.add_developer(create(:user))
          end

          it 'rejects all the members' do
            result = import.execute

            expect(result.error?).to be(true)
            expect(result.message).to eq(maintainer_message)
            expect(result.reason).to eq(:seat_limit_exceeded_error)
            expect(target_project.reload.members.map(&:user_id)).to contain_exactly(user.id)
          end
        end
      end

      context 'with a target project in a subgroup' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:subgroup_project) { create(:project, group: subgroup) }

        let(:target_project_id) { subgroup_project.id }

        before_all do
          subgroup_project.add_maintainer(user)
        end

        it 'rejects the additional members when there are not enough seats left in the subscription' do
          group.add_developer(create(:user))

          result = import.execute

          expect(result.error?).to be(true)
          expect(result.message).to eq(maintainer_message)
          expect(result.reason).to eq(:seat_limit_exceeded_error)
          expect(subgroup_project.reload.members.map(&:user_id)).to contain_exactly(user.id)
        end
      end
    end

    context 'with the licensed feature for disable_invite_members' do
      shared_examples 'successful import' do
        it 'imports the members' do
          result = import.execute

          expect(result.success?).to be(true)
        end
      end

      shared_examples 'failed import' do
        it 'does not import the members' do
          result = import.execute

          expect(result.success?).to be(false)
          expect(result.message).to eq('Forbidden')
        end
      end

      context 'when the user is a project maintainer' do
        context 'and the licensed feature is available' do
          before do
            stub_licensed_features(disable_invite_members: true)
          end

          context 'and the setting disable_invite_members is ON' do
            before do
              stub_application_setting(disable_invite_members: true)
            end

            it_behaves_like 'failed import'
          end

          context 'and the setting disable_invite_members is OFF' do
            before do
              stub_application_setting(disable_invite_members: false)
            end

            it_behaves_like 'successful import'
          end
        end

        context 'and the licensed feature is unavailable' do
          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(disable_invite_members: true)
          end

          it_behaves_like 'successful import'
        end
      end

      context 'when the user is an admin and the setting disable_invite_members is ON' do
        let_it_be(:user) { create(:admin) }

        before do
          stub_licensed_features(disable_invite_members: true)
          stub_application_setting(disable_invite_members: true)
        end

        context 'with admin mode enabled', :enable_admin_mode do
          before_all do
            target_project.add_maintainer(user)
          end

          it_behaves_like 'successful import'
        end

        it_behaves_like 'failed import'
      end
    end
  end
end
