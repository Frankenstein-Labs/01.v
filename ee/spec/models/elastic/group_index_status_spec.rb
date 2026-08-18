# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::GroupIndexStatus, feature_category: :global_search do
  subject(:index_status) { described_class.new }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace_id) }
    it { is_expected.not_to allow_value(nil).for(:namespace_id) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:group).with_foreign_key('namespace_id') }
  end

  describe 'scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:group_index_status) { create(:group_index_status, group: group) }

    describe '.for_group' do
      it 'returns the status associated with the provided group' do
        create(:group_index_status)
        expect(described_class.for_group(group)).to contain_exactly(group_index_status)
      end
    end
  end
end
