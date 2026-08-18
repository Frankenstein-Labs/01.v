# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::CreateBotService, feature_category: :security_policy_management do
  describe '#execute' do
    let(:current_user) { create(:user) }
    let(:params) { { private_profile: true } }

    subject(:execute_service) { described_class.new(current_user, params).execute }

    it 'calls BuildBotService' do
      expect(Users::BuildBotService).to receive(:new).with(current_user, params).and_call_original

      execute_service
    end
  end
end
