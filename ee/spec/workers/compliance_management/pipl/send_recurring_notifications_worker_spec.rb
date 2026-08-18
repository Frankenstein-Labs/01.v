# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::SendRecurringNotificationsWorker, :saas,
  feature_category: :compliance_management do
  subject(:perform) { described_class.new.perform }

  it_behaves_like 'an idempotent worker'

  it 'has the `until_executing` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executing)
  end

  describe '.perform', :freeze_time do
    let_it_be(:current_time) { Time.current }

    before do
      stub_ee_application_setting(enforce_pipl_compliance: true)
    end

    context 'when there are matching records' do
      before_all do
        pipl_user_from(30, current_time)
        pipl_user_from(53, current_time)
        pipl_user_from(59, current_time)
      end

      it 'sends the recurring email for the correct dates' do
        expect do
          perform_enqueued_jobs do
            perform
          end
        end.to change { ActionMailer::Base.deliveries.count }.by(3)
      end

      it_behaves_like 'an idempotent worker'

      context 'when enforce_pipl_compliance setting is disabled' do
        before do
          stub_ee_application_setting(enforce_pipl_compliance: false)
        end

        it 'does not send any emails' do
          expect do
            perform_enqueued_jobs do
              perform
            end
          end.not_to change { ActionMailer::Base.deliveries.count }
        end
      end
    end

    context 'when there are no matching records' do
      before do
        pipl_user_from(0, current_time)
        pipl_user_from(60, current_time)
      end

      it 'does not send any emails' do
        expect do
          perform_enqueued_jobs do
            perform
          end
        end.not_to change { ActionMailer::Base.deliveries.count }
      end
    end
  end

  def pipl_user_from(days_ago, current_time)
    date = current_time - days_ago.days
    create(:pipl_user, initial_email_sent_at: date)
  end
end
