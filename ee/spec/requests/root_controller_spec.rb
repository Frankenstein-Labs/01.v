# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RootController, feature_category: :shared do
  describe 'PIPL-subject user identification', :freeze_time, :sidekiq_inline do
    using RSpec::Parameterized::TableSyntax

    let_it_be_with_reload(:user) { create(:user) }

    subject(:request) { get root_path, env: { HTTP_CF_IPCOUNTRY: country_code } }

    before do
      sign_in(user)

      stub_saas_features(pipl_compliance: true)
    end

    context 'with access from PIPL-covered country' do
      where(:country_code) do
        ComplianceManagement::Pipl::COVERED_COUNTRY_CODES
      end

      with_them do
        it 'is tracked' do
          perform_enqueued_jobs { request }

          user.reload
          log = user.country_access_logs.first

          expect(user.pipl_user.last_access_from_pipl_country_at).to eq Time.zone.now
          expect(log.country_code).to eq country_code
          expect(log.access_count).to eq 1
          expect(log.first_access_at).to eq Time.zone.now
          expect(log.last_access_at).to eq Time.zone.now
        end
      end

      context 'when followed by access from another PIPL-covered country within 24 hours', freeze_time: false do
        let(:country_code) { 'CN' }

        it 'is not tracked' do
          perform_enqueued_jobs { request }

          log = user.reload.country_access_logs.first
          old_timestamp = user.pipl_user.last_access_from_pipl_country_at

          expect(old_timestamp.present?).to be(true)
          expect(log.access_count).to eq 1

          perform_enqueued_jobs { get root_path, env: { HTTP_CF_IPCOUNTRY: 'HK' } }

          expect(log.reload.access_count).to eq 1
          expect(user.reload.pipl_user.last_access_from_pipl_country_at).to eq(old_timestamp)
        end
      end

      context 'when followed by access from non PIPL-covered country' do
        let(:country_code) { 'CN' }

        it 'is tracked' do
          perform_enqueued_jobs { request }

          user.reload
          log = user.country_access_logs.first

          expect(user.pipl_user.last_access_from_pipl_country_at).to eq Time.zone.now
          expect(log.access_count).to eq 1
          expect(log.access_count_reset_at).to be_nil

          perform_enqueued_jobs { get root_path, env: { HTTP_CF_IPCOUNTRY: 'US' } }

          user.reload
          log.reload

          expect(user.pipl_user).to be_nil
          expect(log.access_count).to eq 0
          expect(log.access_count_reset_at).to eq Time.zone.now
        end
      end

      context 'when user can be subject to PIPL', :use_clean_rails_redis_caching do
        let(:country_code) { 'CN' }
        let!(:log) { create(:country_access_log, user: user, access_count: 4) }

        it "checks if user is paid and caches 'pipl_subject_user/<user.id>'" do
          perform_enqueued_jobs { request }

          expect(Rails.cache.read([ComplianceManagement::Pipl::PIPL_SUBJECT_USER_CACHE_KEY, user.id])).to be true
        end
      end
    end

    context 'with access from non PIPL-covered country' do
      let(:country_code) { 'US' }

      it 'is not tracked' do
        perform_enqueued_jobs { request }

        user.reload
        expect(user.pipl_user).to be_nil
        expect(user.country_access_logs).to be_empty
      end
    end
  end
end
