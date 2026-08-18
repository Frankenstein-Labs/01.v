# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Registry::Upstream::Create, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  specify { expect(described_class).to require_graphql_authorizations(:create_virtual_registry) }

  describe '#service_class' do
    subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

    it 'raises NotImplementedError' do
      expect { mutation.send(:service_class) }.to raise_error(NotImplementedError)
    end
  end
end
