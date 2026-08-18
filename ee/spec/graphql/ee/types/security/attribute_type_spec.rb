# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::AttributeType, feature_category: :security_asset_inventories do
  include GraphqlHelpers

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :id,
      :name,
      :description,
      :color,
      :editable_state,
      :security_category
    )
  end

  it { expect(described_class.graphql_name).to eq('SecurityAttribute') }

  describe 'fields' do
    it { expect(described_class).to have_graphql_field(:id, resolver_method: :resolve_id) }
    it { expect(described_class).to have_graphql_field(:name) }
    it { expect(described_class).to have_graphql_field(:description) }
    it { expect(described_class).to have_graphql_field(:color) }
    it { expect(described_class).to have_graphql_field(:editable_state) }
    it { expect(described_class).to have_graphql_field(:security_category) }
  end

  describe '#resolve_id' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:category) { create(:security_category, namespace: namespace) }
    let_it_be(:current_user) { create(:user) }

    before_all do
      namespace.add_maintainer(current_user)
    end

    subject(:resolved_id) { resolve_field(:id, attribute, current_user: current_user) }

    context 'when attribute is persisted' do
      let(:attribute) do
        create(:security_attribute, security_category: category, namespace: namespace)
      end

      it 'returns the global ID' do
        expect(resolved_id).to eq(attribute.to_global_id)
      end

      it 'returns a GlobalID instance' do
        expect(resolved_id).to be_a(GlobalID)
      end

      it 'uses the database ID' do
        expect(resolved_id.model_id).to eq(attribute.id.to_s)
      end
    end

    context 'when attribute is not persisted' do
      let(:attribute) do
        build(:security_attribute,
          security_category: category,
          namespace: namespace,
          template_type: :mission_critical)
      end

      subject(:resolved_id) do
        type_instance = described_class.allocate
        type_instance.instance_variable_set(:@object, attribute)
        type_instance.resolve_id
      end

      it 'builds a URI::GID using template_type' do
        expect(attribute.persisted?).to be_falsey
        expect(resolved_id).to be_a(URI::GID)
      end

      it 'uses template_type as the model_id' do
        expect(resolved_id.model_id).to eq('mission_critical')
      end

      it 'has the correct model_name' do
        expect(resolved_id.model_name).to eq('Security::Attribute')
      end

      it 'matches the output of Gitlab::GlobalId.build' do
        expected_id = ::Gitlab::GlobalId.build(attribute, id: attribute.template_type)
        expect(resolved_id.to_s).to eq(expected_id.to_s)
      end
    end
  end

  describe '#security_category' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:category) { create(:security_category, namespace: namespace) }
    let_it_be(:attribute) { create(:security_attribute, security_category: category, namespace: namespace) }
    let_it_be(:current_user) { create(:user) }

    before_all do
      namespace.add_maintainer(current_user)
    end

    subject(:resolved_category) { resolve_field(:security_category, attribute, current_user: current_user) }

    it 'returns the associated category' do
      expect(resolved_category).to eq(category)
    end
  end
end
