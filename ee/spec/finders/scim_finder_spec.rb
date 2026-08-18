# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScimFinder, feature_category: :system_access do
  include LoginHelpers

  let_it_be(:group) { create(:group) }
  let(:unused_params) { double }

  subject(:finder) { described_class.new(group) }

  describe '#initialize' do
    context 'on Gitlab.com', :saas do
      it 'raises error for group not passed' do
        expect { described_class.new }.to raise_error(ArgumentError)
      end
    end

    context 'on self managed' do
      it 'does not raise error when group is not passed' do
        expect { described_class.new }.not_to raise_error { ArgumentError }
      end
    end
  end

  describe '#search' do
    context 'without a SAML provider' do
      it 'returns an empty scim identity relation' do
        expect(finder.search(unused_params)).to eq ScimIdentity.none
      end
    end

    context 'SCIM/SAML is not enabled' do
      before do
        create(:saml_provider, group: group, enabled: false)
      end

      it 'returns an empty scim identity relation' do
        expect(finder.search(unused_params)).to eq ScimIdentity.none
      end
    end
  end
end
