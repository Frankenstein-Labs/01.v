# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::AttributeFilterInputType, feature_category: :security_asset_inventories do
  specify { expect(described_class.graphql_name).to eq('AttributeFilterInput') }

  it 'has the expected arguments' do
    expect(described_class.arguments.keys).to match_array(%w[operator attributes])
  end

  describe 'operator argument' do
    let(:argument) { described_class.arguments['operator'] }

    it 'is required' do
      expect(argument.type).to be_non_null
    end

    it 'has the correct type' do
      expect(argument.type.of_type).to eq(Types::Security::AttributeFilterOperatorEnum)
    end
  end

  describe 'attributes argument' do
    let(:argument) { described_class.arguments['attributes'] }

    it 'is required' do
      expect(argument.type).to be_non_null
    end

    it 'has the correct type' do
      expect(argument.type.of_type).to be_list
      expect(argument.type.of_type.of_type.of_type).to eq(Types::GlobalIDType[::Security::Attribute])
    end

    describe 'prepare' do
      let_it_be(:group) { create(:group) }
      let_it_be(:security_category) { create(:security_category, namespace: group) }
      let_it_be(:attribute1) { create(:security_attribute, security_category: security_category, namespace: group) }
      let_it_be(:attribute2) { create(:security_attribute, security_category: security_category, namespace: group) }

      it 'converts GlobalIDs to model IDs' do
        global_ids = [
          attribute1.to_global_id.to_s,
          attribute2.to_global_id.to_s
        ]

        result = argument.prepare.call(global_ids, nil)

        expect(result).to contain_exactly(attribute1.id, attribute2.id)
      end

      it 'filters out invalid GlobalIDs' do
        global_ids = [
          attribute1.to_global_id.to_s,
          'invalid-global-id',
          attribute2.to_global_id.to_s
        ]

        expect { argument.prepare.call(global_ids, nil) }
          .to raise_error(Gitlab::Graphql::Errors::ArgumentError, /is not a valid GitLab ID/)
      end
    end
  end
end
