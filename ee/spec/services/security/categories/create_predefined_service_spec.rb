# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Categories::CreatePredefinedService, feature_category: :security_asset_inventories do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }

  subject(:execute) { described_class.new(namespace: namespace, current_user: current_user).execute }

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#execute' do
    context 'when user does not have permission' do
      let(:current_user) { create(:user) }

      it 'does not create any security categories' do
        expect { execute }.not_to change { Security::Category.count }
      end

      it 'returns UnauthorizedError' do
        expect(execute).to eq(described_class::UnauthorizedError)
      end
    end

    context 'when namespace has a parent' do
      let_it_be(:sub_group) { create(:group, parent: namespace) }

      subject(:execute) { described_class.new(namespace: sub_group, current_user: current_user).execute }

      it 'creates categories in the root namespace' do
        execute

        expect(Security::Category.where(namespace: namespace).pluck(:namespace_id).uniq)
          .to eq([namespace.id])
      end

      it 'returns a success response' do
        expect(execute).to be_a(ServiceResponse)
        expect(execute).to be_success
      end
    end

    context 'when namespace already has categories' do
      before do
        create(:security_category, namespace: namespace)
      end

      it 'does not create any new categories' do
        expect { execute }.not_to change { Security::Category.count }
      end

      it 'returns a success response' do
        expect(execute).to be_a(ServiceResponse)
        expect(execute).to be_success
      end
    end

    context 'when namespace has no existing categories' do
      it 'creates all predefined categories' do
        expected_count = Security::DefaultCategoriesHelper.default_categories.size

        expect { execute }.to change { Security::Category.count }.by(expected_count)
      end

      it 'creates categories with correct attributes' do
        execute

        business_impact = Security::Category.where(namespace: namespace).find_by(template_type: :business_impact)
        expect(business_impact).to have_attributes(
          Security::DefaultCategoriesHelper.build_business_impact_category.attributes
          .except('id', 'created_at', 'updated_at', 'namespace_id')
        )
      end

      it 'creates categories with their security attributes' do
        execute

        attributes = Security::DefaultCategoriesHelper.build_business_impact_category.security_attributes
        business_impact = Security::Category.find_by(namespace: namespace, template_type: :business_impact)
        expect(business_impact.security_attributes.count).to eq(attributes.length)

        created_values = business_impact.security_attributes.pluck(:name, :template_type)
        expected_attributes = attributes.map { |attr| [attr.name, attr.template_type] }

        expect(created_values).to match_array(expected_attributes)
      end

      it 'creates all expected template types' do
        execute

        created_template_types = Security::Category.where(namespace: namespace).pluck(:template_type)
        expected_template_types = Security::DefaultCategoriesHelper.default_categories.map(&:template_type)

        expect(created_template_types).to match_array(expected_template_types)
      end

      it 'returns a success response' do
        expect(execute).to be_a(ServiceResponse)
        expect(execute).to be_success
      end
    end

    context 'with different namespace scenarios' do
      context 'when namespace is a subgroup' do
        let!(:parent_group) { create(:group) }
        let(:child_group) { create(:group, parent: parent_group) }
        let(:grandchild_group) { create(:group, parent: child_group) }
        let(:user) { create(:user, owner_of: parent_group) }

        subject(:execute) { described_class.new(namespace: grandchild_group, current_user: user).execute }

        it 'creates categories in the root namespace' do
          execute

          expect(Security::Category.all.map(&:namespace_id).uniq).to eq([parent_group.id])
        end
      end
    end

    context 'when there is an error during creation' do
      before do
        allow_next_instance_of(Security::Category) do |instance|
          allow(instance).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)
        end
      end

      it 'returns an error response' do
        response = execute

        expect(response).to be_a(ServiceResponse)
        expect(execute).to be_error
        expect(response.message).to include("Failed to create default categories")
      end
    end
  end
end
