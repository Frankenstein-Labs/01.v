# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScimOauthAccessToken, feature_category: :system_access do
  describe "Associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to :group }
  end

  describe 'validations' do
    context 'for instance-level SCIM tokens (group_id is nil)' do
      it 'requires organization_id on create' do
        token = described_class.new(group: nil, organization_id: nil)

        expect(token).not_to be_valid
        expect(token.errors[:organization_id]).to include("can't be blank")
      end

      it 'is valid when organization_id is set' do
        organization = create(:organization)
        token = described_class.new(group: nil, organization: organization)

        expect(token).to be_valid
        expect(token.errors[:organization_id]).to be_empty
      end
    end

    context 'for group-level SCIM tokens (group_id is present)' do
      it 'does not require organization_id on create' do
        group = create(:group)
        token = described_class.new(group: group, organization_id: nil)

        expect(token).to be_valid
        expect(token.errors[:organization_id]).to be_empty
      end
    end
  end

  describe '.token_matches_for_group?' do
    context 'when token passed in found in database' do
      context 'when token associated with group passed in' do
        it 'returns true' do
          group = create(:group)
          scim_token = create(:scim_oauth_access_token, group: group, organization: create(:organization))
          token_value = scim_token.token

          expect(
            described_class.token_matches_for_group?(token_value, group)
          ).to be true
        end
      end

      context 'when token not associated with group passed in' do
        it 'returns false' do
          other_group = create(:group)
          scim_token = create(:scim_oauth_access_token, group: create(:group), organization: create(:organization))
          token_value = scim_token.token

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

  describe '.token_matches_for_instance?' do
    context 'when token passed in found in database' do
      context 'when token not associated with a group' do
        it 'returns true' do
          scim_token = create(:scim_oauth_access_token, group: nil)
          token_value = scim_token.token

          expect(described_class.token_matches_for_instance?(token_value)).to be true
        end
      end

      context 'when token associated with a group' do
        it 'returns false' do
          scim_token = create(:scim_oauth_access_token, group: create(:group), organization: create(:organization))
          token_value = scim_token.token

          expect(described_class.token_matches_for_instance?(token_value)).to be false
        end
      end
    end

    context 'when token passed in not found in database' do
      it 'returns nil' do
        expect(described_class.token_matches_for_instance?('notatoken')).to be_nil
      end
    end
  end

  describe '.find_for_instance' do
    let!(:scim_token) { create(:scim_oauth_access_token, group: nil) }

    it 'find a token with group id nil' do
      expect(described_class.find_for_instance).to eq(scim_token)
    end
  end

  describe '#token' do
    shared_examples 'has a prefix' do
      it 'starts with prefix' do
        scim_token = build(:scim_oauth_access_token, group: create(:group), token_encrypted: nil)
        scim_token.save!

        expect(scim_token.token).to start_with expected_prefix
      end
    end

    it 'generates a prefixed token on creation' do
      scim_token = described_class.create!(group: create(:group), organization: create(:organization))

      expect(scim_token.token).to match(/^glsoat-[\w-]{20}$/)
    end

    it 'generates a prefixed token on creation with organization' do
      scim_token = described_class.create!(group: nil, organization: create(:organization))

      expect(scim_token.token).to match(/^glsoat-[\w-]{20}$/)
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
