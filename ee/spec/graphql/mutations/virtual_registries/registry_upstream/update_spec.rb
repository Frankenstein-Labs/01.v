# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::RegistryUpstream::Update, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  specify { expect(described_class).to require_graphql_authorizations(:update_virtual_registry) }

  describe '#enabled?' do
    subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

    it 'raises NotImplementedError' do
      expect { mutation.send(:enabled?, nil) }.to raise_error(NotImplementedError)
    end
  end
end
