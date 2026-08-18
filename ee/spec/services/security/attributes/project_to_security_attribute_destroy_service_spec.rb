# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::ProjectToSecurityAttributeDestroyService,
  feature_category: :security_policy_management,
  factory_default: :keep do
  let_it_be(:namespace) { create_default(:group) }
  let_it_be(:creator) { create_default(:user) }

  let_it_be(:security_category) { create(:security_category, namespace: namespace) }

  let_it_be(:attribute1) do
    create(:security_attribute, security_category: security_category, namespace: namespace, name: "attr1")
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: security_category, namespace: namespace, name: "attr2")
  end

  let_it_be(:attribute3) do
    create(:security_attribute, security_category: security_category, namespace: namespace, name: "attr3")
  end

  describe '#execute' do
    subject(:service) { described_class.new(attribute_ids: attribute_ids) }

    context 'with single attribute' do
      let(:attribute_ids) { attribute1.id }

      let_it_be(:associations) do
        Array.new(5) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      let_it_be(:other_associations) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute2,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'deletes all associations for the given attribute' do
        expect { service.execute }.to change { Security::ProjectToSecurityAttribute.count }.by(-5)
      end

      it 'does not delete associations for other attributes' do
        service.execute

        expect(Security::ProjectToSecurityAttribute.where(security_attribute: attribute2).count).to eq(3)
      end

      it 'returns success response with deletion count' do
        result = service.execute

        expect(result.success?).to be true
        expect(result.message).to eq("Successfully deleted project to security attribute associations")
        expect(result.payload[:deleted_count]).to eq(5)
      end
    end

    context 'with multiple attributes' do
      let(:attribute_ids) { [attribute1.id, attribute2.id] }

      let_it_be(:associations1) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      let_it_be(:associations2) do
        Array.new(4) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute2,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      let_it_be(:associations3) do
        Array.new(2) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute3,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'deletes associations for all given attributes' do
        expect { service.execute }.to change { Security::ProjectToSecurityAttribute.count }.by(-7)
      end

      it 'does not delete associations for attributes not in the list' do
        service.execute

        expect(Security::ProjectToSecurityAttribute.where(security_attribute: attribute3).count).to eq(2)
      end

      it 'returns success response with total deletion count' do
        result = service.execute

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(7)
      end
    end

    context 'with empty attribute_ids array' do
      let(:attribute_ids) { [] }

      let_it_be(:associations) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'does not delete any associations' do
        expect { service.execute }.not_to change { Security::ProjectToSecurityAttribute.count }
      end

      it 'returns success response with zero count' do
        result = service.execute

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(0)
      end
    end

    context 'with non-existent attribute id' do
      let(:attribute_ids) { 999999 }

      let_it_be(:associations) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'does not delete any associations' do
        expect { service.execute }.not_to change { Security::ProjectToSecurityAttribute.count }
      end

      it 'returns success response with zero count' do
        result = service.execute

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(0)
      end
    end

    context 'when batch processing is needed' do
      let(:attribute_ids) { attribute1.id }

      before_all do
        # Create more records than the stubbed BATCH_SIZE of 1 to test batching
        2.times do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      before do
        stub_const('Security::Attributes::ProjectToSecurityAttributeDestroyService::BATCH_SIZE', 1)
      end

      it 'deletes all associations in batches' do
        expect { service.execute }.to change { Security::ProjectToSecurityAttribute.count }.by(-2)
      end

      it 'returns success response with correct count' do
        result = service.execute

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(2)
      end
    end

    context 'when an error occurs' do
      let(:attribute_ids) { attribute1.id }

      before do
        allow(Security::ProjectToSecurityAttribute).to receive(:where).and_raise(StandardError.new("Database error"))
      end

      it 'returns error response' do
        result = service.execute

        expect(result.success?).to be false
        expect(result.message).to include("Failed to delete project to security attribute associations")
        expect(result.message).to include("Database error")
      end
    end
  end

  describe 'private methods' do
    let(:service) { described_class.new(attribute_ids: [attribute1.id]) }

    describe '#delete_associations_for_attribute' do
      let_it_be(:associations) do
        Array.new(5) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'deletes all associations for a specific attribute' do
        expect { service.send(:delete_associations_for_attribute, attribute1.id) }
          .to change { Security::ProjectToSecurityAttribute.where(security_attribute: attribute1).count }.by(-5)
      end

      it 'returns the count of deleted associations' do
        count = service.send(:delete_associations_for_attribute, attribute1.id)

        expect(count).to eq(5)
      end
    end
  end
end
