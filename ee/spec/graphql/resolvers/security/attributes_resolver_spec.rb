# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::AttributesResolver, feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:root_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: root_group) }
  let_it_be(:project) { create(:project, group: sub_group) }
  let_it_be(:current_user) { create(:user) }

  let(:resolver) { described_class }
  let(:obj) { project }

  subject(:resolve_attributes) do
    resolve(resolver, obj: obj, ctx: { current_user: current_user }, arg_style: :internal)
  end

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#resolve' do
    context 'when user does not have permission' do
      it 'returns an empty array' do
        expect(resolve_attributes.items).to be_empty
      end
    end

    context 'when user has permission' do
      before_all do
        sub_group.add_maintainer(current_user)
      end

      context 'when project has linked attributes' do
        let_it_be(:category) { create(:security_category, namespace: root_group) }
        let_it_be(:attribute1) { create(:security_attribute, security_category: category, namespace: root_group) }
        let_it_be(:attribute2) { create(:security_attribute, security_category: category, namespace: root_group) }
        let_it_be(:association1) do
          create(:project_to_security_attribute, project: project, security_attribute: attribute1,
            traversal_ids: [root_group.id])
        end

        let_it_be(:association2) do
          create(:project_to_security_attribute, project: project, security_attribute: attribute2,
            traversal_ids: [root_group.id])
        end

        it 'returns security attributes linked to the project' do
          expect(resolve_attributes.items).to contain_exactly(attribute1, attribute2)
        end

        context 'when a linked attribute is soft-deleted' do
          let_it_be(:deleted_attribute) do
            create(:security_attribute, :soft_deleted, security_category: category, namespace: root_group)
          end

          let_it_be(:deleted_association) do
            create(:project_to_security_attribute, project: project, security_attribute: deleted_attribute,
              traversal_ids: [root_group.id])
          end

          it 'excludes soft-deleted attributes' do
            expect(resolve_attributes.items).to contain_exactly(attribute1, attribute2)
          end
        end

        it 'preloads security categories' do
          attributes = resolve_attributes.items
          expect(attributes.first.association(:security_category)).to be_loaded
        end

        it 'returns attributes with correct namespace_id' do
          attributes = resolve_attributes.items
          expect(attributes).to all(have_attributes(namespace_id: root_group.id))
        end
      end

      context 'when project has no attributes' do
        it 'returns an empty array' do
          expect(resolve_attributes.items).to be_empty
        end
      end
    end
  end
end
