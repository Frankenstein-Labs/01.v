# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IdentityVerification::UserRiskProfile, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user) }
  let(:risk_profile) { described_class.new(user) }

  shared_examples 'clears user_custom_attributes memoization' do
    specify do
      expect(risk_profile).to receive(:clear_memoization).with(:user_custom_attributes).and_call_original

      subject
    end
  end

  describe '#assume_low_risk!' do
    subject(:call_method) { risk_profile.assume_low_risk!(reason: 'Because') }

    it 'creates a custom attribute with correct attribute values for the user', :aggregate_failures do
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: 'IdentityVerification::UserRiskProfile',
        event: 'User assumed low risk.',
        reason: 'Because',
        user_id: user.id,
        username: user.username
      )
      expect { call_method }.to change { user.custom_attributes.count }.by(1)

      record = user.custom_attributes.last
      expect(record.key).to eq described_class::ASSUMED_LOW_RISK_ATTR_KEY
      expect(record.value).to eq 'Because'
    end

    it_behaves_like 'clears user_custom_attributes memoization'
  end

  describe '#assume_high_risk!' do
    subject(:call_method) { risk_profile.assume_high_risk!(reason: 'Because') }

    it 'creates a custom attribute with correct attribute values for the user', :aggregate_failures do
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: 'IdentityVerification::UserRiskProfile',
        event: 'User assumed high risk.',
        reason: 'Because',
        user_id: user.id,
        username: user.username
      )
      expect { call_method }.to change { user.custom_attributes.count }.by(1)

      record = user.custom_attributes.last
      expect(record.key).to eq described_class::ASSUMED_HIGH_RISK_ATTR_KEY
      expect(record.value).to eq 'Because'
    end

    it_behaves_like 'clears user_custom_attributes memoization'
  end

  describe '#assumed_high_risk?' do
    subject(:result) { risk_profile.assumed_high_risk? }

    it { is_expected.to be false }

    context 'when user has a "assumed_high_risk_reason" custom attribute' do
      before do
        create(:user_custom_attribute, :assumed_high_risk_reason, user: user)
      end

      it { is_expected.to be true }
    end
  end

  def add_user_risk_band(value)
    create(:user_custom_attribute, key: UserCustomAttribute::ARKOSE_RISK_BAND, value: value, user_id: user.id)
  end

  describe('#medium_risk?') do
    subject { risk_profile.medium_risk? }

    where(:arkose_risk_band, :result) do
      nil           | false
      'High'        | false
      'Medium'      | true
      'Low'         | false
      'Unavailable' | false
    end

    with_them do
      before do
        add_user_risk_band(arkose_risk_band) if arkose_risk_band.present?
      end

      it { is_expected.to eq result }
    end
  end

  describe('#high_risk?') do
    subject { risk_profile.high_risk? }

    where(:arkose_risk_band, :result) do
      nil           | false
      'High'        | true
      'Medium'      | false
      'Low'         | false
      'Unavailable' | false
    end

    with_them do
      before do
        add_user_risk_band(arkose_risk_band) if arkose_risk_band.present?
      end

      it { is_expected.to eq result }
    end
  end

  describe('#arkose_verified?') do
    subject { risk_profile.arkose_verified? }

    where(:arkose_risk_band, :assumed_low_risk, :result) do
      nil           | false | false
      nil           | true  | true
      'High'        | false | true
      'Medium'      | false | true
      'Low'         | false | true
      'Unavailable' | false | true
    end

    with_them do
      before do
        add_user_risk_band(arkose_risk_band) if arkose_risk_band.present?
        user.assume_low_risk!(reason: 'Because') if assumed_low_risk
      end

      it { is_expected.to eq result }
    end
  end

  describe '#remove_identity_verification_exemption' do
    subject(:call_method) { risk_profile.remove_identity_verification_exemption }

    context 'when user has an identity verification exemption custom attribute' do
      before do
        user.add_identity_verification_exemption('testing')
      end

      it 'destroys the custom attribute' do
        key = UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT
        expect { call_method }.to change {
                                    user.custom_attributes.find_by_key(key)
                                  }.to(nil)
      end

      it_behaves_like 'clears user_custom_attributes memoization'
    end

    context 'when user does not have an identity verification exemption custom attribute' do
      it { is_expected.to be_nil }
    end
  end

  describe '#identity_verification_exempt?' do
    subject(:call_method) { risk_profile.identity_verification_exempt? }

    context 'when user has an identity verification exemption custom attribute' do
      it 'returns true' do
        user.add_identity_verification_exemption('testing')

        expect(call_method).to be true
      end
    end

    context 'when user does not have an identity verification exemption custom attribute' do
      it { is_expected.to be false }
    end
  end

  describe '#add_identity_verification_exemption' do
    subject(:call_method) { risk_profile.add_identity_verification_exemption('because') }

    it 'creates the exemption custom attribute', :aggregate_failures do
      key = UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT
      expect { call_method }.to change { user.custom_attributes.by_key(key).count }.from(0).to(1)

      expect(user.custom_attributes.by_key(key).first.value).to eq('because')
    end

    it_behaves_like 'clears user_custom_attributes memoization'
  end

  describe '#phone_number_verification_exempt?' do
    subject(:call_method) { risk_profile.phone_number_verification_exempt? }

    context 'when user has a phone number verification exemption custom attribute' do
      it 'returns true' do
        risk_profile.add_phone_number_verification_exemption

        expect(call_method).to be true
      end
    end

    context 'when user does not have a phone number verification exemption custom attribute' do
      it { is_expected.to be false }
    end
  end

  describe '#add_phone_number_verification_exemption' do
    subject(:call_method) { risk_profile.add_phone_number_verification_exemption }

    it 'creates the exemption custom attribute' do
      key = UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT
      expect { call_method }.to change { user.custom_attributes.by_key(key).count }.from(0).to(1)
    end

    it_behaves_like 'clears user_custom_attributes memoization'
  end

  describe '#remove_phone_number_verification_exemption' do
    subject(:call_method) { risk_profile.remove_phone_number_verification_exemption }

    context 'when user has a phone number verification exemption custom attribute' do
      before do
        risk_profile.add_phone_number_verification_exemption
      end

      it 'destroys the custom attribute' do
        key = UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT
        expect { call_method }.to change {
                                    user.custom_attributes.find_by_key(key)
                                  }.to(nil)
      end

      it_behaves_like 'clears user_custom_attributes memoization'
    end

    context 'when user does not have a phone number verification exemption custom attribute' do
      it { is_expected.to be_nil }
    end
  end

  describe '#assume_high_risk_if_phone_verification_limit_exceeded!' do
    subject(:check_risk_profile) { risk_profile.assume_high_risk_if_phone_verification_limit_exceeded! }

    # Use shared context for rate limiter setup
    shared_context 'with phone verification limit' do |is_exceeded|
      before do
        allow(Gitlab::ApplicationRateLimiter)
          .to receive(:peek)
          .with(:soft_phone_verification_transactions_limit, scope: :global)
          .and_return(is_exceeded)
      end
    end

    context 'when verification limit is exceeded' do
      include_context 'with phone verification limit', true

      it 'marks user as high risk' do
        expect(user).to receive(:assume_high_risk!)
          .with(reason: 'Phone verification daily transaction limit exceeded')

        check_risk_profile
      end
    end

    context 'when verification limit is not exceeded' do
      include_context 'with phone verification limit', false

      it 'does not mark user as high risk' do
        expect(user).not_to receive(:assume_high_risk!)

        check_risk_profile
      end
    end
  end
end
