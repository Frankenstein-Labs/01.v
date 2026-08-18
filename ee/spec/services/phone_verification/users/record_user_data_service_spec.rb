# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PhoneVerification::Users::RecordUserDataService, feature_category: :system_access do
  let_it_be(:low_risk_score) { 50 }
  let_it_be(:high_risk_score) { 750 }

  let_it_be(:user) { create(:user) }
  let(:risk_score) { low_risk_score }

  let(:risk_result) { { risk_score: risk_score } }
  let(:phone_verification_record) { build(:phone_number_validation, user: user) }

  let(:service) do
    described_class.new(
      user: user,
      phone_verification_record: phone_verification_record,
      risk_result: risk_result
    )
  end

  describe '#execute' do
    it 'returns a success response' do
      expect(service.execute).to be_success
    end

    it 'adds the risk score to the phone validation record' do
      expect { service.execute }.to change { phone_verification_record.risk_score }.from(0).to(low_risk_score)
    end

    it 'does not persist the phone validation record' do
      service.execute

      expect(phone_verification_record).not_to be_persisted
    end

    context 'when the risk score is 0' do
      let(:risk_score) { 0 }

      it 'changes the phone validation record risk score to 1' do
        expect { service.execute }.to change { phone_verification_record.risk_score }.from(0).to(1)
      end
    end

    context 'when the user is high risk' do
      let(:risk_score) { high_risk_score }

      it 'returns an error', :aggregate_failures do
        response = service.execute

        expect(response).to be_a(ServiceResponse)
        expect(response).to be_error
        expect(response.message).to eq('Phone verification high-risk user')
        expect(response.reason).to eq(:related_to_high_risk_user)
      end

      it 'adds an assumed high risk reason to user custom attributes' do
        service.execute

        expect(
          user.custom_attributes.find_by(key: IdentityVerification::UserRiskProfile::ASSUMED_HIGH_RISK_ATTR_KEY).value
        ).to eq('Telesign intelligence identified user as high risk')
      end

      it 'persistes the phone verification record' do
        service.execute

        expect(phone_verification_record).to be_persisted
      end
    end

    context 'when the user already assumed to be high risk' do
      let(:risk_score) { high_risk_score }

      before do
        user.assume_high_risk!(reason: 'risky user')
      end

      it 'returns a success response' do
        expect(service.execute).to be_success
      end

      it 'does not change the assumed high risk reason' do
        service.execute

        expect(
          user.custom_attributes.find_by(key: IdentityVerification::UserRiskProfile::ASSUMED_HIGH_RISK_ATTR_KEY).value
        ).to eq('risky user')
      end

      it 'does not persist the phone verification record' do
        service.execute

        expect(phone_verification_record).not_to be_persisted
      end
    end
  end
end
