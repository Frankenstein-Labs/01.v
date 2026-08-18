# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::BlockNonCompliantUserService,
  :saas,
  feature_category: :compliance_management do
  subject(:execute) { described_class.new(pipl_user: pipl_user, current_user: blocking_user).execute }

  let(:pipl_user) { create(:pipl_user) }
  let(:blocking_user) { create(:user, :admin) }

  shared_examples 'does not block the user' do
    it 'does not change the user status and note' do
      # Using &. because we set user { nil }, for validation checks
      expect { execute }.to not_change { pipl_user&.user&.reload&.state }
                                  .and not_change { pipl_user&.user&.note }
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
      context 'when validations fail' do
        context 'when the feature is not available on the instance' do
          before do
            stub_saas_features(pipl_compliance: false)
          end

          it_behaves_like 'does not block the user'
          it_behaves_like 'has a validation error', "Pipl Compliance is not available on this instance"
        end

        context 'when the enforce_pipl_compliance setting is disabled' do
          before do
            stub_ee_application_setting(enforce_pipl_compliance: false)
          end

          it_behaves_like 'does not block the user'
          it_behaves_like 'has a validation error', "You don't have the required permissions to " \
            "perform this action or this feature is disabled"
        end

        context 'when the user belongs to a paid group' do
          before do
            create(:group_with_plan, plan: :ultimate_plan, guests: pipl_user.user)
          end

          it_behaves_like 'does not block the user'
          it_behaves_like 'has a validation error', "User belongs to a paid group"
        end

        context 'when the blocking user is not an admin' do
          before do
            blocking_user.update!(admin: false)
          end

          it_behaves_like 'does not block the user'
          it_behaves_like 'has a validation error', "You don't have the required permissions to " \
            "perform this action or this feature is disabled"
        end

        context 'when the pipl threshold has not passed' do
          let(:pipl_user) { create(:pipl_user, user: blocking_user) }

          it_behaves_like 'does not block the user'
          it_behaves_like 'has a validation error',
            "Pipl block threshold has not been exceeded for user:"
        end
      end

      context 'when the data is valid' do
        let(:pipl_user) { create(:pipl_user, initial_email_sent_at: 60.days.ago) }
        let(:note) do
          "User was blocked due to the 60-day " \
            "PIPL compliance block threshold being reached"
        end

        it 'blocks the user and leaves an admin message' do
          result = execute

          expect(result.error?).to be(false)
          expect(pipl_user.user.reload.blocked?).to be(true)
          expect(pipl_user.user.note).to include(note)
        end
      end

      context 'when the block operation fails' do
        let(:pipl_user) { create(:pipl_user, user: create(:user, :admin_bot), initial_email_sent_at: 60.days.ago) }

        it_behaves_like 'does not block the user'
        it_behaves_like 'has a validation error',
          "An internal user cannot be blocked"
      end
    end

    context 'when admin mode is enabled' do
      it_behaves_like 'does not block the user'
      it_behaves_like 'has a validation error', "You don't have the required permissions to " \
        "perform this action or this feature is disabled"

      context 'when the user is in the admin_mode' do
        let(:pipl_user) { create(:pipl_user, initial_email_sent_at: 60.days.ago) }
        let(:note) do
          "User was blocked due to the 60-day " \
            "PIPL compliance block threshold being reached"
        end

        it 'blocks the user and leaves an admin message', :enable_admin_mode do
          result = execute

          expect(result.error?).to be(false)
          expect(pipl_user.user.reload.blocked?).to be(true)
          expect(pipl_user.user.note).to include(note)
        end
      end
    end
  end
end
