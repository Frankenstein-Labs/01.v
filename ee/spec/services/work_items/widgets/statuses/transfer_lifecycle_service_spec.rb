# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Statuses::TransferLifecycleService, feature_category: :team_planning do
  let_it_be_with_reload(:old_namespace) { create(:group) }
  let_it_be_with_reload(:new_namespace) { create(:group) }
  let(:service) do
    described_class.new(old_root_namespace: old_namespace, new_root_namespace: new_namespace)
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  describe '#execute' do
    context 'when old and new root namespaces are the same' do
      let(:new_namespace) { old_namespace }

      it 'returns early without processing' do
        expect(WorkItems::Statuses::Custom::Lifecycle).not_to receive(:create!)
        service.execute
      end
    end

    context 'when old_root_namespace is nil' do
      let(:old_namespace) { nil }

      it 'returns early without processing' do
        expect(WorkItems::Statuses::Custom::Lifecycle).not_to receive(:create!)
        service.execute
      end
    end

    context 'when new_root_namespace is nil' do
      let(:new_namespace) { nil }

      it 'returns early without processing' do
        expect(WorkItems::Statuses::Custom::Lifecycle).not_to receive(:create!)
        service.execute
      end
    end

    context 'when old_namespace does not have custom lifecycles' do
      it 'returns early without processing' do
        expect(WorkItems::Statuses::Custom::Lifecycle).not_to receive(:create!)
        service.execute
      end
    end

    context 'when old_namespace has a custom lifecycle' do
      let_it_be(:custom_to_do) { create(:work_item_custom_status, :open, namespace: old_namespace) }
      let_it_be(:custom_done) { create(:work_item_custom_status, :closed, namespace: old_namespace) }
      let_it_be(:custom_canceled) { create(:work_item_custom_status, :duplicate, namespace: old_namespace) }
      let_it_be(:custom_in_progress) { create(:work_item_custom_status, :in_progress, namespace: old_namespace) }

      let!(:old_lifecycle) do
        create(:work_item_custom_lifecycle, :for_issues,
          namespace: old_namespace,
          statuses: [custom_to_do, custom_in_progress, custom_done, custom_canceled],
          default_open_status: custom_to_do,
          default_closed_status: custom_done,
          default_duplicate_status: custom_canceled
        )
      end

      it 'creates 4 new statuses and 1 new custom lifecycle' do
        expect { service.execute }
          .to change { new_namespace.statuses.count }.to(4)
          .and change { new_namespace.custom_lifecycles.count }.to(1)
      end

      it "creates the new statuses with the correct attributes" do
        service.execute

        attributes_to_match = [:name, :category, :description, :color, :created_by_id,
          :converted_from_system_defined_status_identifier]

        new_statuses_attributes = new_namespace.reload.statuses.map { |s| s.slice(attributes_to_match) }
        old_statuses_attributes = old_namespace.statuses.map { |s| s.slice(attributes_to_match) }

        expect(new_statuses_attributes).to match_array(old_statuses_attributes)
      end

      it "created lifecycle with correct default statuses" do
        service.execute
        new_lifecycle = new_namespace.reload.lifecycles.last

        expect(new_lifecycle.default_open_status.name).to eq(custom_to_do.name)
        expect(new_lifecycle.default_closed_status.name).to eq(custom_done.name)
        expect(new_lifecycle.default_duplicate_status.name).to eq(custom_canceled.name)
      end

      it 'creates a new lifecycle with correct attributes' do
        old_lifecycle = old_namespace.lifecycles.first

        service.execute

        expect(new_namespace.reload.lifecycles.first).to have_attributes(
          name: old_lifecycle.name,
          work_item_types: old_lifecycle.work_item_types,
          created_by_id: old_lifecycle.created_by_id,
          statuses: match_array(new_namespace.statuses)
        )
      end

      it 'wraps the creation in a transaction' do
        expect(ApplicationRecord).to receive(:transaction).and_yield
        service.execute
      end

      context 'when status creation fails' do
        before do
          allow(WorkItems::Statuses::Custom::Status).to receive(:create!)
            .and_raise(ActiveRecord::RecordInvalid)
        end

        it 'rolls back the transaction' do
          expect { service.execute }.to raise_error(ActiveRecord::RecordInvalid)
          expect(WorkItems::Statuses::Custom::Lifecycle).not_to receive(:create!)
        end
      end

      context 'when lifecycle creation fails' do
        before do
          allow(WorkItems::Statuses::Custom::Lifecycle).to receive(:create!)
            .and_raise(ActiveRecord::RecordInvalid)
        end

        it 'rolls back the transaction' do
          expect { service.execute }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      context 'when a matching custom lifecycle already exists in new namespace' do
        let(:custom_to_do) { create(:work_item_custom_status, :open, namespace: new_namespace) }
        let(:custom_done) { create(:work_item_custom_status, :closed, namespace: new_namespace) }
        let(:custom_canceled) { create(:work_item_custom_status, :duplicate, namespace: new_namespace) }
        let!(:lifecycle) do
          create(:work_item_custom_lifecycle, :for_issues,
            namespace: new_namespace,
            statuses: [custom_to_do, custom_done, custom_canceled],
            default_open_status: custom_to_do,
            default_closed_status: custom_done,
            default_duplicate_status: custom_canceled
          )
        end

        it 'skips creating a new lifecycle' do
          expect(WorkItems::Statuses::Custom::Status).not_to receive(:create!)
          expect(WorkItems::Statuses::Custom::Lifecycle).not_to receive(:create!)
          service.execute
        end
      end
    end

    context "when old_namespace has multiple custom lifecycles" do
      let_it_be(:custom_to_do) { create(:work_item_custom_status, :open, namespace: old_namespace) }
      let_it_be(:custom_done) { create(:work_item_custom_status, :closed, namespace: old_namespace) }
      let_it_be(:custom_canceled) { create(:work_item_custom_status, :duplicate, namespace: old_namespace) }
      let_it_be(:custom_in_progress) { create(:work_item_custom_status, :in_progress, namespace: old_namespace) }

      let!(:old_lifecycle1) do
        create(:work_item_custom_lifecycle, :for_issues,
          namespace: old_namespace,
          statuses: [custom_to_do, custom_in_progress, custom_done, custom_canceled],
          default_open_status: custom_to_do,
          default_closed_status: custom_done,
          default_duplicate_status: custom_canceled
        )
      end

      let!(:old_lifecycle2) do
        create(:work_item_custom_lifecycle, :for_tasks,
          namespace: old_namespace,
          statuses: [custom_to_do, custom_in_progress, custom_done, custom_canceled],
          default_open_status: custom_to_do,
          default_closed_status: custom_done,
          default_duplicate_status: custom_canceled
        )
      end

      it 'creates 4 new statuses(does not recreate the statuses) and 2 new custom lifecycles' do
        expect { service.execute }
          .to change { new_namespace.statuses.count }.to(4)
          .and change { new_namespace.custom_lifecycles.count }.to(2)
      end

      it 'creates a new lifecycles with correct attributes' do
        old_lifecycles = old_namespace.lifecycles

        service.execute

        old_lifecycles.each do |old_lifecycle|
          new_lifecycle = new_namespace.lifecycles.find_by(name: old_lifecycle.name)

          expect(new_lifecycle).to have_attributes(
            name: old_lifecycle.name,
            work_item_types: old_lifecycle.work_item_types,
            created_by_id: old_lifecycle.created_by_id,
            statuses: match_array(new_namespace.statuses)
          )
        end
      end
    end
  end
end
