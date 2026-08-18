# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SshCertificate, feature_category: :source_code_management do
  describe 'associations' do
    it 'belongs to a group' do
      is_expected.to belong_to(:group).with_foreign_key(:namespace_id).inverse_of(:ssh_certificates)
    end
  end

  subject { build(:group_ssh_certificate) }

  describe 'validations' do
    it 'presence fields' do
      is_expected.to validate_presence_of(:group)
      is_expected.to validate_presence_of(:key)
      is_expected.to validate_presence_of(:title)
      is_expected.to validate_presence_of(:fingerprint)
    end

    it 'length of key and title' do
      is_expected.to validate_length_of(:title).is_at_most(255)
      is_expected.to validate_length_of(:key).is_at_most(5000)
    end

    it 'format of the key' do
      is_expected.to allow_value(build(:rsa_key_4096).key).for(:key)
      is_expected.not_to allow_value('unsupported-ssh-rsa key').for(:key)
    end

    it 'uniqueness of fingerprint scoped to namespace_id' do
      existing = create(:group_ssh_certificate)

      duplicate = build(:group_ssh_certificate, group: existing.group, fingerprint: existing.fingerprint)
      expect(duplicate).to be_invalid
      expect(duplicate.errors[:fingerprint]).to include(
        'must be unique. This CA has already been configured for this namespace.'
      )

      other_group = create(:group)
      different_namespace = build(:group_ssh_certificate, group: other_group, fingerprint: existing.fingerprint)
      expect(different_namespace).to be_valid
    end

    it_behaves_like 'meets ssh key restrictions'
  end

  describe 'scopes' do
    let_it_be(:group1) { create(:group) }
    let_it_be(:group2) { create(:group) }
    let_it_be(:cert1) { create(:group_ssh_certificate, group: group1) }
    let_it_be(:cert2) { create(:group_ssh_certificate, group: group2) }

    describe '.for_fingerprint' do
      it 'returns certificates matching the fingerprint' do
        result = described_class.for_fingerprint(cert1.fingerprint)

        expect(result).to contain_exactly(cert1)
      end

      it 'returns empty when no match' do
        result = described_class.for_fingerprint('nonexistent')

        expect(result).to be_empty
      end
    end

    describe '.for_namespace' do
      it 'returns certificates for the given namespace' do
        result = described_class.for_namespace(group1.id)

        expect(result).to contain_exactly(cert1)
      end

      it 'returns empty when no match' do
        result = described_class.for_namespace(non_existing_record_id)

        expect(result).to be_empty
      end
    end
  end
end
