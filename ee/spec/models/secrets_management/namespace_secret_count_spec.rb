# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::NamespaceSecretCount, feature_category: :secrets_management do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
    it { is_expected.to belong_to(:root_namespace).class_name('Namespace').required }
  end

  describe 'validations' do
    subject(:record) { build(:namespace_secret_count) }

    it 'is valid with non-negative count' do
      record.count = 0
      expect(record).to be_valid

      record.count = 5
      expect(record).to be_valid
    end

    it 'is invalid with negative count' do
      record.count = -1
      expect(record).not_to be_valid
      expect(record.errors[:count]).to be_present
    end

    it 'is invalid with non-integer count' do
      record.count = 1.5
      expect(record).not_to be_valid
    end
  end

  describe '.for_root_namespace' do
    let_it_be(:root_a) { create(:group) }
    let_it_be(:root_b) { create(:group) }
    let_it_be(:row_a) { create(:namespace_secret_count, namespace: root_a, root_namespace: root_a, count: 3) }
    let_it_be(:row_b) { create(:namespace_secret_count, namespace: root_b, root_namespace: root_b, count: 7) }

    it 'filters rows by root namespace id' do
      expect(described_class.for_root_namespace(root_a.id)).to contain_exactly(row_a)
    end
  end

  describe 'primary key' do
    it 'is namespace_id' do
      expect(described_class.primary_key).to eq('namespace_id')
    end
  end
end
