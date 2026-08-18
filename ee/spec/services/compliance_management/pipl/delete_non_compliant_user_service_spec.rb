# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::DeleteNonCompliantUserService,
  :saas,
  feature_category: :compliance_management do
  subject(:execute) { described_class.new(pipl_user: pipl_user, current_user: deleting_user).execute }

  let_it_be_with_reload(:pipl_user) { create(:pipl_user, :deletable) }
  let_it_be_with_reload(:user) { pipl_user.user }
  let(:deleting_user) { create(:user, :admin) }

  shared_examples 'does not delete the user' do
    it 'does not schedule a deletion migration' do
      expect { execute }.not_to change { user.reload.ghost_user_migration.present? }
    end
  end

  shared_examples 'has a validation error' do |message|
    it 'returns an error with a descriptive message' do
      result = execute

      expect(result.error?).to be(true)
      expect(result.message).to include(message)
    end
  end

  describe '#execute' do
    before do
      stub_ee_application_setting(enforce_pipl_compliance: true)
    end

    context 'when admin_mode is disabled', :do_not_mock_admin_mode_setting do
      context 'when checks fail' do
        context 'when the feature is not available on the instance' do
          before do
            stub_saas_features(pipl_compliance: false)
          end

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error', "Pipl Compliance is not available on this instance"
        end

        context 'when the enforce_pipl_compliance setting is disabled' do
          before do
            stub_ee_application_setting(enforce_pipl_compliance: false)
          end

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error', "You don't have the required permissions to " \
            "perform this action or this feature is disabled"
        end

        context 'when the pipl_user is not blocked' do
          before do
            pipl_user.user.update!(state: :active)
          end

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error', "User is not blocked"
        end

        context 'when the pipl_user is recently blocked' do
          before do
            pipl_user.user.update!(last_activity_on: Time.current - 1.day)
            pipl_user.user.update!(state: :blocked)
          end

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error', "User has activity which is more recent than 60 days"
        end

        context 'when the deleting user is not an admin' do
          before do
            deleting_user.update!(admin: false)
          end

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error',
            "You don't have the required permissions to perform this " \
              "action or this feature is disabled"
        end

        context 'when the pipl deletion threshold has not passed' do
          let(:pipl_user) { create(:pipl_user, user: deleting_user) }

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error',
            "Pipl deletion threshold has not been exceeded for user:"
        end
      end

      context 'when the data is valid' do
        let(:pipl_user) { create(:pipl_user, :deletable) }

        it 'schedules user deletion', :sidekiq_inline do
          result = execute

          expect(result.error?).to be(false)
          expect(pipl_user.user.reload.ghost_user_migration.present?).to be(true)
          expect(pipl_user.user.reload.ghost_user_migration.hard_delete?).to be(false)
        end
      end
    end

    context 'when admin mode is enabled' do
      it_behaves_like 'does not delete the user'
      it_behaves_like 'has a validation error', "You don't have the required permissions to " \
        "perform this action or this feature is disabled"

      context 'when the user is in the admin_mode' do
        let(:pipl_user) { create(:pipl_user, :deletable) }

        it 'schedules user deletion', :sidekiq_inline, :enable_admin_mode do
          result = execute

          expect(result.error?).to be(false)
          expect(pipl_user.user.reload.ghost_user_migration.present?).to be(true)
        end
      end
    end
  end
end
