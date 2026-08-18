# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::BuildBotService, feature_category: :security_policy_management do
  describe '#execute' do
    subject(:execute_service) { described_class.new(current_user, params).execute }

    let(:current_user) { create(:user) }
    let(:params) { { private_profile: true } }

    it 'allows the private_profile param', :aggregate_failures do
      expect(execute_service.private_profile).to eq(true)
    end
  end
end
