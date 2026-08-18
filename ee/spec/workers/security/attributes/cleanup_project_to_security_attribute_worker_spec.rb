# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::CleanupProjectToSecurityAttributeWorker, feature_category: :security_policy_management do
  let_it_be(:namespace) { create(:group) }

  let_it_be(:security_category) { create(:security_category, namespace: namespace) }

  let_it_be_with_reload(:attribute1) do
    create(:security_attribute, security_category: security_category, namespace: namespace, name: "attr1")
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: security_category, namespace: namespace, name: "attr2")
  end

  let_it_be(:attribute3) do
    create(:security_attribute, security_category: security_category, namespace: namespace, name: "attr3")
  end

  describe '#perform' do
    subject(:worker) { described_class.new }

    context 'with single attribute' do
      let(:attribute_ids) { attribute1.id }

      let!(:associations) do
        Array.new(5) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      let!(:other_associations) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute2,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'deletes all associations for the given attribute' do
        # Soft delete attribute first
        attribute1.update!(deleted_at: Time.current)

        expect { worker.perform(attribute_ids) }
          .to change { Security::ProjectToSecurityAttribute.count }.by(-5)
      end

      it 'hard deletes the soft-deleted attribute after cleanup' do
        # Soft delete attribute first
        attribute1.update!(deleted_at: Time.current)

        expect { worker.perform(attribute_ids) }
          .to change { Security::Attribute.unscoped.count }.by(-1)
      end

      it 'does not delete associations for other attributes' do
        attribute1.update!(deleted_at: Time.current)
        worker.perform(attribute_ids)

        expect(Security::ProjectToSecurityAttribute.where(security_attribute: attribute2).count).to eq(3)
      end

      it 'returns success result' do
        attribute1.update!(deleted_at: Time.current)
        result = worker.perform(attribute_ids)

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(5)
      end
    end

    context 'with multiple attributes' do
      let(:attribute_ids) { [attribute1.id, attribute2.id] }

      let!(:associations1) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      let!(:associations2) do
        Array.new(4) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute2,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      let!(:associations3) do
        Array.new(2) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute3,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'deletes associations for all given attributes' do
        expect { worker.perform(attribute_ids) }
          .to change { Security::ProjectToSecurityAttribute.count }.by(-7)
      end

      it 'does not delete associations for attributes not in the list' do
        worker.perform(attribute_ids)

        expect(Security::ProjectToSecurityAttribute.where(security_attribute: attribute3).count).to eq(2)
      end

      it 'returns success result with total deletion count' do
        result = worker.perform(attribute_ids)

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(7)
      end
    end

    context 'with nil attribute_ids' do
      it 'returns early without performing any deletions' do
        expect(Security::Attributes::ProjectToSecurityAttributeDestroyService).not_to receive(:new)

        result = worker.perform(nil)

        expect(result).to be_nil
      end
    end

    context 'with empty attribute_ids array' do
      let(:attribute_ids) { [] }

      let!(:associations) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'does not delete any associations' do
        expect { worker.perform(attribute_ids) }
          .not_to change { Security::ProjectToSecurityAttribute.count }
      end

      it 'returns success result with zero count' do
        result = worker.perform(attribute_ids)

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(0)
      end
    end

    context 'when service returns error' do
      let(:attribute_ids) { attribute1.id }
      let(:error_message) { 'Database connection failed' }

      before do
        allow(Security::Attributes::ProjectToSecurityAttributeDestroyService)
          .to receive(:new).and_return(instance_double(
            Security::Attributes::ProjectToSecurityAttributeDestroyService,
            execute: ServiceResponse.error(message: error_message)
          ))
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(StandardError),
          hash_including(
            attribute_ids: attribute_ids,
            worker: 'Security::Attributes::CleanupProjectToSecurityAttributeWorker'
          )
        )

        worker.perform(attribute_ids)
      end

      it 'returns the error result' do
        result = worker.perform(attribute_ids)

        expect(result.success?).to be false
        expect(result.message).to eq(error_message)
      end
    end

    context 'when batch processing is needed' do
      let(:attribute_ids) { attribute1.id }

      before do
        stub_const('Security::Attributes::ProjectToSecurityAttributeDestroyService::BATCH_SIZE', 1)

        # Create more than batch size to test batching
        5.times do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'deletes all associations in batches' do
        attribute1.update!(deleted_at: Time.current)

        expect { worker.perform(attribute_ids) }
          .to change { Security::ProjectToSecurityAttribute.count }.by(-5)
      end

      it 'returns success result with correct count' do
        attribute1.update!(deleted_at: Time.current)
        result = worker.perform(attribute_ids)

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(5)
      end
    end

    context 'with category deletion' do
      it 'hard deletes the category after cleanup when category_id is provided' do
        # Create fresh resources for this test
        test_cat = create(:security_category, namespace: namespace, name: "DelCat1 #{SecureRandom.hex(8)}")
        test_attr = create(:security_attribute, security_category: test_cat, namespace: namespace,
          name: "del_attr1_#{SecureRandom.hex(8)}")

        # Soft delete them
        test_cat.update!(deleted_at: Time.current)
        test_attr.update!(deleted_at: Time.current)

        expect { worker.perform([test_attr.id], test_cat.id) }
          .to change { Security::Category.unscoped.count }.by(-1)
      end

      it 'does not delete the category when category_id is nil' do
        # Create fresh resources for this test
        test_cat = create(:security_category, namespace: namespace, name: "DelCat2 #{SecureRandom.hex(8)}")
        test_attr = create(:security_attribute, security_category: test_cat, namespace: namespace,
          name: "del_attr2_#{SecureRandom.hex(8)}")

        # Soft delete them
        test_cat.update!(deleted_at: Time.current)
        test_attr.update!(deleted_at: Time.current)

        expect { worker.perform([test_attr.id], nil) }
          .not_to change { Security::Category.unscoped.count }
      end

      it 'hard deletes only specified soft-deleted attributes when category_id is provided' do
        # Create a fresh category with two attributes
        test_category = create(:security_category, namespace: namespace, name: "TestCat #{SecureRandom.hex(8)}")
        attr1 = create(:security_attribute, security_category: test_category, namespace: namespace,
          name: "attr1_#{SecureRandom.hex(8)}")
        attr2 = create(:security_attribute, security_category: test_category, namespace: namespace,
          name: "attr2_#{SecureRandom.hex(8)}")

        # Soft delete only attr1 (simulating individual attribute deletion)
        attr1.update!(deleted_at: Time.current)

        # Worker should only delete attr1, not attr2
        worker.perform([attr1.id], nil)

        # Verify attr1 is gone
        expect(Security::Attribute.unscoped.find_by(id: attr1.id)).to be_nil
        # Verify attr2 still exists
        expect(Security::Attribute.unscoped.find_by(id: attr2.id)).to be_present
        # Verify category still exists (no category_id provided)
        expect(Security::Category.unscoped.find_by(id: test_category.id)).to be_present
      end
    end
  end
end
