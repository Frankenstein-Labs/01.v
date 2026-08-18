# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::CategoryType, feature_category: :security_asset_inventories do
  include GraphqlHelpers

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :id,
      :name,
      :description,
      :editable_state,
      :multiple_selection,
      :security_attributes,
      :template_type
    )
  end

  it { expect(described_class.graphql_name).to eq('SecurityCategory') }

  describe 'fields' do
    it { expect(described_class).to have_graphql_field(:id, resolver_method: :resolve_id) }
    it { expect(described_class).to have_graphql_field(:name) }
    it { expect(described_class).to have_graphql_field(:description) }
    it { expect(described_class).to have_graphql_field(:editable_state) }
    it { expect(described_class).to have_graphql_field(:multiple_selection) }
    it { expect(described_class).to have_graphql_field(:security_attributes) }
    it { expect(described_class).to have_graphql_field(:template_type) }
  end

  describe '#security_attributes' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:namespace) { create(:group, maintainers: current_user) }

    subject(:resolved_attributes) { resolve_field(:security_attributes, category, current_user: current_user) }

    context 'when category is persisted' do
      let_it_be(:category) { create(:security_category, namespace: namespace) }
      let_it_be(:active_attribute) do
        create(:security_attribute, security_category: category, namespace: namespace, name: 'Active')
      end

      let_it_be(:deleted_attribute) do
        create(:security_attribute, security_category: category, namespace: namespace, name: 'Deleted',
          deleted_at: Time.current)
      end

      it 'returns only non-deleted attributes' do
        expect(resolved_attributes).to contain_exactly(active_attribute)
      end
    end

    context 'when category is not persisted' do
      let(:category) { Security::DefaultCategoriesHelper.build_business_impact_category }

      it 'returns the in-memory attributes' do
        expect(resolved_attributes.map(&:name)).to match_array(category.security_attributes.map(&:name))
      end
    end
  end

  describe '#resolve_id' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:current_user) { create(:user) }

    before_all do
      namespace.add_maintainer(current_user)
    end

    subject(:resolved_id) { resolve_field(:id, category, current_user: current_user) }

    context 'when category is persisted' do
      let(:category) { create(:security_category, namespace: namespace) }

      it 'returns the global ID' do
        expect(resolved_id).to eq(category.to_global_id)
      end

      it 'returns a GlobalID instance' do
        expect(resolved_id).to be_a(GlobalID)
      end

      it 'uses the database ID' do
        expect(resolved_id.model_id).to eq(category.id.to_s)
      end
    end

    context 'when category is not persisted' do
      let(:category) do
        build(:security_category, namespace: namespace, template_type: 'business_impact')
      end

      subject(:resolved_id) do
        type_instance = described_class.allocate
        type_instance.instance_variable_set(:@object, category)
        type_instance.resolve_id
      end

      it 'builds a URI::GID using template_type' do
        expect(category.persisted?).to be_falsey
        expect(resolved_id).to be_a(URI::GID)
      end

      it 'uses template_type as the model_id' do
        expect(resolved_id.model_id).to eq('business_impact')
      end

      it 'has the correct model_name' do
        expect(resolved_id.model_name).to eq('Security::Category')
      end

      it 'matches the output of Gitlab::GlobalId.build' do
        expected_id = ::Gitlab::GlobalId.build(category, id: category.template_type)
        expect(resolved_id.to_s).to eq(expected_id.to_s)
      end
    end
  end
end
