# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::UpdateUserCountryAccessLogsService, feature_category: :compliance_management do
  let_it_be_with_reload(:user) { create(:user) }

  let(:country_code) { 'CN' }

  subject(:service) { described_class.new(user, country_code) }

  describe '#execute', :aggregate_failures, :freeze_time do
    shared_examples 'does not enqueue job to check if user is paid' do
      it 'does not enqueue job to check if user is paid' do
        expect(::ComplianceManagement::Pipl::UserPaidStatusCheckWorker).not_to receive(:perform_async)

        service.execute
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'does not create a CountryAccessLog record' do
        expect { service.execute }.not_to change { Users::CountryAccessLog.count }
      end
    end

    context 'when country_code is nil' do
      let(:country_code) { nil }

      it 'does not create a CountryAccessLog record' do
        expect { service.execute }.not_to change { Users::CountryAccessLog.count }
      end
    end

    context 'when country_code is not in %w[CN HK MO]' do
      let(:country_code) { 'US' }
      let_it_be_with_reload(:pipl_log1) { create(:country_access_log, user: user, access_count: 1) }
      let_it_be_with_reload(:pipl_log2) { create(:country_access_log, country_code: 'HK', user: user, access_count: 1) }

      it "resets the access counts of access log records from #{ComplianceManagement::Pipl::COVERED_COUNTRY_CODES}" do
        service.execute

        logs = user.country_access_logs
        log1 = logs.find(pipl_log1.id)
        log2 = logs.find(pipl_log2.id)

        expect(log1.access_count).to eq 0
        expect(log1.access_count_reset_at).to eq Time.zone.now

        expect(log2.access_count).to eq 0
        expect(log2.access_count_reset_at).to eq Time.zone.now
      end

      context 'when the user was previously tracked' do
        let!(:pipl_user) { create(:pipl_user, user: user) }

        it 'destroys the related pipl_user record' do
          expect { service.execute }.to change { ComplianceManagement::PiplUser.count }.by(-1)
          expect(user.reload.pipl_user).to be_nil
        end
      end

      it_behaves_like 'does not enqueue job to check if user is paid'
    end

    describe "when country_code is in #{ComplianceManagement::Pipl::COVERED_COUNTRY_CODES}" do
      context 'when user access was tracked within the past 24 hours' do
        let!(:pipl_user) do
          create(:pipl_user, user: user, last_access_from_pipl_country_at: 12.hours.ago)
        end

        it 'does not create a new access log' do
          expect { service.execute }.not_to change { user.country_access_logs.count }
        end

        it 'does not create a new pipl_user' do
          expect { service.execute }.not_to change { user.pipl_user.persisted? }
        end

        context 'when user has existing access logs' do
          before do
            create(:country_access_log, user: user, first_access_at: 12.hours.ago, access_count: 4)
          end

          it 'does not update existing log access records' do
            expect { service.execute }.not_to change { user.country_access_logs.first.access_count }
          end

          it "does not update the user's last_access_from_pipl_country_at" do
            expect { service.execute }.not_to change { pipl_user.reload.last_access_from_pipl_country_at }
          end

          it "does not update the user's initial_email_sent_at" do
            expect { service.execute }.not_to change { pipl_user.reload.initial_email_sent_at }
          end

          it_behaves_like 'does not enqueue job to check if user is paid'
        end
      end

      context 'when user has no existing access logs' do
        it 'creates a new record with the correct attribute values' do
          expect { service.execute }.to change { user.country_access_logs.count }.from(0).to(1)

          log = user.country_access_logs.first
          expect(log.first_access_at).to eq Time.zone.now
          expect(log.last_access_at).to eq Time.zone.now
          expect(log.access_count).to eq 1
        end

        it 'creates a new pipl_user and sets the last access timestamp' do
          expect { service.execute }.to change { user.reload.pipl_user.present? }.from(false).to(true)

          expect(user.pipl_user.last_access_from_pipl_country_at).to eq Time.zone.now
        end
      end

      context 'when user has existing logs' do
        let!(:pipl_user) { create(:pipl_user, user: user) }

        let!(:other_log) { create(:country_access_log, country_code: 'HK', user: user, access_count: 1) }
        let!(:target_log) do
          create(:country_access_log, user: user, first_access_at: 25.hours.ago, access_count: 1)
        end

        before do
          pipl_user.update!(last_access_from_pipl_country_at: 25.hours.ago)
        end

        it 'updates the existing log record correctly' do
          expect { service.execute }.not_to change { other_log }

          target_log = user.country_access_logs.find_by_country_code('CN')
          expect(target_log.first_access_at).to eq 25.hours.ago
          expect(target_log.last_access_at).to eq Time.zone.now
          expect(target_log.access_count).to eq 2
        end

        it 'updates the existing pipl_user correctly', :freeze_time do
          expect { service.execute }.not_to change { pipl_user.reload.persisted? }

          expect(pipl_user.last_access_from_pipl_country_at).to eq Time.zone.now
        end
      end

      it_behaves_like 'does not enqueue job to check if user is paid'

      describe 'background job to check if user is paid' do
        shared_examples 'job is enqueued' do
          it 'enqueues job' do
            expect(::ComplianceManagement::Pipl::UserPaidStatusCheckWorker).to receive(:perform_async).with(user.id)

            service.execute
          end
        end

        context 'when user has exclusively accessed from PIPL-covered countries' do
          context 'with duration > 6 months' do
            let!(:log) do
              create(:country_access_log, user: user, first_access_at: 7.months.ago, access_count: 1)
            end

            it_behaves_like 'job is enqueued'
          end

          context 'with duration < 6 months' do
            let!(:log) do
              create(:country_access_log, user: user, first_access_at: 5.months.ago, access_count: 1)
            end

            it_behaves_like 'does not enqueue job to check if user is paid'
          end

          context 'with a single access log record with access count >= 5' do
            let!(:log) { create(:country_access_log, user: user, access_count: 5) }

            it_behaves_like 'job is enqueued'
          end

          context 'with a single access log record with access count < 5' do
            let!(:log) { create(:country_access_log, user: user, access_count: 1) }

            it_behaves_like 'does not enqueue job to check if user is paid'
          end

          context 'with accesses from multiple PIPL-covered countries' do
            let!(:log) { create(:country_access_log, user: user, access_count: 1) }
            let!(:log2) { create(:country_access_log, country_code: 'HK', user: user, access_count: 1) }

            context 'with sum of access counts < 5' do
              it_behaves_like 'does not enqueue job to check if user is paid'
            end

            context 'with sum of access counts >= 5' do
              let!(:log3) { create(:country_access_log, country_code: 'MO', user: user, access_count: 3) }

              it_behaves_like 'job is enqueued'
            end
          end
        end
      end
    end
  end
end
