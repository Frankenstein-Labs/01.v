# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::GitlabSubscriptions::PreviewBillableUserChangeService, feature_category: :subscription_management do
  describe '#execute' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:role) { :developer }

    shared_examples 'preview billable user change service' do
      context 'when target namespace exists', :saas do
        let(:eligible_for_usage_alerts) { true }
        let(:usage_alert_eligibility_service) do
          instance_double(GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService,
            execute: eligible_for_usage_alerts)
        end

        before do
          allow(GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService)
            .to receive(:new).and_return(usage_alert_eligibility_service)
        end

        context 'when adding users' do
          context 'by group id' do
            subject(:execute) do
              described_class.new(
                current_user: current_user,
                target_namespace: target_namespace,
                role: role,
                add_group_id: add_group_id
              ).execute
            end

            context 'when group exists' do
              let_it_be(:group_member_1) { create(:user) }
              let_it_be(:group_member_2) { create(:user) }
              let_it_be(:group) { create(:group, :private, developers: [group_member_1, group_member_2]) }
              let_it_be(:add_group_id) { group.id }

              context 'when current_user has access to view group' do
                before do
                  group.add_developer(current_user)
                end

                it 'counts group members' do
                  expect(execute).to include({
                    success: true,
                    data: {
                      will_increase_overage: true,
                      new_billable_user_count: 4,
                      seats_in_subscription: 0
                    }
                  })
                end

                context 'when group contains an existing user from target group' do
                  before do
                    group.add_developer(existing_user)
                  end

                  it 'does not count existing user' do
                    expect(execute).to include({
                      success: true,
                      data: {
                        will_increase_overage: true,
                        new_billable_user_count: 4,
                        seats_in_subscription: 0
                      }
                    })
                  end
                end
              end

              context 'when current_user does not have access to view group' do
                it 'does not count group members' do
                  expect(execute).to include({
                    success: true,
                    data: {
                      will_increase_overage: false,
                      new_billable_user_count: 1,
                      seats_in_subscription: 0
                    }
                  })
                end
              end
            end

            context 'when group does not exist' do
              let_it_be(:add_group_id) { non_existing_record_id }

              it 'returns successfully' do
                expect(execute).to include({
                  success: true,
                  data: { will_increase_overage: false, new_billable_user_count: 1, seats_in_subscription: 0 }
                })
              end
            end
          end

          context 'by email' do
            let_it_be(:user) { create(:user) }
            let_it_be(:add_user_emails) { [user.email, 'foo@example.com'] }

            subject(:execute) do
              described_class.new(
                current_user: current_user,
                target_namespace: target_namespace,
                role: role,
                add_user_emails: add_user_emails
              ).execute
            end

            it 'counts user emails and unassociated emails' do
              expect(execute).to include({
                success: true,
                data: {
                  will_increase_overage: true,
                  new_billable_user_count: 3,
                  seats_in_subscription: 0
                }
              })
            end

            context 'when email is associated with user already in target group' do
              let(:add_user_emails) { [user.email, 'foo@example.com', existing_user.email] }

              it 'does not count existing user' do
                expect(execute).to include({
                  success: true,
                  data: {
                    will_increase_overage: true,
                    new_billable_user_count: 3,
                    seats_in_subscription: 0
                  }
                })
              end
            end
          end

          context 'by user id' do
            let_it_be(:add_user_ids) { [non_existing_record_id] }

            subject(:execute) do
              described_class.new(
                current_user: current_user,
                target_namespace: target_namespace,
                role: role,
                add_user_ids: add_user_ids
              ).execute
            end

            it 'returns successfully' do
              expect(execute).to include({
                success: true,
                data: {
                  will_increase_overage: true,
                  new_billable_user_count: 2,
                  seats_in_subscription: 0
                }
              })
            end

            context 'when id is associated with user already in target group' do
              let(:add_user_ids) { [non_existing_record_id, existing_user.id] }

              it 'does not count existing user' do
                expect(execute).to include({
                  success: true,
                  data: {
                    will_increase_overage: true,
                    new_billable_user_count: 2,
                    seats_in_subscription: 0
                  }
                })
              end
            end
          end

          context 'with guest role' do
            let_it_be(:role) { :guest }

            let(:member_role_id) { nil }

            subject(:execute) do
              described_class.new(
                current_user: current_user,
                target_namespace: target_namespace,
                role: role,
                add_user_ids: [non_existing_record_id],
                member_role_id: member_role_id
              ).execute
            end

            shared_examples 'not counting added users' do
              it 'does not count added users' do
                expect(execute).to include({
                  success: true,
                  data: {
                    will_increase_overage: false,
                    new_billable_user_count: 1,
                    seats_in_subscription: 0
                  }
                })
              end
            end

            context 'when target group does not charge for guests' do
              before do
                allow(target_namespace).to receive(:exclude_guests?).and_return true
              end

              context 'with basic guest role' do
                it_behaves_like 'not counting added users'
              end

              context 'with guest based custom roles with read_code permission enabled' do
                let(:member_role) { create(:member_role, :guest, namespace: target_namespace, read_code: true) }
                let(:member_role_id) { member_role.id }

                it_behaves_like 'not counting added users'
              end

              context 'with guest based custom roles with other permissions enabled' do
                let(:member_role) do
                  create(:member_role, :guest, namespace: target_namespace, read_vulnerability: true)
                end

                let(:member_role_id) { member_role.id }

                it 'counts added users' do
                  expect(execute).to include({
                    success: true,
                    data: {
                      will_increase_overage: true,
                      new_billable_user_count: 2,
                      seats_in_subscription: 0
                    }
                  })
                end
              end

              context 'with non-existing member role id' do
                let(:member_role_id) { non_existing_record_id }

                it_behaves_like 'not counting added users'
              end
            end

            context 'when target group charges for guests' do
              before do
                allow(target_namespace).to receive(:exclude_guests?).and_return false
              end

              it 'counts added users' do
                expect(execute).to include({
                  success: true,
                  data: {
                    will_increase_overage: true,
                    new_billable_user_count: 2,
                    seats_in_subscription: 0
                  }
                })
              end
            end
          end
        end

        context 'when adding a service account' do
          context 'by group id' do
            subject(:execute) do
              described_class.new(
                current_user: current_user,
                target_namespace: target_namespace,
                role: role,
                add_group_id: add_group_id
              ).execute
            end

            context 'when group exists' do
              let_it_be(:service_account_member_1) { create(:service_account) }
              let_it_be(:service_account_member_2) { create(:service_account) }
              let_it_be(:group) do
                create(:group, :private, developers: [service_account_member_1, service_account_member_2])
              end

              let(:add_group_id) { group.id }

              context 'when current_user has access to view group' do
                before do
                  group.add_developer(current_user)
                end

                it 'counts group members but not service accounts' do
                  expect(execute).to include({
                    success: true,
                    data: {
                      will_increase_overage: true,
                      new_billable_user_count: 2,
                      seats_in_subscription: 0
                    }
                  })
                end
              end

              context 'when current_user does not have access to view group' do
                before do
                  group.add_developer(service_account_member_1)
                  group.add_developer(service_account_member_2)
                end

                it 'does not count group members or service accounts' do
                  expect(execute).to include({
                    success: true,
                    data: {
                      will_increase_overage: false,
                      new_billable_user_count: 1,
                      seats_in_subscription: 0
                    }
                  })
                end
              end
            end
          end

          context 'by email' do
            let_it_be(:user) { create(:user) }
            let_it_be(:service_account) { create(:service_account) }
            let(:add_user_emails) { [user.email, 'foo@example.com', service_account.email] }

            subject(:execute) do
              described_class.new(
                current_user: current_user,
                target_namespace: target_namespace,
                role: role,
                add_user_emails: add_user_emails
              ).execute
            end

            it 'counts user emails and unassociated emails but not service accounts' do
              expect(execute).to include({
                success: true,
                data: {
                  will_increase_overage: true,
                  new_billable_user_count: 3,
                  seats_in_subscription: 0
                }
              })
            end

            context 'when email is associated with user already in target group' do
              let(:add_user_emails) { [user.email, 'foo@example.com', existing_user.email, service_account.email] }

              it 'does not count either existing user or service accounts' do
                expect(execute).to include({
                  success: true,
                  data: {
                    will_increase_overage: true,
                    new_billable_user_count: 3,
                    seats_in_subscription: 0
                  }
                })
              end
            end
          end

          context 'by user id' do
            let(:add_user_ids) { [non_existing_record_id] }

            subject(:execute) do
              described_class.new(
                current_user: current_user,
                target_namespace: target_namespace,
                role: role,
                add_user_ids: add_user_ids
              ).execute
            end

            context 'when id is associated with a service account' do
              let(:service_account) { create(:service_account) }
              let(:add_user_ids) { [non_existing_record_id, service_account.id, existing_user.id] }

              it 'does not count the service account' do
                expect(execute).to include({
                  success: true,
                  data: {
                    will_increase_overage: true,
                    new_billable_user_count: 2,
                    seats_in_subscription: 0
                  }
                })
              end
            end
          end
        end

        context 'when added users results in an increased overage' do
          let_it_be(:add_user_ids) do
            10.times.map do |i| # rubocop:disable Performance/TimesMap
              non_existing_record_id - i
            end
          end

          subject(:execute) do
            described_class.new(
              current_user: current_user,
              target_namespace: target_namespace,
              role: role,
              add_user_ids: add_user_ids
            ).execute
          end

          it 'sets will_increase_overage: true' do
            expect(execute).to include({
              success: true,
              data: {
                will_increase_overage: true,
                new_billable_user_count: 11,
                seats_in_subscription: 0
              }
            })
          end

          context 'when not eligible for for seat usage alerts' do
            let(:eligible_for_usage_alerts) { false }

            it 'sets will_increase_overage: false' do
              expect(execute).to include({
                success: true,
                data: {
                  will_increase_overage: false,
                  new_billable_user_count: 11,
                  seats_in_subscription: 0
                }
              })
            end
          end
        end
      end
    end

    context 'when target namespace is a group' do
      let_it_be_with_reload(:target_namespace) { create(:group) }
      let_it_be(:existing_user) { create(:user) }

      before_all do
        target_namespace.add_developer(existing_user)
      end

      it_behaves_like 'preview billable user change service'
    end

    context 'when target namespace is a user namespace' do
      let(:target_namespace) { create(:user_namespace) }
      let(:existing_user) { target_namespace.owner }

      it_behaves_like 'preview billable user change service'
    end

    context 'with different instance types' do
      let_it_be(:target_namespace) { create(:group) }

      subject(:service) do
        described_class.new(
          current_user: current_user,
          target_namespace: target_namespace,
          role: role,
          add_user_ids: [non_existing_record_id]
        )
      end

      before do
        allow(GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService)
          .to receive(:new).and_return(
            instance_double(GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService, execute: true)
          )
      end

      context 'with SaaS instance', :saas do
        it 'calls saas_billable_role_change?' do
          expect(service).to receive(:saas_billable_role_change?).with(
            target_namespace: target_namespace,
            role: Gitlab::Access::DEVELOPER,
            member_role_id: nil
          ).at_least(:once)

          expect(service).not_to receive(:sm_billable_role_change?)

          service.execute
        end

        context 'with owner role' do
          let(:role) { :owner }

          it 'calls saas_billable_role_change?' do
            expect(service).to receive(:saas_billable_role_change?).with(
              target_namespace: target_namespace,
              role: Gitlab::Access::OWNER,
              member_role_id: nil
            ).at_least(:once)

            expect(service).not_to receive(:sm_billable_role_change?)

            service.execute
          end
        end
      end

      context 'with self-managed instance' do
        it 'calls sm_billable_role_change?' do
          expect(service).to receive(:sm_billable_role_change?).with(
            role: Gitlab::Access::DEVELOPER,
            member_role_id: nil
          ).at_least(:once)

          expect(service).not_to receive(:saas_billable_role_change?)

          service.execute
        end

        context 'with owner role' do
          let(:role) { :owner }

          it 'calls sm_billable_role_change?' do
            expect(service).to receive(:sm_billable_role_change?).with(
              role: Gitlab::Access::OWNER,
              member_role_id: nil
            ).at_least(:once)

            expect(service).not_to receive(:saas_billable_role_change?)

            service.execute
          end
        end
      end
    end
  end
end
