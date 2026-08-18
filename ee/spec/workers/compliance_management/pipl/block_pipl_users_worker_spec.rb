# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::BlockPiplUsersWorker,
  :saas,
  feature_category: :compliance_management do
  subject(:perform) { described_class.new.perform }

  it_behaves_like 'an idempotent worker'

  it 'has the `until_executing` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executing)
  end

  shared_examples 'worker runs as expected' do
    describe '.perform', :freeze_time do
      context 'when there are matching records' do
        let_it_be_with_reload(:blockable_user) { pipl_user_from(60).user }
        let_it_be_with_reload(:user) { pipl_user_from(53).user }

        it 'blocks the users for the correct day threshold' do
          perform

          expect(blockable_user.reload.blocked?).to be(true)
          expect(user.reload.blocked?).to be(false)
        end

        it 'sets the correct admin message' do
          perform

          note = "User was blocked due to the 60-day " \
            "PIPL compliance block threshold being reached"

          expect(blockable_user.reload.note).to include(note)
        end

        it_behaves_like 'an idempotent worker'

        context 'when enforce_pipl_compliance setting is disabled' do
          before do
            stub_ee_application_setting(enforce_pipl_compliance: false)
          end

          it 'does not block the blockable users' do
            perform

            expect(blockable_user.reload.blocked?).to be(false)
          end
        end

        context 'when the users are paid' do
          before do
            User.find_each do |user|
              create(:group_with_plan, plan: :ultimate_plan, guests: user)
            end
          end

          it 'does not block the blockable users' do
            perform

            expect(blockable_user.reload.blocked?).to be(false)
          end
        end
      end
    end
  end

  context 'when system admin_mode is enabled', :enable_admin_mode do
    before do
      stub_ee_application_setting(enforce_pipl_compliance: true)
    end

    it_behaves_like 'worker runs as expected'
  end

  context 'when system admin_mode is enabled', :do_not_mock_admin_mode_setting do
    before do
      stub_ee_application_setting(enforce_pipl_compliance: true)
    end

    it_behaves_like 'worker runs as expected'
  end

  def pipl_user_from(days_ago, current_time = Time.current)
    date = current_time - days_ago.days
    create(:pipl_user, initial_email_sent_at: date)
  end
end
