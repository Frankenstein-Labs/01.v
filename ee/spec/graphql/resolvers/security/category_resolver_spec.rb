# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::CategoryResolver, feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:root_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: root_group) }
  let_it_be(:current_user) { create(:user) }

  let(:resolver) { described_class }
  let(:group) { root_group }

  subject(:resolve_categories) do
    resolve(resolver, obj: group, ctx: { current_user: current_user }, arg_style: :internal)
  end

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#resolve' do
    context 'when user does not have permission' do
      it 'raises a resource not available error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolve_categories
        end
      end
    end

    context 'when user has permission' do
      before_all do
        root_group.add_maintainer(current_user)
      end

      context 'when resolving for a subgroup' do
        let(:group) { sub_group }

        context 'when root ancestor has existing categories' do
          let_it_be(:category1) { create(:security_category, namespace: root_group, name: 'Category A') }
          let_it_be(:category2) { create(:security_category, namespace: root_group, name: 'Category B') }
          let_it_be(:attribute1) { create(:security_attribute, security_category: category1, namespace: root_group) }
          let_it_be(:attribute2) { create(:security_attribute, security_category: category2, namespace: root_group) }

          it 'returns categories from the root ancestor' do
            expect(resolve_categories.items).to contain_exactly(category1, category2)
          end

          it 'preloads non-deleted security attributes' do
            categories = resolve_categories.items
            expect(categories.first.association(:not_deleted_security_attributes)).to be_loaded
          end

          context 'when a category has only soft-deleted attributes' do
            let_it_be(:empty_category) { create(:security_category, namespace: root_group, name: 'Category C') }
            let_it_be(:deleted_attribute) do
              create(:security_attribute, security_category: empty_category, namespace: root_group,
                deleted_at: Time.current)
            end

            it 'still returns the category with no attributes', :aggregate_failures do
              resolved = resolve_categories.items.find { |c| c.id == empty_category.id }

              expect(resolved).to be_present
              expect(resolved.not_deleted_security_attributes).to be_empty
            end
          end

          it 'returns persisted categories with valid ids' do
            categories = resolve_categories.items
            expect(categories.map(&:id)).to all(be_present)
            expect(categories).to all(be_persisted)
          end

          it 'returns attributes with correct namespace_id' do
            categories = resolve_categories.items
            all_attributes = categories.flat_map(&:security_attributes)

            expect(all_attributes).to all(have_attributes(namespace_id: root_group.id))
          end

          it 'avoids N+1 queries when loading categories with attributes' do
            resolve_categories

            control = ActiveRecord::QueryRecorder.new do
              categories = resolve_categories.items
              categories.each { |category| category.not_deleted_security_attributes.to_a }
            end

            3.times do |i|
              create(:security_category, namespace: root_group, name: "Extra Category #{i}").tap do |category|
                create_list(:security_attribute, 3, security_category: category, namespace: root_group)
              end
            end

            expect do
              categories = resolve_categories.items
              categories.each { |category| category.not_deleted_security_attributes.to_a }
            end.not_to exceed_query_limit(control)
          end
        end

        context 'when root ancestor has no categories' do
          it 'returns default categories' do
            expect(resolve_categories.items.size).to eq(Security::DefaultCategoriesHelper.default_categories.size)
          end

          it 'sets namespace_id on default categories' do
            expect(resolve_categories.items.map(&:namespace_id)).to all(eq(root_group.id))
          end

          it 'sets namespace_id on default attributes' do
            categories = resolve_categories.items
            all_attributes = categories.flat_map(&:security_attributes)

            expect(all_attributes).to all(be_present)
            expect(all_attributes.map(&:namespace_id)).to all(eq(root_group.id))
          end

          it 'includes the expected default category types' do
            categories = resolve_categories.items
            template_types = categories.map(&:template_type)

            expect(template_types)
              .to match_array(::Security::DefaultCategoriesHelper.default_categories.map(&:template_type))
          end

          it 'returns null IDs for unpersisted default categories and attributes' do
            categories = resolve_categories.items

            expect(categories.map(&:id)).to all(be_nil)
            all_attributes = categories.flat_map(&:security_attributes)
            expect(all_attributes.map(&:id)).to all(be_nil)
          end

          it 'includes correct attributes for business_impact category' do
            categories = resolve_categories.items
            business_impact = categories.find { |c| c.template_type == 'business_impact' }

            expect(business_impact.security_attributes.map(&:name)).to match_array(
              ::Security::DefaultCategoriesHelper.build_business_impact_category.security_attributes.map(&:name)
            )
          end

          it 'ensures all attributes have the same namespace_id as their categories' do
            categories = resolve_categories.items

            categories.each do |category|
              expect(category.namespace_id).to eq(root_group.id)

              category.security_attributes.each do |attribute|
                expect(attribute.namespace_id).to eq(category.namespace_id)
              end
            end
          end
        end
      end

      context 'when resolving for root group directly' do
        let(:group) { root_group }

        context 'with existing categories' do
          let_it_be(:category) { create(:security_category, namespace: root_group) }

          it 'returns existing categories' do
            expect(resolve_categories.items).to contain_exactly(category)
          end
        end

        context 'without existing categories' do
          it 'returns default categories' do
            expect(resolve_categories.items.size).to eq(Security::DefaultCategoriesHelper.default_categories.size)
          end
        end
      end
    end
  end
end
