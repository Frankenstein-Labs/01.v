# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::CleanupProjectConnectionsService, feature_category: :security_asset_inventories do
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

  describe '#execute' do
    context 'when request is invalid' do
      context 'when project_ids is empty' do
        let(:project_ids) { [] }

        it 'returns 0 without performing any deletions' do
          expect { execute }.not_to change { Security::ProjectToSecurityAttribute.count }
          expect(execute).to eq(0)
        end
      end

      context 'when project_ids is nil' do
        let(:project_ids) { nil }

        it 'returns 0 without performing any deletions' do
          expect { execute }.not_to change { Security::ProjectToSecurityAttribute.count }
          expect(execute).to eq(0)
        end
      end

      context 'when new_root_namespace_id is nil' do
        let(:new_root_namespace_id) { nil }

        it 'returns 0 without performing any deletions' do
          expect { execute }.not_to change { Security::ProjectToSecurityAttribute.count }
          expect(execute).to eq(0)
        end
      end
    end

    context 'when request is valid' do
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

      it 'deletes only connections with mismatched root namespace for specified projects' do
        expect { execute }.to change { Security::ProjectToSecurityAttribute.count }.by(-2)

        expect(Security::ProjectToSecurityAttribute.exists?(connection_to_delete1.id)).to be_falsey
        expect(Security::ProjectToSecurityAttribute.exists?(connection_to_delete2.id)).to be_falsey
        expect(Security::ProjectToSecurityAttribute.exists?(connection_to_keep1.id)).to be_truthy
        expect(Security::ProjectToSecurityAttribute.exists?(connection_to_keep_outside_scope.id)).to be_truthy
      end

      it 'returns the count of deleted records' do
        expect(execute).to eq(2)
      end

      context 'with batch deleting behavior' do
        before do
          stub_const("#{described_class}::PROJECT_BATCH_SIZE", 1)
          stub_const("#{described_class}::CONNECTIONS_BATCH_SIZE", 1)
        end

        it 'processes connections in batches' do
          expect(service).to receive(:delete_connections_for_project_batch).twice.and_call_original
          # once to get the connection ids, once to get empty array and exit loop
          expect(service).to receive(:ids_to_delete_for_batch).exactly(4).times.and_call_original

          result = execute
          expect(result).to eq(2)
        end
      end
    end

    context 'when no connections need cleanup' do
      it 'does not delete any records' do
        expect { execute }.not_to change { Security::ProjectToSecurityAttribute.count }
        expect(execute).to eq(0)
      end
    end
  end
end
