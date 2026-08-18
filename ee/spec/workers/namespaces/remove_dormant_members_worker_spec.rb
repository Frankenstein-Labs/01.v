# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::RemoveDormantMembersWorker, :saas, feature_category: :seat_cost_management do
  let(:worker) { described_class.new }

  describe '#perform_work' do
    subject(:perform_work) { worker.perform_work }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    context 'with Groups requiring dormant member review', :freeze_time do
      let_it_be_with_reload(:group) { create(:group) }

      before do
        group.namespace_settings.update!(remove_dormant_members: true, last_dormant_member_review_at: 2.days.ago)
      end

      context 'with dormant members', :enable_admin_mode do
        let_it_be(:active_assignment) do
          create(:gitlab_subscription_seat_assignment, namespace: group, last_activity_on: Time.zone.today)
        end

        let_it_be_with_reload(:dormant_assignment) do
          create(:gitlab_subscription_seat_assignment, namespace: group, last_activity_on: 91.days.ago)
        end

        it_behaves_like 'an idempotent worker' do
          it 'only removes dormant members' do
            expect { perform_work }.to change { Members::DeletionSchedule.count }.from(0).to(1)
          end

          it 'updates last_dormant_member_review_at' do
            expect { perform_work }.to change { group.namespace_settings.reload.last_dormant_member_review_at }
          end

          it 'logs monitoring data' do
            allow(Gitlab::AppLogger).to receive(:info)

            expect(Gitlab::AppLogger).to receive(:info).with(
              message: 'Processed dormant member removal',
              namespace_id: group.id,
              dormant_count: 1
            )

            perform_work
          end

          context 'when the dormant member is an owner of the group' do
            before_all do
              user = dormant_assignment.user
              create(:organization_user, user: user, organization: group.organization)
              group.add_owner(user)
            end

            it 'does not remove the owner' do
              expect { perform_work }.not_to change { Members::DeletionSchedule.count }
            end

            it 'logs deactivation skip reason' do
              allow(Gitlab::AppLogger).to receive(:info).and_call_original

              expect(Gitlab::AppLogger).to receive(:info).with(
                message: 'User deactivation skipped',
                reason: 'is_owner',
                user_id: dormant_assignment.user.id,
                namespace_id: group.id
              )

              perform_work
            end
          end

          context 'when the dormant member is a bot' do
            let_it_be(:bot_user) { create(:user, :project_bot) }

            before_all do
              dormant_assignment.update!(user: bot_user)
            end

            it 'does not remove the bot' do
              expect { perform_work }.not_to change { Members::DeletionSchedule.count }
            end

            it 'logs deactivation skip reason' do
              allow(Gitlab::AppLogger).to receive(:info).and_call_original

              expect(Gitlab::AppLogger).to receive(:info).with(
                message: 'User deactivation skipped',
                reason: 'bot_user',
                user_id: dormant_assignment.user.id,
                namespace_id: group.id
              )

              perform_work
            end
          end

          context 'when the dormant member is already deactivated' do
            before do
              dormant_assignment.user.deactivate!
            end

            it 'does not remove the user' do
              expect { perform_work }.not_to change { Members::DeletionSchedule.count }
            end

            it 'logs deactivation skip reason' do
              allow(Gitlab::AppLogger).to receive(:info).and_call_original

              expect(Gitlab::AppLogger).to receive(:info).with(
                message: 'User deactivation skipped',
                reason: 'deactivated_user',
                user_id: dormant_assignment.user.id,
                namespace_id: group.id
              )

              perform_work
            end
          end
        end

        context 'when group has non-default dormant period' do
          it 'respects the group dormant period' do
            group.namespace_settings.update!(remove_dormant_members_period: 150)
            expect do
              perform_work
            end.not_to change { Members::DeletionSchedule.count }
          end
        end

        context 'with dormant enterprise users' do
          let_it_be(:dormant_enterprise_user) { create(:enterprise_user, enterprise_group: group) }
          let_it_be(:other_group_enterprise_user) { create(:enterprise_user) }
          let_it_be(:dormant_regular_user) { create(:user) }

          before do
            create(:gitlab_subscription_seat_assignment, namespace: group, user: dormant_enterprise_user,
              last_activity_on: 91.days.ago)
            create(:gitlab_subscription_seat_assignment, namespace: group, user: other_group_enterprise_user,
              last_activity_on: 91.days.ago)
            create(:gitlab_subscription_seat_assignment, user: dormant_regular_user, last_activity_on: 91.days.ago)
          end

          it_behaves_like 'an idempotent worker' do
            it 'deactivates dormant enterprise users' do
              perform_work

              expect(dormant_enterprise_user.reload.deactivated?).to be true
              expect(other_group_enterprise_user.reload.deactivated?).to be false
            end

            it 'does not deactivate non-enterprise users' do
              perform_work

              expect(dormant_regular_user.reload.deactivated?).to be false
            end

            include_examples 'audit event logging' do
              let_it_be(:admin) do
                create(:user, :admin_bot, organization: dormant_enterprise_user.organization)
              end

              let(:operation) { perform_work }

              let(:fail_condition!) do
                allow_next_found_instance_of(User) do |user|
                  allow(user).to receive(:deactivate).and_return(false)
                end
              end

              let(:attributes) do
                {
                  author_id: admin.id,
                  entity_id: dormant_enterprise_user.id,
                  entity_type: 'User',
                  details: {
                    author_class: 'User',
                    author_name: admin.name,
                    event_name: 'user_deactivate',
                    custom_message: 'Deactivated user',
                    target_details: dormant_enterprise_user.username,
                    target_id: dormant_enterprise_user.id,
                    target_type: 'User'
                  }
                }
              end

              before do
                # this has to be stubbed, otherwise the next_found_instance_of stub above
                # will apply to admin_bot instead of the expected test user
                allow_next_instance_of(::Users::Internal) do |internal|
                  allow(internal).to receive(:admin_bot).and_return(admin)
                end
              end
            end
          end
        end
      end
    end

    context 'with no Namespaces requiring refresh' do
      let_it_be(:setting) do
        create(:namespace_settings, last_dormant_member_review_at: 1.hour.ago, remove_dormant_members: true)
      end

      it 'does not update last_dormant_member_review_at' do
        expect { perform_work }.not_to change { setting.reload.last_dormant_member_review_at }
      end
    end
  end

  describe '#max_running_jobs' do
    subject { worker.max_running_jobs }

    it { is_expected.to eq(described_class::MAX_RUNNING_JOBS) }
  end

  describe '#remaining_work_count', :freeze_time do
    let_it_be_with_reload(:namespaces_requiring_dormant_member_removal) do
      create_list(:namespace_settings, 8, last_dormant_member_review_at: 3.days.ago, remove_dormant_members: true)
    end

    subject(:remaining_work_count) { worker.remaining_work_count }

    context 'when there is remaining work' do
      it { is_expected.to eq(described_class::MAX_RUNNING_JOBS + 1) }
    end

    context 'when there is no remaining work' do
      before do
        namespaces_requiring_dormant_member_removal.map do |setting|
          setting.update!(last_dormant_member_review_at: Time.current)
        end
      end

      it { is_expected.to eq(0) }
    end
  end
end
