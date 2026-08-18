# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatuses::AncestorsUpdateService, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup1) { create(:group, parent: root_group) }
  let_it_be(:subgroup2) { create(:group, parent: subgroup1) }
  let_it_be(:project) { create(:project, namespace: subgroup2) }
  let_it_be(:number_of_groups) { 3 }

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object and calls `execute`' do
      described_class.execute(nil)

      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    context 'when diffs are not provided' do
      context 'when diffs is nil' do
        let(:diffs_with_metadata) { nil }

        subject(:namespace_update_service) { described_class.execute(diffs_with_metadata) }

        it 'does not change the db' do
          expect { namespace_update_service }
            .to not_change { Security::AnalyzerNamespaceStatus.count }.from(0)
        end
      end

      context 'when diffs_with_metadata are an empty hash' do
        let(:diffs_with_metadata) { {} }

        subject(:namespace_update_service) { described_class.execute(diffs_with_metadata) }

        it 'does not change the db' do
          expect { namespace_update_service }
            .to not_change { Security::AnalyzerNamespaceStatus.count }.from(0)
        end
      end

      context 'when metadata exists' do
        let(:diffs_with_metadata) { { namespace_id: non_existing_record_id, traversal_ids: [1, 2, 3] } }

        subject(:namespace_update_service) { described_class.execute(diffs_with_metadata) }

        it 'does not change the db' do
          expect { namespace_update_service }
            .to not_change { Security::AnalyzerNamespaceStatus.count }.from(0)
        end
      end
    end

    context 'when metadata is not provided' do
      context 'when metadata is nil' do
        let(:diffs_with_metadata) { { diff: { sast: { "success" => 2, "failed" => 1 } } } }

        subject(:namespace_update_service) { described_class.execute(diffs_with_metadata) }

        it 'does not change the db' do
          expect { namespace_update_service }
            .to not_change { Security::AnalyzerNamespaceStatus.count }.from(0)
        end
      end

      context 'when namespace_id is nil' do
        let(:diffs_with_metadata) { { diff: { sast: { "success" => 2, "failed" => 1 } }, traversal_ids: [1, 2, 3] } }

        subject(:namespace_update_service) { described_class.execute(diffs_with_metadata) }

        it 'does not change the db' do
          expect { namespace_update_service }
            .to not_change { Security::AnalyzerNamespaceStatus.count }.from(0)
        end
      end

      context 'when traversal_ids are nil' do
        let(:diffs_with_metadata) { { diff: { sast: { "success" => 2, "failed" => 1 } }, namespace_id: 1 } }

        subject(:namespace_update_service) { described_class.execute(diffs_with_metadata) }

        it 'does not change the db' do
          expect { namespace_update_service }
            .to not_change { Security::AnalyzerNamespaceStatus.count }.from(0)
        end
      end
    end

    context 'when diffs_with_metadata are provided' do
      let(:diffs_with_metadata) do
        {
          namespace_id: subgroup2.id,
          traversal_ids: subgroup2.traversal_ids,
          diff: {
            sast: { "success" => 2, "failed" => 1 },
            dast: { "success" => 1, "failed" => 2 }
          }
        }
      end

      subject(:namespace_update_service) { described_class.execute(diffs_with_metadata) }

      context 'when there are no statistics in the table' do
        it 'inserts new rows to the table' do
          expect { namespace_update_service }.to change { Security::AnalyzerNamespaceStatus.count }
            .from(0).to(number_of_groups * diffs_with_metadata[:diff].keys.length)

          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: root_group.id, analyzer_type: "sast")
            .attributes).to include({ "success" => 2, "failure" => 1 })
          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: root_group.id, analyzer_type: "dast")
            .attributes).to include({ "success" => 1, "failure" => 2 })

          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: subgroup1.id, analyzer_type: "sast")
            .attributes).to include({ "success" => 2, "failure" => 1 })
          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: subgroup1.id, analyzer_type: "dast")
            .attributes).to include({ "success" => 1, "failure" => 2 })

          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: subgroup2.id, analyzer_type: "sast")
            .attributes).to include({ "success" => 2, "failure" => 1 })
          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: subgroup2.id, analyzer_type: "dast")
            .attributes).to include({ "success" => 1, "failure" => 2 })
        end
      end

      context 'when all statistics exists in the table' do
        let_it_be(:subgroup2_sast_status) do
          create(:analyzer_namespace_status, namespace: subgroup2, analyzer_type: "sast", success: 1, failure: 0)
        end

        let_it_be(:subgroup2_dast_status) do
          create(:analyzer_namespace_status, namespace: subgroup2, analyzer_type: "dast", success: 0, failure: 3)
        end

        let_it_be(:subgroup1_sast_status) do
          create(:analyzer_namespace_status, namespace: subgroup1, analyzer_type: "sast", success: 1, failure: 2)
        end

        let_it_be(:subgroup1_dast_status) do
          create(:analyzer_namespace_status, namespace: subgroup1, analyzer_type: "dast", success: 3, failure: 3)
        end

        let_it_be(:root_group_sast_status) do
          create(:analyzer_namespace_status, namespace: root_group, analyzer_type: "sast", success: 3, failure: 4)
        end

        let_it_be(:root_group_dast_status) do
          create(:analyzer_namespace_status, namespace: root_group, analyzer_type: "dast", success: 4, failure: 3)
        end

        it 'upserts new counts to the table' do
          expect { namespace_update_service }.to not_change { Security::AnalyzerNamespaceStatus.count }
            .from(number_of_groups * diffs_with_metadata[:diff].keys.length)

          expect(subgroup2_sast_status.reload.attributes).to include({ "success" => 3, "failure" => 1 })
          expect(subgroup2_dast_status.reload.attributes).to include({ "success" => 1, "failure" => 5 })
          expect(subgroup1_sast_status.reload.attributes).to include({ "success" => 3, "failure" => 3 })
          expect(subgroup1_dast_status.reload.attributes).to include({ "success" => 4, "failure" => 5 })
          expect(root_group_sast_status.reload.attributes).to include({ "success" => 5, "failure" => 5 })
          expect(root_group_dast_status.reload.attributes).to include({ "success" => 5, "failure" => 5 })
        end

        context 'when projects have stale transitions' do
          let_it_be(:subgroup2_dependency_scanning_status) do
            create(:analyzer_namespace_status, namespace: subgroup2,
              analyzer_type: "dependency_scanning", success: 0, stale: 3)
          end

          let_it_be(:subgroup1_dependency_scanning_status) do
            create(:analyzer_namespace_status, namespace: subgroup1,
              analyzer_type: "dependency_scanning", success: 0, stale: 3)
          end

          let_it_be(:root_group_dependency_scanning_status) do
            create(:analyzer_namespace_status, namespace: root_group,
              analyzer_type: "dependency_scanning", success: 0, stale: 3)
          end

          let(:diffs_with_metadata) do
            {
              namespace_id: subgroup2.id,
              traversal_ids: subgroup2.traversal_ids,
              diff: {
                sast: { "stale" => 1, "success" => -1 },
                dast: { "stale" => 1, "failed" => -1 },
                dependency_scanning: { "success" => 1, "stale" => -1 }
              }
            }
          end

          it 'correctly upserts stale transitions across all ancestor groups' do
            namespace_update_service

            expect(subgroup2_sast_status.reload.attributes).to include({ "success" => 0, "failure" => 0, "stale" => 1 })
            expect(subgroup2_dast_status.reload.attributes).to include({ "success" => 0, "failure" => 2, "stale" => 1 })
            expect(subgroup2_dependency_scanning_status.reload.attributes).to include({ "success" => 1, "stale" => 2 })

            expect(subgroup1_sast_status.reload.attributes).to include({ "success" => 0, "failure" => 2, "stale" => 1 })
            expect(subgroup1_dast_status.reload.attributes).to include({ "success" => 3, "failure" => 2, "stale" => 1 })
            expect(subgroup1_dependency_scanning_status.reload.attributes).to include({ "success" => 1, "stale" => 2 })

            expect(root_group_sast_status.reload.attributes)
              .to include({ "success" => 2, "failure" => 4, "stale" => 1 })
            expect(root_group_dast_status.reload.attributes)
              .to include({ "success" => 4, "failure" => 2, "stale" => 1 })
            expect(root_group_dependency_scanning_status.reload.attributes)
              .to include({ "success" => 1, "failure" => 0, "stale" => 2 })
          end
        end
      end

      context 'when some statistics exists in the table' do
        let_it_be(:root_group_sast_status) do
          create(:analyzer_namespace_status, namespace: root_group, analyzer_type: "sast", success: 1, failure: 1)
        end

        let_it_be(:subgroup1_dast_status) do
          create(:analyzer_namespace_status, namespace: subgroup1, analyzer_type: "dast", success: 3, failure: 1)
        end

        it 'inserts missing statistics and upserts new counts to the table' do
          expect { namespace_update_service }.to change { Security::AnalyzerNamespaceStatus.count }.from(2)
            .to(number_of_groups * diffs_with_metadata[:diff].keys.length)

          expect(root_group_sast_status.reload.attributes).to include({ "success" => 3, "failure" => 2 })
          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: root_group.id, analyzer_type: "dast")
            .attributes).to include({ "success" => 1, "failure" => 2 })
          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: subgroup1.id, analyzer_type: "sast")
            .attributes).to include({ "success" => 2, "failure" => 1 })

          expect(subgroup1_dast_status.reload.attributes).to include({ "success" => 4, "failure" => 3 })
          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: subgroup2.id, analyzer_type: "sast")
            .attributes).to include({ "success" => 2, "failure" => 1 })
          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: subgroup2.id, analyzer_type: "dast")
            .attributes).to include({ "success" => 1, "failure" => 2 })
        end
      end

      context 'when diffs_with_metadata contain entries with zero success and zero failure' do
        let(:diffs_with_metadata) do
          {
            namespace_id: subgroup2.id,
            traversal_ids: subgroup2.traversal_ids,
            diff: {
              sast: { "success" => 2, "failed" => 1 },
              dast: { "success" => 0, "failed" => 0 },
              secret_detection: { "success" => 1, "failed" => 1 }
            }
          }
        end

        it 'ignores entries with zero success and zero failure' do
          expect { namespace_update_service }.to change { Security::AnalyzerNamespaceStatus.count }.from(0).to(6)

          expect(Security::AnalyzerNamespaceStatus.where(analyzer_type: "dast").count).to eq(0)
        end
      end

      context 'when diffs contain entries with zero success and zero failure but non-zero stale' do
        let(:diffs_with_metadata) do
          {
            namespace_id: subgroup2.id,
            traversal_ids: subgroup2.traversal_ids,
            diff: {
              sast: { "success" => 0, "failed" => 0, "stale" => 1 }
            }
          }
        end

        it 'processes entries with non-zero stale count' do
          expect { namespace_update_service }.to change { Security::AnalyzerNamespaceStatus.count }
            .from(0).to(number_of_groups)

          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: subgroup2.id, analyzer_type: "sast")
            .attributes).to include({ "success" => 0, "failure" => 0, "stale" => 1 })
          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: subgroup1.id, analyzer_type: "sast")
            .attributes).to include({ "success" => 0, "failure" => 0, "stale" => 1 })
          expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: root_group.id, analyzer_type: "sast")
            .attributes).to include({ "success" => 0, "failure" => 0, "stale" => 1 })
        end
      end
    end
  end
end
