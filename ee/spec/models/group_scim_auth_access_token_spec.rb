# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupScimAuthAccessToken, type: :model, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end

  describe '.token_matches_for_group?' do
    context 'when token passed in found in database' do
      context 'when token associated with group passed in' do
        it 'returns true' do
          group = create(:group)
          token = create(:group_scim_auth_access_token, group: group)
          token_value = token.token

          expect(
            described_class.token_matches_for_group?(token_value, group)
          ).to be true
        end
      end

      context 'when token not associated with group passed in' do
        it 'returns false' do
          other_group = create(:group)
          token = create(:group_scim_auth_access_token, group: create(:group))
          token_value = token.token

          expect(
            described_class.token_matches_for_group?(token_value, other_group)
          ).to be false
        end
      end
    end

    context 'when token passed in is not found in database' do
      it 'returns nil' do
        group = create(:group)

        expect(
          described_class.token_matches_for_group?('notatoken', group)
        ).to be_nil
      end
    end
  end

  describe '#token' do
    shared_examples 'has a prefix' do
      it 'starts with prefix' do
        token = build(:group_scim_auth_access_token, token_encrypted: nil)
        token.save!

        expect(token.token).to start_with expected_prefix
      end
    end

    it 'generates a token on creation' do
      token = described_class.create!(group: create(:group))

      expect(token.token).to be_a(String)
    end

    it 'is prefixed' do
      token = create(:group_scim_auth_access_token)

      expect(token.token).to match(/^#{described_class::TOKEN_PREFIX}[\w-]{20}$/o)
    end

    it_behaves_like 'has a prefix' do
      let(:expected_prefix) { described_class::TOKEN_PREFIX }
    end

    context 'with instance prefix configured' do
      let(:instance_prefix) { 'instanceprefix' }

      before do
        stub_application_setting(instance_token_prefix: instance_prefix)
      end

      it_behaves_like 'has a prefix' do
        let(:expected_prefix) { "#{instance_prefix}-#{described_class::TOKEN_PREFIX}" }
      end

      context 'with feature flag custom_prefix_for_all_token_types disabled' do
        before do
          stub_feature_flags(custom_prefix_for_all_token_types: false)
        end

        it_behaves_like 'has a prefix' do
          let(:expected_prefix) { described_class::TOKEN_PREFIX }
        end
      end
    end
  end
end
