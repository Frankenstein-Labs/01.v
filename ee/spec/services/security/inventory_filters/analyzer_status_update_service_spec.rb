# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::InventoryFilters::AnalyzerStatusUpdateService, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: group) }
  let_it_be(:project2) { create(:project, namespace: group) }
  let_it_be(:namespace1) { project1.namespace }
  let_it_be(:namespace2) { project2.namespace }

  let(:projects) { [project1, project2] }
  let(:analyzer_statuses) { [] }

  subject(:service) { described_class.new(projects, analyzer_statuses) }

  describe '.execute' do
    let(:analyzer_statuses) do
      [
        {
          project_id: project1.id,
          analyzer_type: :secret_detection_secret_push_protection,
          status: :success,
          archived: false
        },
        {
          project_id: project2.id,
          analyzer_type: :container_scanning,
          status: :not_configured,
          archived: false
        }
      ]
    end

    it 'creates a new instance and calls execute' do
      instance = instance_double(described_class)
      expect(described_class).to receive(:new).with(projects, analyzer_statuses).and_return(instance)
      expect(instance).to receive(:execute)

      described_class.execute(projects, analyzer_statuses)
    end
  end

  describe '#execute' do
    context 'when projects is empty' do
      let(:projects) { [] }
      let(:analyzer_statuses) do
        [
          {
            project_id: project1.id,
            analyzer_type: :sast,
            status: :success,
            archived: false
          }
        ]
      end

      it 'returns early' do
        expect { service.execute }.not_to change { Security::InventoryFilter.count }
      end
    end

    context 'when project is nil' do
      let(:projects) { [nil] }
      let(:analyzer_statuses) do
        [
          {
            project_id: nil,
            traversal_ids: [],
            analyzer_type: :sast,
            status: :not_configured,
            archived: false
          }
        ]
      end

      it 'returns early' do
        expect { service.execute }.not_to change { Security::InventoryFilter.count }
      end
    end

    context 'when analyzer_statuses is empty' do
      let(:analyzer_statuses) { [] }

      it 'returns early' do
        expect { service.execute }.not_to change { Security::InventoryFilter.count }
      end
    end

    context 'when analyzer_statuses is nil' do
      let(:analyzer_statuses) { nil }

      it 'returns early' do
        expect { service.execute }.not_to change { Security::InventoryFilter.count }
      end
    end

    context 'when analyzer_statuses only contains a non-inventory analyzer type' do
      let(:analyzer_statuses) do
        [
          {
            project_id: project1.id,
            traversal_ids: namespace1.traversal_ids,
            analyzer_type: :dependency_scanning_post_processing,
            status: :success,
            archived: false
          }
        ]
      end

      it 'does not create an inventory filter row', :aggregate_failures do
        expect(Security::InventoryFilter).not_to receive(:upsert_all)
        expect { service.execute }.not_to change { Security::InventoryFilter.count }
      end
    end

    context 'when analyzer_statuses mixes inventory and non-inventory analyzer types' do
      let(:projects) { [project1] }
      let(:analyzer_statuses) do
        [
          {
            project_id: project1.id,
            traversal_ids: namespace1.traversal_ids,
            analyzer_type: :dependency_scanning_post_processing,
            status: :success,
            archived: false
          },
          {
            project_id: project1.id,
            traversal_ids: namespace1.traversal_ids,
            analyzer_type: :sast,
            status: :success,
            archived: false
          }
        ]
      end

      it 'only writes the inventory-relevant analyzer column', :aggregate_failures do
        expect { service.execute }.to change { Security::InventoryFilter.count }.by(1)

        inventory_filter = Security::InventoryFilter.find_by(project: project1)
        expect(inventory_filter).to have_attributes(sast: "success")
      end
    end

    context 'when project_id in analyzer_statuses does not match any project' do
      let(:analyzer_statuses) do
        [
          {
            project_id: non_existing_record_id,
            analyzer_type: :secret_detection,
            status: :success,
            archived: false
          }
        ]
      end

      it 'skips records with invalid project_id' do
        expect { service.execute }.not_to change { Security::InventoryFilter.count }
      end
    end

    context 'with single project' do
      let(:projects) { [project1] }

      context 'with standard analyzer statuses' do
        let(:analyzer_statuses) do
          [
            {
              project_id: project1.id,
              traversal_ids: namespace1.traversal_ids,
              analyzer_type: :sast,
              status: :success,
              archived: false
            },
            {
              project_id: project1.id,
              traversal_ids: namespace1.traversal_ids,
              analyzer_type: :dependency_scanning,
              status: :failed,
              archived: false
            }
          ]
        end

        it 'creates or updates inventory filters record with single upsert' do
          expect(Security::InventoryFilter).to receive(:upsert_all).once.and_call_original

          expect { service.execute }.to change { Security::InventoryFilter.count }.by(1)

          inventory_filter = Security::InventoryFilter.find_by(project: project1)
          expect(inventory_filter).to have_attributes(
            project_id: project1.id,
            project_name: project1.name,
            traversal_ids: namespace1.traversal_ids,
            archived: false,
            sast: "success",
            dependency_scanning: "failed"
          )
        end

        context 'when inventory filter already exists' do
          let!(:existing_filter) do
            create(:security_inventory_filters,
              project: project1,
              archived: true,
              sast: "failed",
              dependency_scanning: "success")
          end

          it 'updates the existing record' do
            expect { service.execute }.not_to change { Security::InventoryFilter.count }

            existing_filter.reload
            expect(existing_filter).to have_attributes(
              sast: "success",
              dependency_scanning: "failed",
              archived: false
            )
          end
        end
      end

      context 'with archived project' do
        let_it_be(:project1) { create(:project, namespace: group, archived: true) }
        let(:analyzer_statuses) do
          [
            {
              project_id: project1.id,
              analyzer_type: :sast,
              status: :success,
              archived: true
            }
          ]
        end

        it 'correctly sets archived status' do
          service.execute

          inventory_filter = Security::InventoryFilter.find_by(project: project1)
          expect(inventory_filter.archived).to be(true)
        end
      end
    end

    context 'with multiple projects' do
      context 'with paired analyzer statuses' do
        let(:analyzer_statuses) do
          [
            {
              project_id: project1.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :success,
              archived: false
            },
            {
              project_id: project1.id,
              analyzer_type: :secret_detection,
              status: :failed,
              archived: false
            },
            {
              project_id: project2.id,
              analyzer_type: :container_scanning_for_registry,
              status: :success,
              archived: false
            },
            {
              project_id: project2.id,
              analyzer_type: :container_scanning,
              status: :not_configured,
              archived: false
            }
          ]
        end

        it 'creates inventory filters records for each project with grouped upserts' do
          # Should perform two separate upserts because we have two groups of columns to update:
          # - project1 has secret_detection_secret_push_protection + secret_detection
          # - project2 has container_scanning_for_registry + container_scanning
          expect(Security::InventoryFilter).to receive(:upsert_all).twice.and_call_original

          expect { service.execute }.to change { Security::InventoryFilter.count }.by(2)

          inventory_filter1 = Security::InventoryFilter.find_by(project: project1)
          expect(inventory_filter1).to have_attributes(
            project_id: project1.id,
            project_name: project1.name,
            traversal_ids: namespace1.traversal_ids,
            archived: false,
            secret_detection_secret_push_protection: "success",
            secret_detection: "failed"
          )

          inventory_filter2 = Security::InventoryFilter.find_by(project: project2)
          expect(inventory_filter2).to have_attributes(
            project_id: project2.id,
            project_name: project2.name,
            traversal_ids: namespace2.traversal_ids,
            archived: false,
            container_scanning_for_registry: "success",
            container_scanning: "not_configured"
          )
        end

        context 'when inventory filter already exists' do
          let!(:existing_filter) do
            create(:security_inventory_filters,
              project: project1,
              secret_detection_secret_push_protection: "failed",
              secret_detection: "not_configured")
          end

          it 'updates the existing record' do
            expect { service.execute }.to change { Security::InventoryFilter.count }.by(1) # Only for project2

            existing_filter.reload
            expect(existing_filter).to have_attributes(
              secret_detection_secret_push_protection: "success",
              secret_detection: "failed"
            )
          end
        end
      end

      context 'with partial analyzer pairs' do
        let(:analyzer_statuses) do
          [
            {
              project_id: project1.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :success,
              archived: false
            },
            {
              project_id: project2.id,
              analyzer_type: :secret_detection,
              status: :success,
              archived: false
            }
          ]
        end

        it 'creates records with only the specified analyzer types' do
          expect(Security::InventoryFilter).to receive(:upsert_all).twice.and_call_original

          service.execute

          inventory_filter1 = Security::InventoryFilter.find_by(project: project1)
          expect(inventory_filter1.secret_detection_secret_push_protection).to eq("success")
          expect(inventory_filter1.secret_detection).to eq("not_configured") # DB default value

          inventory_filter2 = Security::InventoryFilter.find_by(project: project2)
          expect(inventory_filter2.secret_detection).to eq("success")
          expect(inventory_filter2.secret_detection_secret_push_protection).to eq("not_configured") # DB default value
        end
      end

      context 'with mixed analyzer types in the same batch' do
        let(:analyzer_statuses) do
          [
            {
              project_id: project1.id,
              analyzer_type: :secret_detection_secret_push_protection,
              status: :success,
              archived: false
            },
            {
              project_id: project1.id,
              analyzer_type: :secret_detection,
              status: :failed,
              archived: false
            },
            {
              project_id: project2.id,
              analyzer_type: :container_scanning_for_registry,
              status: :success,
              archived: false
            }
          ]
        end

        it 'handles different sets of analyzer columns correctly' do
          expect(Security::InventoryFilter).to receive(:upsert_all).twice.and_call_original

          service.execute

          inventory_filter1 = Security::InventoryFilter.find_by(project: project1)
          expect(inventory_filter1).to have_attributes(
            secret_detection_secret_push_protection: "success",
            secret_detection: "failed"
          )

          inventory_filter2 = Security::InventoryFilter.find_by(project: project2)
          expect(inventory_filter2).to have_attributes(
            container_scanning_for_registry: "success",
            container_scanning: "not_configured"
          )
        end
      end

      context 'when preserving existing values not in the update' do
        let!(:existing_filter) do
          create(:security_inventory_filters,
            project: project2,
            container_scanning_for_registry: "failed",
            container_scanning: "success",
            sast: "success")
        end

        let(:analyzer_statuses) do
          [
            {
              project_id: project2.id,
              analyzer_type: :container_scanning_for_registry,
              status: :success,
              archived: false
            }
          ]
        end

        it 'updates only specified fields while preserving others' do
          service.execute

          existing_filter.reload
          expect(existing_filter).to have_attributes(
            container_scanning_for_registry: "success", # Updated
            container_scanning: "success",              # Preserved
            sast: "success"                             # Preserved
          )
        end
      end
    end

    describe 'aggregate booleans recomputation' do
      let(:projects) { [project1] }

      where(:sast_status, :dast_status, :has_scanners, :has_failed_or_warning, :has_stale) do
        [
          [:not_configured, :not_configured, false, false, false],
          [:success,        :not_configured, true,  false, false],
          [:failed,         :not_configured, true,  true,  false],
          [:stale,          :not_configured, true,  false, true],
          [:success,        :failed,         true,  true,  false],
          [:success,        :stale,          true,  false, true],
          [:failed,         :stale,          true,  true,  true]
        ]
      end

      with_them do
        let(:analyzer_statuses) do
          [
            { project_id: project1.id, analyzer_type: :sast, status: sast_status, archived: false },
            { project_id: project1.id, analyzer_type: :dast, status: dast_status, archived: false }
          ]
        end

        it 'recomputes aggregate booleans correctly' do
          service.execute

          expect(project1.reload_security_inventory_filters).to have_attributes(
            has_scanners: has_scanners,
            has_failed_or_warning: has_failed_or_warning,
            has_stale: has_stale
          )
        end
      end

      context 'when failed analyzer is updated to success and no other failures exist' do
        let!(:existing_filter) do
          create(:security_inventory_filters,
            project: project1, sast: :failed, has_scanners: true, has_failed_or_warning: true)
        end

        let(:analyzer_statuses) do
          [{ project_id: project1.id, analyzer_type: :sast, status: :success, archived: false }]
        end

        it 'flips has_failed_or_warning from true to false' do
          expect { service.execute }.to change { existing_filter.reload.has_failed_or_warning }.from(true).to(false)
        end
      end
    end

    context 'when an error occurs during execution' do
      let(:analyzer_statuses) do
        [
          {
            project_id: project1.id,
            analyzer_type: :sast,
            status: :success,
            archived: false
          }
        ]
      end

      before do
        allow(Security::InventoryFilter).to receive(:upsert_all).and_raise(StandardError.new('Database error'))
      end

      it 'catches and tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(an_instance_of(StandardError), project_id: project1.id)

        expect { service.execute }.not_to raise_error
      end
    end
  end
end
