# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::Gitlab::PersonalAccessTokens::ExpiryDateCalculator, feature_category: :system_access do
  let_it_be(:instance_level_pat_expiration_policy) { 30 }
  let_it_be(:instance_level_pat_expiration_date) { Date.current + instance_level_pat_expiration_policy }

  let_it_be(:group_level_pat_expiration_policy) { 20 }
  let_it_be(:group_level_max_expiration_date) { Date.current + group_level_pat_expiration_policy }

  let(:group) do
    build(:group_with_managed_accounts, max_personal_access_token_lifetime: group_level_pat_expiration_policy)
  end

  let(:user) { create(:user) }
  let(:expiry_date_calculator) { described_class.new(user) }

  before do
    stub_licensed_features(personal_access_token_expiration_policy: true)
    stub_ee_application_setting(max_personal_access_token_lifetime: instance_level_pat_expiration_policy)
  end

  describe "#max_expiry_date", :freeze_time do
    context 'when user is not group managed' do
      it 'returns instance level value for max_personal_access_token_lifetime' do
        expect(expiry_date_calculator.max_expiry_date).to eq(instance_level_pat_expiration_date)
      end
    end

    context 'when user is group_managed' do
      let(:user) { build(:user, managing_group: group) }

      it 'returns group value for max_personal_access_token_lifetime' do
        expect(expiry_date_calculator.max_expiry_date).to eq(group_level_max_expiration_date)
      end
    end
  end

  describe "#instance_level_expiry_date", :freeze_time do
    it "returns the instance level max expiry date" do
      expect(expiry_date_calculator.instance_level_max_expiry_date).to eq(instance_level_pat_expiration_date)
    end
  end

  describe "#group_level_max_expiry_date", :freeze_time do
    context 'when user is not group managed' do
      it "returns nil max expiry date" do
        expect(expiry_date_calculator.group_level_max_expiry_date).to be_nil
      end
    end

    context 'when user is group managed' do
      let(:user) { build(:user, managing_group: group) }

      it "returns group level max expiry date" do
        expect(expiry_date_calculator.group_level_max_expiry_date).to eq(group_level_max_expiration_date)
      end
    end
  end
end
