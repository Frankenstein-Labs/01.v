# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::VirtualRegistries::Cache::Entry::Destroy, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  specify { expect(described_class).to require_graphql_authorizations(:destroy_virtual_registry) }

  describe '#cache_entry_model' do
    subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

    it 'raises NotImplementedError' do
      expect { mutation.send(:cache_entry_model) }.to raise_error(NotImplementedError)
    end
  end

  describe '#available?' do
    subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

    it 'raises NotImplementedError' do
      expect { mutation.send(:available?, nil) }.to raise_error(NotImplementedError)
    end
  end
end
