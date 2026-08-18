# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::CompromisedPasswordDetection, :saas, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:compromised_password_detection) }

    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:resolved_at) }
  end

  describe 'scopes' do
    let_it_be(:user) { create(:user) }
    let_it_be(:unresolved) { create(:compromised_password_detection, user: user) }
    let_it_be(:resolved) { create(:compromised_password_detection, :resolved, user: user) }

    describe '.unresolved' do
      it 'returns records with resolved_at is null' do
        expect(described_class.unresolved).to match_array [unresolved]
      end
    end
  end
end
