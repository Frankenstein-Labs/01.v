# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::UpdateProjectConnectionsService, feature_category: :security_asset_inventories do
  let_it_be(:old_root_namespace) { create(:group) }
  let_it_be(:new_root_namespace) { create(:group) }
  let_it_be(:different_root_namespace) { create(:group) }

  let_it_be(:security_category_old_ns) { create(:security_category, namespace: old_root_namespace) }
  let_it_be(:security_attribute1) do
    create(:security_attribute, security_category: security_category_old_ns,
      namespace: old_root_namespace, name: "attr1")
  end

  let_it_be(:security_attribute2) do
    create(:security_attribute, security_category: security_category_old_ns,
      namespace: old_root_namespace, name: "attr2")
  end

  let_it_be(:security_category_new_ns) { create(:security_category, namespace: new_root_namespace) }
  let_it_be(:security_attribute_new_ns) do
    create(:security_attribute, security_category: security_category_new_ns,
      namespace: new_root_namespace, name: "attr1")
  end

  let_it_be(:security_attribute_new_ns2) do
    create(:security_attribute, security_category: security_category_new_ns,
      namespace: new_root_namespace, name: "attr3")
  end

  let_it_be(:security_category_different_ns) { create(:security_category, namespace: different_root_namespace) }
  let_it_be(:security_attribute_different_ns) do
    create(:security_attribute, security_category: security_category_different_ns,
      namespace: different_root_namespace, name: "attr1")
  end

  let_it_be(:old_root_subgroup) { create(:group, parent: old_root_namespace) }
  let_it_be(:new_root_subgroup) { create(:group, parent: new_root_namespace) }
  let_it_be(:different_root_subgroup) { create(:group, parent: different_root_namespace) }

  let_it_be(:project_in_old_subgroup) { create(:project, namespace: old_root_subgroup) }
  let_it_be(:project_in_new_subgroup) { create(:project, namespace: new_root_subgroup) }
  let_it_be(:project_outside_scope) { create(:project, namespace: different_root_subgroup) }

  let(:project_ids) { [project_in_old_subgroup.id, project_in_new_subgroup.id] }
  let(:new_root_namespace_id) { new_root_namespace.id }
  let(:service) { described_class.new(project_ids: project_ids, new_root_namespace_id: new_root_namespace_id) }

  subject(:execute) { service.execute }

  describe '.execute' do
    it 'creates a new instance and calls execute' do
      expect(described_class).to receive(:new).with(
        project_ids: project_ids,
        new_root_namespace_id: new_root_namespace_id
      ).and_call_original

      described_class.execute(project_ids: project_ids, new_root_namespace_id: new_root_namespace_id)
    end
  end

  describe '#initialize' do
    it 'sorts project_ids and assigns instance variables' do
      unsorted_project_ids = [3, 1, 2]
      service = described_class.new(project_ids: unsorted_project_ids, new_root_namespace_id: new_root_namespace_id)

      expect(service.project_ids).to match_array([1, 2, 3])
      expect(service.new_root_namespace_id).to eq(new_root_namespace_id)
    end
  end

  describe '#execute' do
    context 'when request is invalid' do
      context 'when project_ids is empty' do
        let(:project_ids) { [] }

        it 'returns early without performing any operations' do
          expect(service).not_to receive(:cleanup_mismatched_connections)
          expect(service).not_to receive(:update_traversal_ids_for_remaining_connections)

          execute
        end
      end

      context 'when project_ids is nil' do
        let(:project_ids) { nil }

        it 'returns early without performing any operations' do
          expect(service).not_to receive(:cleanup_mismatched_connections)
          expect(service).not_to receive(:update_traversal_ids_for_remaining_connections)

          execute
        end
      end
    end

    context 'when request is valid' do
      context 'when new_root_namespace_id is present' do
        let!(:connection_to_delete1) do
          connection = build(:project_to_security_attribute, project: project_in_old_subgroup,
            security_attribute: security_attribute1, traversal_ids: old_root_subgroup.traversal_ids)
          connection.save!(validate: false)
          connection
        end

        let!(:connection_to_delete2) do
          connection = build(:project_to_security_attribute, project: project_in_new_subgroup,
            security_attribute: security_attribute2, traversal_ids: different_root_subgroup.traversal_ids)
          connection.save!(validate: false)
          connection
        end

        let!(:connection_to_keep1) do
          create(:project_to_security_attribute, project: project_in_new_subgroup,
            security_attribute: security_attribute_new_ns, traversal_ids: new_root_subgroup.traversal_ids)
        end

        let!(:connection_to_keep_outside_scope) do
          create(:project_to_security_attribute, project: project_outside_scope,
            security_attribute: security_attribute_different_ns, traversal_ids: different_root_subgroup.traversal_ids)
        end

        it 'deletes mismatched connections and updates traversal_ids for remaining connections' do
          expect { execute }.to change { Security::ProjectToSecurityAttribute.count }.by(-2)

          expect(Security::ProjectToSecurityAttribute.exists?(connection_to_delete1.id)).to be_falsey
          expect(Security::ProjectToSecurityAttribute.exists?(connection_to_delete2.id)).to be_falsey
          expect(Security::ProjectToSecurityAttribute.exists?(connection_to_keep1.id)).to be_truthy
          expect(Security::ProjectToSecurityAttribute.exists?(connection_to_keep_outside_scope.id)).to be_truthy
        end

        it 'updates traversal_ids for remaining connections' do
          # Create a separate connection that should have its traversal_ids updated
          # Use traversal_ids that have the correct root namespace but wrong intermediate path
          old_traversal_ids = [new_root_namespace.id, 999, 888] # Correct root, wrong intermediate
          connection_with_old_traversal_ids = build(:project_to_security_attribute,
            project: project_in_new_subgroup,
            security_attribute: security_attribute_new_ns2,
            traversal_ids: old_traversal_ids)
          connection_with_old_traversal_ids.save!(validate: false)

          expect { execute }.to change { connection_with_old_traversal_ids.reload.traversal_ids }
            .from(old_traversal_ids).to(project_in_new_subgroup.namespace.traversal_ids)
        end

        context 'with batch processing behavior' do
          before do
            stub_const("#{described_class}::PROJECT_BATCH_SIZE", 1)
            stub_const("#{described_class}::CONNECTIONS_BATCH_SIZE", 1)
          end

          it 'processes connections in batches' do
            expect(service).to receive(:delete_connections_for_project_batch).twice.and_call_original
            # once to get the connection ids, once to get empty array and exit loop
            expect(service).to receive(:ids_to_delete_for_batch).exactly(4).times.and_call_original

            execute
          end

          it 'processes projects in batches for traversal_id updates' do
            expect(Project).to receive(:by_ids).twice.and_call_original

            execute
          end
        end
      end

      context 'when new_root_namespace_id is nil' do
        let(:new_root_namespace_id) { nil }

        let!(:connection_with_old_traversal_ids) do
          old_traversal_ids = [999, 888, 777] # Wrong traversal_ids
          connection = build(:project_to_security_attribute,
            project: project_in_new_subgroup,
            security_attribute: security_attribute_new_ns,
            traversal_ids: old_traversal_ids)
          connection.save!(validate: false)
          connection
        end

        it 'skips cleanup but still updates traversal_ids' do
          expect(service).not_to receive(:delete_connections_for_project_batch)

          expect { execute }.to change { connection_with_old_traversal_ids.reload.traversal_ids }
            .from([999, 888, 777]).to(project_in_new_subgroup.namespace.traversal_ids)
        end

        it 'does not delete any connections' do
          expect { execute }.not_to change { Security::ProjectToSecurityAttribute.count }
        end
      end
    end

    context 'when no connections exist for projects' do
      it 'does not raise errors and completes successfully' do
        expect { execute }.not_to change { Security::ProjectToSecurityAttribute.count }
      end
    end
  end
end
