# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::UpdateUserCountryAccessLogsWorker, feature_category: :compliance_management do
  let_it_be_with_reload(:user) { create(:user) }

  let(:user_id) { user.id }
  let(:country_code) { 'CN' }

  it_behaves_like 'an idempotent worker' do
    subject(:perform) { described_class.new.perform(user_id, country_code) }

    shared_examples 'does not execute an instance of UpdateUserCountryAccessLogsService' do
      it 'does not execute an instance of UpdateUserCountryAccessLogsService' do
        expect(ComplianceManagement::Pipl::UpdateUserCountryAccessLogsService).not_to receive(:new)

        perform
      end
    end

    context 'when user cannot be found' do
      let(:user_id) { non_existing_record_id }

      it_behaves_like 'does not execute an instance of UpdateUserCountryAccessLogsService'
    end

    context 'when country code is not present' do
      let(:country_code) { nil }

      it 'does not try to find a user' do
        expect(User).not_to receive(:find_by_id)

        perform
      end

      it_behaves_like 'does not execute an instance of UpdateUserCountryAccessLogsService'
    end

    it 'executes an instance of UpdateUserCountryAccessLogsService' do
      expect_next_instance_of(ComplianceManagement::Pipl::UpdateUserCountryAccessLogsService, user,
        country_code) do |service|
        expect(service).to receive(:execute)
      end

      perform
    end
  end
end
