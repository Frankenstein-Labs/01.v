# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SamlGroupLink, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:access_level) }
    it { is_expected.to validate_presence_of(:saml_group_name) }
    it { is_expected.to validate_length_of(:saml_group_name).is_at_most(255) }
    it { is_expected.to validate_length_of(:provider).is_at_most(255) }

    context 'group name uniqueness' do
      let_it_be(:group) { create(:group) }

      before do
        create(:saml_group_link, group: group, saml_group_name: 'test-group')
      end

      it { is_expected.to validate_uniqueness_of(:saml_group_name).scoped_to([:group_id, :provider]) }

      context 'with same group name but different providers' do
        before do
          create(:saml_group_link, group: group, saml_group_name: 'duplicate-group', provider: 'provider1')
        end

        it 'allows creating links with same group name but different providers' do
          link = build(:saml_group_link, group: group, saml_group_name: 'duplicate-group', provider: 'provider2')

          expect(link).to be_valid
        end
      end

      context 'with same group name and nil provider' do
        before do
          create(:saml_group_link, group: group, saml_group_name: 'duplicate-group', provider: nil)
        end

        it 'allows creating links with same group name when one has nil provider' do
          link = build(:saml_group_link, group: group, saml_group_name: 'duplicate-group', provider: 'provider1')

          expect(link).to be_valid
        end
      end

      context 'with same group name and same provider' do
        before do
          create(:saml_group_link, group: group, saml_group_name: 'duplicate-group', provider: 'provider1')
        end

        it 'prevents creating duplicate links with same group name and provider' do
          duplicate_link = build(:saml_group_link, group: group, saml_group_name: 'duplicate-group',
            provider: 'provider1')

          expect(duplicate_link).not_to be_valid
          expect(duplicate_link.errors[:saml_group_name]).to include('has already been taken')
        end
      end

      context 'with both nil provider' do
        before do
          create(:saml_group_link, group: group, saml_group_name: 'duplicate-group', provider: nil)
        end

        it 'prevents creating duplicate links with same group name and nil provider' do
          duplicate_link = build(:saml_group_link, group: group, saml_group_name: 'duplicate-group', provider: nil)

          expect(duplicate_link).not_to be_valid
          expect(duplicate_link.errors[:saml_group_name]).to include('has already been taken')
        end
      end

      context 'across different groups' do
        let_it_be(:other_group) { create(:group) }

        it 'allows creating links with same group name and provider in different groups' do
          create(:saml_group_link, group: group, saml_group_name: 'same-group', provider: 'provider1')
          link_in_other_group = build(:saml_group_link, group: other_group, saml_group_name: 'same-group',
            provider: 'provider1')

          expect(link_in_other_group).to be_valid
        end
      end
    end

    context 'saml_group_name with whitespaces' do
      it 'saves group link name without whitespace' do
        saml_group_link = described_class.new(saml_group_name: '   group   ')
        saml_group_link.valid?

        expect(saml_group_link.saml_group_name).to eq('group')
      end
    end

    context 'provider with whitespaces' do
      it 'saves provider without whitespace' do
        saml_group_link = described_class.new(provider: '   idp-1   ')
        saml_group_link.valid?

        expect(saml_group_link.provider).to eq('idp-1')
      end
    end

    context 'provider normalization' do
      let_it_be(:group) { create(:group) }

      it 'normalizes empty string to nil' do
        saml_group_link = build(:saml_group_link, group: group, provider: '')

        expect(saml_group_link).to be_valid
        expect(saml_group_link.provider).to be_nil
      end

      it 'normalizes whitespace-only string to nil' do
        saml_group_link = build(:saml_group_link, group: group, provider: '   ')

        expect(saml_group_link).to be_valid
        expect(saml_group_link.provider).to be_nil
      end

      it 'keeps valid provider values unchanged' do
        saml_group_link = build(:saml_group_link, group: group, provider: 'okta')

        expect(saml_group_link).to be_valid
        expect(saml_group_link.provider).to eq('okta')
      end

      it 'keeps nil provider values unchanged' do
        saml_group_link = build(:saml_group_link, group: group, provider: nil)

        expect(saml_group_link).to be_valid
        expect(saml_group_link.provider).to be_nil
      end
    end

    context 'minimal access role' do
      let_it_be(:top_level_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: top_level_group) }

      def saml_group_link(group:)
        build(:saml_group_link, group: group, access_level: ::Gitlab::Access::MINIMAL_ACCESS)
      end

      before do
        stub_licensed_features(minimal_access_role: true)
      end

      it 'allows the role at the top level group' do
        expect(saml_group_link(group: top_level_group)).to be_valid
      end

      it 'does not allow the role for subgroups' do
        expect(saml_group_link(group: subgroup)).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    let_it_be(:group) { create(:group) }
    let_it_be(:group_link) { create(:saml_group_link, group: group) }

    describe '.by_id_and_group_id' do
      it 'finds the group link' do
        results = described_class.by_id_and_group_id(group_link.id, group.id)

        expect(results).to match_array([group_link])
      end

      context 'with multiple groups and group links' do
        let_it_be(:group2) { create(:group) }
        let_it_be(:group_link2) { create(:saml_group_link, group: group2) }

        it 'finds group links within the given groups' do
          results = described_class.by_id_and_group_id([group_link, group_link2], [group, group2])

          expect(results).to match_array([group_link, group_link2])
        end

        it 'does not find group links outside the given groups' do
          results = described_class.by_id_and_group_id([group_link, group_link2], [group])

          expect(results).to match_array([group_link])
        end
      end
    end

    describe '.by_saml_group_name' do
      it 'finds the group link' do
        results = described_class.by_saml_group_name(group_link.saml_group_name)

        expect(results).to match_array([group_link])
      end

      context 'with multiple groups and group links' do
        let_it_be(:group2) { create(:group) }
        let_it_be(:group_link2) { create(:saml_group_link, group: group2) }

        it 'finds group links within the given groups' do
          results = described_class.by_saml_group_name([group_link.saml_group_name, group_link2.saml_group_name])

          expect(results).to match_array([group_link, group_link2])
        end
      end
    end

    describe '.by_scim_group_uid' do
      let_it_be(:uid) { SecureRandom.uuid }
      let_it_be(:group_link_with_uid) { create(:saml_group_link, group: group, scim_group_uid: uid) }

      it 'finds the group link' do
        results = described_class.by_scim_group_uid(uid)

        expect(results).to match_array([group_link_with_uid])
      end

      it 'returns empty when no matches exist' do
        results = described_class.by_scim_group_uid(SecureRandom.uuid)

        expect(results).to be_empty
      end

      context 'with multiple groups and group links' do
        let_it_be(:group2) { create(:group) }
        let_it_be(:group_link2) { create(:saml_group_link, group: group2, scim_group_uid: uid) }

        it 'finds all matching group links' do
          results = described_class.by_scim_group_uid(uid)

          expect(results).to match_array([group_link_with_uid, group_link2])
        end
      end
    end

    describe '.by_assign_duo_seats' do
      let_it_be(:group_link_w_assign_duo_seats) { create(:saml_group_link, assign_duo_seats: true) }

      it 'finds group links with correct value' do
        results = described_class.by_assign_duo_seats(true)

        expect(results).to contain_exactly(group_link_w_assign_duo_seats)
      end
    end

    describe '.by_provider' do
      let_it_be(:provider_name) { 'okta' }
      let_it_be(:group_link_with_provider) { create(:saml_group_link, group: group, provider: provider_name) }
      let_it_be(:group_link_without_provider) { create(:saml_group_link, group: group, provider: nil) }

      it 'finds group links with the specified provider' do
        results = described_class.by_provider(provider_name)

        expect(results).to match_array([group_link_with_provider])
      end

      it 'finds group links with nil provider when searching for nil' do
        results = described_class.by_provider(nil)

        expect(results).to match_array([group_link, group_link_without_provider])
      end

      it 'returns empty when no matches exist' do
        results = described_class.by_provider('non-existent-provider')

        expect(results).to be_empty
      end

      context 'with multiple providers' do
        let_it_be(:azure_provider) { 'azure' }
        let_it_be(:group_link_with_azure) { create(:saml_group_link, group: group, provider: azure_provider) }

        it 'finds only group links with the specified provider' do
          results = described_class.by_provider(provider_name)

          expect(results).to match_array([group_link_with_provider])
          expect(results).not_to include(group_link_with_azure)
        end
      end

      context 'with multiple groups' do
        let_it_be(:group2) { create(:group) }
        let_it_be(:group_link2_with_provider) { create(:saml_group_link, group: group2, provider: provider_name) }

        it 'finds group links across all groups with the specified provider' do
          results = described_class.by_provider(provider_name)

          expect(results).to match_array([group_link_with_provider, group_link2_with_provider])
        end
      end

      context 'with array of providers' do
        let_it_be(:azure_provider) { 'azure' }
        let_it_be(:google_provider) { 'google' }
        let_it_be(:group_link_with_azure) { create(:saml_group_link, group: group, provider: azure_provider) }
        let_it_be(:group_link_with_google) { create(:saml_group_link, group: group, provider: google_provider) }

        it 'finds group links with any of the specified providers' do
          results = described_class.by_provider([provider_name, azure_provider])

          expect(results).to match_array([group_link_with_provider, group_link_with_azure])
          expect(results).not_to include(group_link_with_google)
        end
      end
    end
  end

  it_behaves_like 'model with member role relation' do
    subject(:model) { build(:saml_group_link) }

    context 'when the member role namespace is in the same hierarchy', feature_category: :permissions do
      before do
        model.member_role = create(:member_role, namespace: model.group, base_access_level: Gitlab::Access::GUEST)
        model.group = create(:group, parent: model.group)
      end

      it { is_expected.to be_valid }
    end

    describe '.with_scim_group_uid' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group_link_with_uid) { create(:saml_group_link, group: group, scim_group_uid: SecureRandom.uuid) }
      let_it_be(:group_link_without_uid) { create(:saml_group_link, group: group, scim_group_uid: nil) }

      it 'returns only links with non-nil scim_group_uid' do
        results = described_class.with_scim_group_uid

        expect(results).to include(group_link_with_uid)
        expect(results).not_to include(group_link_without_uid)
      end
    end
  end

  describe '.first_by_scim_group_uid' do
    let_it_be(:group) { create(:group) }
    let_it_be(:uid) { SecureRandom.uuid }
    let_it_be(:group_link_with_uid) { create(:saml_group_link, group: group, scim_group_uid: uid) }

    it 'returns the first matching group link' do
      expect(described_class.first_by_scim_group_uid(uid)).to eq(group_link_with_uid)
    end

    it 'returns nil when no matches exist' do
      expect(described_class.first_by_scim_group_uid(SecureRandom.uuid)).to be_nil
    end

    context 'when multiple matches exist' do
      let_it_be(:group2) { create(:group) }
      let_it_be(:another_group_link) { create(:saml_group_link, group: group2, scim_group_uid: uid) }

      it 'returns only one group link' do
        expect(described_class.first_by_scim_group_uid(uid)).to eq(group_link_with_uid)
      end
    end
  end
end
