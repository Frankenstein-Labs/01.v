# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Categories::FindOrCreateService, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:existing_category) { create(:security_category, namespace: root_group) }
  let_it_be(:predefined_category) do
    create(:security_category, namespace: root_group, template_type: :business_impact, name: "Business Impact")
  end

  let(:service) do
    described_class.new(
      category_id: category_id,
      namespace: namespace,
      current_user: current_user
    )
  end

  let(:category_id) { nil }
  let(:namespace) { root_group }
  let(:current_user) { user }

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when user does not have permission' do
      it 'returns unauthorized error' do
        expect(execute).to eq(described_class::UnauthorizedError)
      end
    end

    context 'when user has permission' do
      before_all do
        root_group.add_maintainer(user)
      end

      context 'when namespace is not present' do
        let(:namespace) { nil }

        it 'returns an error' do
          expect(execute).to be_error
          expect(execute.message).to eq('Namespace not found')
        end
      end

      context 'when CreatePredefinedService returns an error' do
        let(:category_id) { 'business_impact' }

        before do
          allow_next_instance_of(Security::Categories::CreatePredefinedService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Failed to create predefined categories')
            )
          end
        end

        it 'returns the error from CreatePredefinedService' do
          expect(execute).to be_error
          expect(execute.message).to eq('Failed to create predefined categories')
        end
      end

      context 'when finding by persisted category_id' do
        let(:category_id) { existing_category.id }

        it 'returns the existing category' do
          expect(execute).to be_success
          expect(execute.payload[:category]).to eq(existing_category)
        end

        it 'does not call CreatePredefinedService' do
          expect(Security::Categories::CreatePredefinedService).not_to receive(:new)

          execute
        end

        context 'when category does not exist' do
          let(:category_id) { non_existing_record_id }

          it 'returns an error' do
            expect(execute).to be_error
            expect(execute.message).to eq('Category not found')
          end
        end
      end

      context 'when finding by template_type string' do
        let(:category_id) { 'business_impact' }

        before do
          allow_next_instance_of(Security::Categories::CreatePredefinedService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        it 'returns the predefined category' do
          expect(execute).to be_success
          expect(execute.payload[:category]).to eq(predefined_category)
        end

        it 'calls CreatePredefinedService' do
          expect_next_instance_of(Security::Categories::CreatePredefinedService) do |service|
            expect(service).to receive(:execute).once.and_call_original
          end

          execute
        end

        context 'when template_type category does not exist' do
          let(:category_id) { 'exposure' }

          it 'returns an error' do
            expect(execute).to be_error
            expect(execute.message).to eq('Category not found')
          end
        end

        context 'when namespace is missing' do
          let(:namespace) { nil }
          let(:category_id) { 'business_impact' }

          it 'returns namespace not found error' do
            expect(execute).to be_error
            expect(execute.message).to eq('Namespace not found')
          end
        end
      end

      context 'when category_id is not provided' do
        let(:category_id) { nil }

        it 'returns an error' do
          expect(execute).to be_error
          expect(execute.message).to eq('Category not found')
        end
      end

      context 'when namespace is a subgroup' do
        let(:namespace) { subgroup }
        let(:category_id) { 'business_impact' }

        before do
          allow_next_instance_of(Security::Categories::CreatePredefinedService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        it 'searches in root_ancestor namespace' do
          expect(::Security::Category).to receive(:by_namespace_and_template_type)
            .with(root_group, category_id).and_call_original
          execute
        end
      end
    end

    context 'when user is maintainer of subgroup but not root group' do
      let(:namespace) { subgroup }

      before_all do
        subgroup.add_maintainer(user)
      end

      it 'returns unauthorized error because permission check is on root_ancestor' do
        expect(execute).to eq(described_class::UnauthorizedError)
      end
    end
  end
end
