# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::DeletePiplUsersWorker,
  :saas,
  feature_category: :compliance_management do
  subject(:perform) { described_class.new.perform }

  before do
    stub_ee_application_setting(enforce_pipl_compliance: true)
  end

  it_behaves_like 'an idempotent worker'

  it 'has the `until_executing` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executing)
  end

  shared_examples 'worker runs as expected' do
    describe '.perform', :freeze_time do
      context 'when there are matching records' do
        let_it_be_with_reload(:deletable_user) { create(:pipl_user, :deletable).user }
        let_it_be_with_reload(:user) { pipl_user_from(53).user }

        it 'schedules a ghost user migration for the deletable user', :sidekiq_inline do
          expect { perform }
            .to change { deletable_user.reload.ghost_user_migration.present? }.from(false).to(true)

          expect(user.reload.ghost_user_migration.present?).to be(false)
        end

        it_behaves_like 'an idempotent worker'

        context 'when enforce_pipl_compliance setting is disabled' do
          before do
            stub_ee_application_setting(enforce_pipl_compliance: false)
          end

          it 'does not schedule user deletion' do
            expect { perform }
              .not_to change { deletable_user.ghost_user_migration.present? }
          end
        end
      end
    end
  end

  context 'when system admin_mode is enabled', :enable_admin_mode do
    it_behaves_like 'worker runs as expected'
  end

  context 'when system admin_mode is enabled', :do_not_mock_admin_mode_setting do
    it_behaves_like 'worker runs as expected'
  end

  def pipl_user_from(days_ago, current_time = Time.current)
    date = current_time - days_ago.days
    create(:pipl_user, initial_email_sent_at: date)
  end
end
