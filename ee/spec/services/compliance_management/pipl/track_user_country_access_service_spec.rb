# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::TrackUserCountryAccessService, feature_category: :compliance_management do
  let_it_be_with_reload(:user) { create(:user) }

  let(:country_code) { 'CN' }

  subject(:service) { described_class.new(user, country_code) }

  describe '#execute', :aggregate_failures do
    before do
      stub_saas_features(pipl_compliance: true)
    end

    shared_examples 'does not enqueue an UpdateUserCountryAccessLogsWorker job' do
      it 'does not enqueue an UpdateUserCountryAccessLogsWorker job' do
        expect(ComplianceManagement::Pipl::UpdateUserCountryAccessLogsWorker).not_to receive(:perform_async)

        service.execute
      end
    end

    shared_examples 'enqueues an UpdateUserCountryAccessLogsWorker job' do
      it 'enqueues an UpdateUserCountryAccessLogsWorker job' do
        expect(ComplianceManagement::Pipl::UpdateUserCountryAccessLogsWorker)
          .to receive(:perform_async).with(user.id, country_code)

        service.execute
      end
    end

    shared_examples 'does not execute any queries' do
      it 'does not execute any queries', :sidekiq_inline do
        service = described_class.new(user, country_code)

        perform_enqueued_jobs do
          expect { service.execute }.to match_query_count(0)
        end
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it_behaves_like 'does not enqueue an UpdateUserCountryAccessLogsWorker job'
      it_behaves_like 'does not execute any queries'
    end

    context 'when country_code is nil' do
      let(:country_code) { nil }

      it_behaves_like 'does not enqueue an UpdateUserCountryAccessLogsWorker job'
      it_behaves_like 'does not execute any queries'
    end

    context 'when pipl_compliance feature is not available' do
      before do
        stub_saas_features(pipl_compliance: false)
      end

      it_behaves_like 'does not enqueue an UpdateUserCountryAccessLogsWorker job'
      it_behaves_like 'does not execute any queries'
    end

    context "when country_code is not in %w[CN HK MO]" do
      let(:country_code) { 'US' }

      context 'when the user has not been using gitlab from a PIPL country' do
        it_behaves_like 'does not enqueue an UpdateUserCountryAccessLogsWorker job'
      end

      context 'when the user has been using gitlab from a PIPL country' do
        let!(:pipl_user) { create(:pipl_user, user: user) }

        before do
          user.pipl_user.update!(last_access_from_pipl_country_at: 2.hours.ago)
        end

        it_behaves_like 'enqueues an UpdateUserCountryAccessLogsWorker job'
      end
    end

    describe "when country_code is in %w[CN HK MO]" do
      context "when user accessed within the past 24 hours" do
        before do
          create(:pipl_user, user: user, last_access_from_pipl_country_at: 12.hours.ago)
        end

        it_behaves_like 'does not enqueue an UpdateUserCountryAccessLogsWorker job'
      end

      context 'when user accessed more than 24 hours in the past' do
        before do
          create(:pipl_user, user: user, last_access_from_pipl_country_at: 25.hours.ago)
        end

        it_behaves_like 'enqueues an UpdateUserCountryAccessLogsWorker job'
      end
    end
  end
end
