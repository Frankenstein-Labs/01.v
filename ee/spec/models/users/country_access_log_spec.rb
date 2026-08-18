# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::CountryAccessLog, :saas, feature_category: :instance_resiliency do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:country_access_log) }

    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:country_code) }
    it { is_expected.to define_enum_for(:country_code).with_values(**described_class::COUNTRY_CODES) }
    it { is_expected.to validate_presence_of(:access_count) }
    it { is_expected.to validate_numericality_of(:access_count).is_greater_than_or_equal_to(0) }

    context 'when access count > 0' do
      subject { build(:country_access_log, access_count: 1) }

      it { is_expected.to validate_presence_of(:first_access_at) }
      it { is_expected.to validate_presence_of(:last_access_at) }
    end
  end

  context 'with loose foreign key on country_access_logs.user_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:user) }
      let_it_be(:model) { create(:country_access_log, user: parent) }
    end
  end

  describe 'scopes' do
    let_it_be(:user) { create(:user) }
    let_it_be(:from_cn) { create(:country_access_log, user: user, access_count: 0) }
    let_it_be(:from_hk) do
      create(:country_access_log, country_code: 'HK', user: user, first_access_at: 7.months.ago, access_count: 1)
    end

    describe '.from_country_code' do
      it 'returns records with country_code in given country codes' do
        expect(described_class.from_country_code(%w[CN])).to match_array [from_cn]
      end
    end

    describe '.with_access' do
      it 'returns records with access_count > 0' do
        expect(described_class.with_access).to match_array [from_hk]
      end
    end

    describe '.first_access_before' do
      it 'returns records with first_access < the given timestamp' do
        expect(described_class.first_access_before(6.months.ago)).to match_array [from_hk]
      end
    end
  end
end
