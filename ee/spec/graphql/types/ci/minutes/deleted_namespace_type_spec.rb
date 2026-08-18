# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::Minutes::DeletedNamespaceType, feature_category: :hosted_runners do
  include GraphqlHelpers

  subject(:type) { described_class }

  describe 'fields' do
    let(:fields) { %i[id] }

    it 'has the expected fields' do
      expect(type).to have_graphql_fields(fields)
    end

    describe 'id field' do
      let(:field) { type.fields['id'] }

      it 'returns a GlobalIDType[Namespace]' do
        expect(field.type.unwrap.to_type_signature).to eq('NamespaceID')
      end
    end
  end

  describe 'DeletedNamespace struct' do
    let(:namespace_id) { 123 }
    let(:deleted_namespace) { Types::Ci::Minutes::DeletedNamespaceType::DeletedNamespace.new(namespace_id) }

    it 'creates a new instance with the provided ID' do
      expect(deleted_namespace.raw_id).to eq(namespace_id)
    end

    it 'generates a global ID with Namespace model name' do
      global_id = deleted_namespace.to_global_id

      expect(global_id).to be_a(URI::GID)
      expect(global_id.model_name).to eq('Namespace')
      expect(global_id.model_id).to eq(namespace_id.to_s)
    end
  end
end
