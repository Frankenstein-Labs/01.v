# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Statuses::TransferService, feature_category: :team_planning do
  let_it_be_with_reload(:old_root_namespace) { create(:group) }
  let_it_be_with_reload(:new_root_namespace) { create(:group) }

  subject(:service) do
    described_class.new(old_root_namespace: old_root_namespace, new_root_namespace: new_root_namespace,
      project_namespace_ids: [1, 2])
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  describe '#execute' do
    let(:bulk_status_updater) { instance_double(WorkItems::Widgets::Statuses::BulkStatusUpdater) }

    context 'when old and new root namespaces are the same' do
      let(:new_root_namespace) { old_root_namespace }

      it 'returns early without processing' do
        expect(WorkItems::Widgets::Statuses::BulkStatusUpdater).not_to receive(:new)
        service.execute
      end
    end

    context 'when lifecycles are nil' do
      context "when old root namespace lifecycle is nil" do
        before do
          allow(old_root_namespace).to receive(:lifecycles).and_return(nil)
        end

        it 'returns early without processing' do
          expect(WorkItems::Widgets::Statuses::BulkStatusUpdater).not_to receive(:new)

          service.execute
        end
      end

      context 'when new root namespace lifecycle is nil' do
        before do
          allow(new_root_namespace).to receive(:lifecycles).and_return(nil)
        end

        it 'returns early without processing' do
          expect(WorkItems::Widgets::Statuses::BulkStatusUpdater).not_to receive(:new)

          service.execute
        end
      end
    end

    context 'when old and new root namespaces have the same system default lifecycle' do
      it 'skips processing for the same lifecycle' do
        expect(WorkItems::Widgets::Statuses::BulkStatusUpdater).not_to receive(:new)

        service.execute
      end
    end

    context "when old root namespace has a default lifecycle and the new one has a custom" do
      it 'processes lifecycles and executes bulk status updater' do
        create(:work_item_custom_lifecycle, :for_tasks, namespace: old_root_namespace)

        expect(WorkItems::Widgets::Statuses::BulkStatusUpdater).to receive(:new).and_return(bulk_status_updater)
        expect(bulk_status_updater).to receive(:execute)

        service.execute
      end
    end

    context "when old root namespace has a custom lifecycle and the new one has a sustem defined" do
      it 'processes lifecycles and executes bulk status updater' do
        create(:work_item_custom_lifecycle, :for_tasks, namespace: new_root_namespace)

        expect(WorkItems::Widgets::Statuses::BulkStatusUpdater).to receive(:new).and_return(bulk_status_updater)
        expect(bulk_status_updater).to receive(:execute)

        service.execute
      end
    end

    context 'when both namespaces have custom lifecycles and no matching work_item_type is found' do
      it 'skips processing for the same lifecycle' do
        create(:work_item_custom_lifecycle, namespace: old_root_namespace) do |lifecycle|
          lifecycle.work_item_types |= [build(:work_item_system_defined_type, :issue)]
        end

        create(:work_item_custom_lifecycle, namespace: new_root_namespace) do |lifecycle|
          lifecycle.work_item_types |= [build(:work_item_system_defined_type, :task)]
        end

        expect(WorkItems::Widgets::Statuses::BulkStatusUpdater).not_to receive(:new)

        service.execute
      end
    end

    context 'when both lifecycles are custom and match on work_item_type' do
      it 'processes lifecycles and executes bulk status updater' do
        create(:work_item_custom_lifecycle, :for_tasks, namespace: old_root_namespace)
        create(:work_item_custom_lifecycle, :for_tasks, namespace: new_root_namespace)

        expect(WorkItems::Widgets::Statuses::BulkStatusUpdater).to receive(:new).and_return(bulk_status_updater)
        expect(bulk_status_updater).to receive(:execute)

        service.execute
      end
    end

    context 'with multiple lifecycles' do
      before do
        create(:work_item_custom_lifecycle, :for_tasks, namespace: old_root_namespace)
        create(:work_item_custom_lifecycle, :for_issues, namespace: old_root_namespace)
        create(:work_item_custom_lifecycle, :for_tasks, namespace: new_root_namespace)
        create(:work_item_custom_lifecycle, :for_issues, namespace: new_root_namespace)
      end

      it 'processes lifecycles and executes bulk status updater twice' do
        expect(WorkItems::Widgets::Statuses::BulkStatusUpdater).to receive(:new).and_return(bulk_status_updater).twice
        expect(bulk_status_updater).to receive(:execute).twice

        service.execute
      end
    end
  end
end
