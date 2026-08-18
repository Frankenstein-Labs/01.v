# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::BillableUsersUtils, feature_category: :consumables_cost_management do
  let(:dummy_class) { Class.new { include GitlabSubscriptions::BillableUsersUtils }.new }

  describe '#sm_billable_role_change?' do
    subject(:sm_billable_role_change?) do
      dummy_class.sm_billable_role_change?(role: role, member_role_id: member_role_id)
    end

    let(:member_role_id) { nil }

    context 'when called from SaaS', :saas do
      let(:role) { Gitlab::Access::DEVELOPER }

      it 'raises InvalidSubscriptionTypeError' do
        expect { sm_billable_role_change? }.to raise_error(
          ::GitlabSubscriptions::BillableUsersUtils::InvalidSubscriptionTypeError
        )
      end
    end

    context 'when called from self-managed' do
      let(:license) { create(:license, plan: plan) }
      let(:plan) { License::PREMIUM_PLAN }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      context 'when role is billable' do
        where(:access_level) do
          [
            Gitlab::Access::REPORTER,
            Gitlab::Access::PLANNER,
            Gitlab::Access::DEVELOPER,
            Gitlab::Access::MAINTAINER,
            Gitlab::Access::OWNER
          ]
        end

        with_them do
          let(:role) { access_level }

          it 'returns true' do
            expect(sm_billable_role_change?).to be(true)
          end
        end
      end

      context 'when role is GUEST' do
        let(:role) { Gitlab::Access::GUEST }

        context 'when subscription does not exclude guests' do
          let(:plan) { License::PREMIUM_PLAN }

          it 'returns true' do
            expect(sm_billable_role_change?).to be(true)
          end
        end

        context 'when subscription excludes guests' do
          let(:plan) { License::ULTIMATE_PLAN }

          context 'without member_role_id' do
            it 'returns false' do
              expect(sm_billable_role_change?).to be(false)
            end
          end

          context 'with member_role_id' do
            let(:member_role_id) { member_role.id }

            context 'when member_role is non-billable' do
              let(:member_role) { create(:member_role, :non_billable, :instance) }

              it 'returns false' do
                expect(sm_billable_role_change?).to be(false)
              end
            end

            context 'when member_role is billable' do
              let(:member_role) { create(:member_role, :billable, :instance) }

              it 'returns true' do
                expect(sm_billable_role_change?).to be(true)
              end
            end

            context 'when member_role does not exist' do
              let(:member_role_id) { non_existing_record_id }

              it 'raises InvalidMemberRoleError' do
                expect { sm_billable_role_change? }.to raise_error(
                  ::GitlabSubscriptions::BillableUsersUtils::InvalidMemberRoleError
                )
              end
            end
          end
        end
      end

      context 'when role is MINIMAL_ACCESS' do
        let(:role) { Gitlab::Access::MINIMAL_ACCESS }

        context 'when subscription does not exclude guests' do
          let(:plan) { License::PREMIUM_PLAN }

          it 'returns false' do
            expect(sm_billable_role_change?).to be(false)
          end
        end

        context 'when subscription excludes guests' do
          let(:plan) { License::ULTIMATE_PLAN }

          it 'returns false' do
            expect(sm_billable_role_change?).to be(false)
          end

          context 'with member_role_id' do
            let(:member_role_id) { member_role.id }
            let(:namespace) { create(:group) }

            context 'when member_role is non-billable' do
              let(:member_role) { create(:member_role, :minimal_access, :non_billable, namespace: namespace) }

              it 'returns false' do
                expect(sm_billable_role_change?).to be(false)
              end
            end

            context 'when member_role is billable' do
              let(:member_role) { create(:member_role, :minimal_access, :billable, namespace: namespace) }

              it 'returns false' do
                expect(sm_billable_role_change?).to be(false)
              end
            end
          end
        end
      end

      context 'when no license exists' do
        let(:license) { nil }
        let(:role) { Gitlab::Access::GUEST }

        it 'defaults to billable' do
          expect(sm_billable_role_change?).to be(true)
        end
      end
    end
  end

  describe '#saas_billable_role_change?' do
    subject(:saas_billable_role_change?) do
      dummy_class.saas_billable_role_change?(target_namespace: namespace, role: role, member_role_id: member_role_id)
    end

    let(:namespace) { create(:group) }
    let(:member_role_id) { nil }
    let(:plan) { :premium }

    context 'when called from self-managed' do
      let(:role) { Gitlab::Access::DEVELOPER }

      it 'raises InvalidSubscriptionTypeError' do
        expect { saas_billable_role_change? }.to raise_error(
          ::GitlabSubscriptions::BillableUsersUtils::InvalidSubscriptionTypeError
        )
      end
    end

    context 'when called from SaaS', :saas do
      before do
        create(:gitlab_subscription, plan, namespace: namespace)
      end

      context 'when role is billable' do
        where(:access_level) do
          [
            Gitlab::Access::REPORTER,
            Gitlab::Access::PLANNER,
            Gitlab::Access::DEVELOPER,
            Gitlab::Access::MAINTAINER,
            Gitlab::Access::OWNER
          ]
        end

        with_them do
          let(:role) { access_level }

          it 'returns true' do
            expect(saas_billable_role_change?).to be(true)
          end
        end
      end

      context 'when role is MINIMAL_ACCESS' do
        let(:role) { Gitlab::Access::MINIMAL_ACCESS }

        it 'returns false' do
          expect(saas_billable_role_change?).to be(false)
        end

        context 'with member_role_id' do
          let(:member_role_id) { member_role.id }

          context 'when member_role is billable' do
            let(:member_role) { create(:member_role, :minimal_access, :billable, namespace: namespace) }

            it 'still returns false (MINIMAL_ACCESS is always non-billable)' do
              expect(saas_billable_role_change?).to be(false)
            end
          end
        end
      end

      context 'when role is GUEST' do
        let(:role) { Gitlab::Access::GUEST }

        context 'when namespace does not exclude guests' do
          let(:plan) { :premium }

          it 'returns true' do
            expect(saas_billable_role_change?).to be(true)
          end
        end

        context 'when namespace excludes guests' do
          let(:plan) { :ultimate }

          context 'without member_role_id' do
            it 'returns false' do
              expect(saas_billable_role_change?).to be(false)
            end
          end

          context 'with member_role_id' do
            let(:member_role_id) { member_role.id }

            context 'when member_role is non-billable' do
              let(:member_role) { create(:member_role, :guest, :non_billable, namespace: namespace) }

              it 'returns false' do
                expect(saas_billable_role_change?).to be(false)
              end
            end

            context 'when member_role is billable' do
              let(:member_role) { create(:member_role, :guest, :billable, namespace: namespace) }

              it 'returns true' do
                expect(saas_billable_role_change?).to be(true)
              end
            end

            context 'when member_role does not exist' do
              let(:member_role_id) { non_existing_record_id }

              it 'raises InvalidMemberRoleError' do
                expect { saas_billable_role_change? }.to raise_error(
                  ::GitlabSubscriptions::BillableUsersUtils::InvalidMemberRoleError
                )
              end
            end
          end
        end
      end
    end
  end
end
