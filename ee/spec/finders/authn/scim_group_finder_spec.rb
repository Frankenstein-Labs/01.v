# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::ScimGroupFinder, feature_category: :system_access do
  describe '#search' do
    let_it_be(:group1) { create(:saml_group_link, :with_scim_group_uid, saml_group_name: 'Engineering') }
    let_it_be(:group2) { create(:saml_group_link, :with_scim_group_uid, saml_group_name: 'Marketing') }

    let(:finder) { described_class.new }

    context 'without a filter' do
      it 'returns all groups' do
        result = finder.search({})

        expect(result).to include(group1, group2)
      end
    end

    context 'with displayName filter using double quotes' do
      it 'returns matching groups' do
        result = finder.search(filter: 'displayName eq "Engineering"')

        expect(result).to include(group1)
        expect(result).not_to include(group2)
      end
    end

    context 'with displayName filter using single quotes' do
      it 'returns matching groups' do
        result = finder.search(filter: "displayName eq 'Marketing'")

        expect(result).to include(group2)
        expect(result).not_to include(group1)
      end
    end

    context 'with case-insensitive displayName and operator' do
      it 'returns matching groups with lowercase displayname' do
        result = finder.search(filter: 'displayname eq "Engineering"')

        expect(result).to include(group1)
        expect(result).not_to include(group2)
      end

      it 'returns matching groups with uppercase DisplayName' do
        result = finder.search(filter: 'DisplayName eq "Engineering"')

        expect(result).to include(group1)
        expect(result).not_to include(group2)
      end

      it 'returns matching groups with uppercase EQ operator' do
        result = finder.search(filter: 'displayName EQ "Engineering"')

        expect(result).to include(group1)
        expect(result).not_to include(group2)
      end

      it 'returns matching groups with mixed case displayName and operator' do
        result = finder.search(filter: 'DiSpLaYnAmE eQ "Engineering"')

        expect(result).to include(group1)
        expect(result).not_to include(group2)
      end
    end

    context 'with unsupported filter format' do
      it 'raises UnsupportedFilter exception' do
        expect { finder.search(filter: 'unsupported filter') }
          .to raise_error(described_class::UnsupportedFilter)
      end
    end
  end
end
