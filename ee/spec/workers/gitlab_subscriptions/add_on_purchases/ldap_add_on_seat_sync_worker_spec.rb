# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::LdapAddOnSeatSyncWorker, feature_category: :seat_cost_management do
  include LdapHelpers

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  describe '#perform' do
    let_it_be(:provider) { 'ldapmain' }
    let_it_be(:extern_uid_1) { 'uid=john,ou=people,dc=example,dc=com'  }
    let_it_be(:extern_uid_2) { 'uid=mary,ou=people,dc=example,dc=com'  }

    let_it_be(:user) { create(:omniauth_user, provider: provider, extern_uid: extern_uid_1) }
    let_it_be(:other_user) { create(:omniauth_user, provider: provider, extern_uid: extern_uid_2) }

    let_it_be_with_reload(:add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        :duo_enterprise,
        :active,
        :self_managed,
        quantity: 2
      )
    end

    let(:group_cn) { 'duo_group' }
    let(:duo_add_on_groups) { [group_cn] }
    let(:group_member_dns) { [extern_uid_1] }

    before do
      fake_proxy = fake_ldap_sync_proxy(provider)
      allow(fake_proxy).to receive(:dns_for_group_cn).with(group_cn).and_return(group_member_dns)

      stub_ldap_config(duo_add_on_groups: [group_cn])

      create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: other_user)
    end

    describe '#perform' do
      let(:user_id) { user.id }
      let(:params) { { 'user_id' => user_id } }

      subject(:perform) { described_class.new.perform(params) }

      shared_examples 'does not sync any seat assignments' do
        it 'returns early' do
          expect(GitlabSubscriptions::UserAddOnAssignments::SelfManaged::CreateService).not_to receive(:new)
          expect(GitlabSubscriptions::Duo::BulkUnassignService).not_to receive(:new)

          expect { perform }.not_to change { GitlabSubscriptions::UserAddOnAssignment.count }
        end
      end

      context 'when user does not exists' do
        let(:user_id) { non_existing_record_id }

        it_behaves_like 'does not sync any seat assignments'
      end

      context 'when user does not have ldap_identity' do
        let(:user) { create(:user) }

        it_behaves_like 'does not sync any seat assignments'
      end

      context 'when ldap_identity does not have provider set' do
        before do
          allow_next_found_instance_of(Identity) do |ldap_identity|
            allow(ldap_identity).to receive(:provider).and_return(nil)
          end
        end

        it_behaves_like 'does not sync any seat assignments'
      end

      context 'when duo_add_on_groups config is not set' do
        before do
          stub_ldap_config(duo_add_on_groups: nil)
        end

        it_behaves_like 'does not sync any seat assignments'
      end

      context 'when there is not any active Duo Add-on' do
        before do
          add_on_purchase.update!(expires_on: 1.year.ago)
        end

        it_behaves_like 'does not sync any seat assignments'
      end

      it_behaves_like 'an idempotent worker' do
        let(:job_args) { { 'user_id' => user_id } }

        it 'assigns seat to the user' do
          expect { perform_idempotent_work }.to change { add_on_purchase.assigned_users.by_user(user).count }.by(1)
        end

        context 'when there are no more seats available' do
          before do
            add_on_purchase.update!(quantity: 1)
          end

          it 'does not assign seat' do
            expect { perform }.not_to change { add_on_purchase.reload.assigned_users.count }
          end
        end

        context 'when the ldap user does not belongs to duo_add_on_groups' do
          let(:user_id) { other_user.id }

          it 'removes the assigned seat' do
            expect { perform }.to change { add_on_purchase.reload.assigned_users.by_user(other_user).count }.by(-1)
          end

          context 'when user does not have any seat assigned' do
            before do
              add_on_purchase.assigned_users.by_user(other_user).delete_all
              add_on_purchase.assigned_users.create!(user: create(:user))
            end

            it 'does not remove other existing seats' do
              expect { perform }.not_to change { add_on_purchase.reload.assigned_users.count }
            end
          end
        end
      end
    end
  end
end
