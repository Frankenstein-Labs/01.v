# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Statuses::UpdateService, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item_type) { build(:work_item_system_defined_type, :task) }

  let(:status_lifecycle) { build(:work_item_system_defined_lifecycle) }
  let(:status) { build(:work_item_system_defined_status, :to_do) }
  let(:new_status) { build(:work_item_system_defined_status, :done) }
  let(:work_item) { create(:work_item, :task, project: project) }

  subject(:service) { described_class.new(work_item, user, new_status) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  def work_item_status
    work_item.reload.current_status&.status
  end

  describe '#initialize' do
    context 'when work_item is an Issue' do
      let(:issue) { create(:issue) }

      it 'converts the issue to a work item' do
        service = described_class.new(issue, user, status)
        expect(service.send(:work_item)).to be_an_instance_of(WorkItem)
      end
    end

    context 'when work_item is already a WorkItem' do
      it 'uses the work item directly' do
        service = described_class.new(work_item, user, status)
        expect(service.send(:work_item)).to be_an_instance_of(WorkItem)
      end
    end
  end

  describe '#execute' do
    context 'when status is nil' do
      let(:service) { described_class.new(work_item, user, nil) }

      it 'returns nil without updating status' do
        expect(service.execute).to be_nil
        expect(work_item_status).to be_nil
      end
    end

    context 'when work item type does not support statuses' do
      let(:work_item) { create(:work_item, :incident, project: project) }

      it 'returns nil without updating status' do
        expect(service.execute).to be_nil
        expect(work_item_status).to be_nil
      end
    end

    context 'when status has incorect type' do
      let(:new_status) { ::WorkItems::Statuses::SystemDefined::Status.new(id: 99, name: 'Invalid') }

      it 'returns nil without updating status' do
        expect(service.execute).to be_nil
        expect(work_item_status).to be_nil
      end
    end

    context 'when work item already has the same status' do
      let!(:current_status) { create(:work_item_current_status, work_item: work_item, status: new_status) }

      it 'returns nil without updating status' do
        expect(service.execute).to be_nil
        expect(work_item_status).to eq(new_status)
      end
    end

    context 'when all conditions are met' do
      it_behaves_like 'internal event tracking' do
        let(:event) { 'change_work_item_status_value' }
        let(:category) { described_class.name }
        let(:namespace) { group }
        let(:label) { new_status.category.to_s }

        subject { described_class.new(work_item, user, new_status).execute }
      end

      context 'when given status is :default' do
        let(:new_status) { :default }
        let(:work_item) do
          create(:work_item, :task, :closed, project: project, duplicated_to: create(:work_item, project: project))
        end

        it 'sets the default status' do
          expect { service.execute }.to change { WorkItems::Statuses::CurrentStatus.count }.by(1)

          expect(work_item_status).to eq(build(:work_item_system_defined_status, :duplicate))
        end
      end

      context 'when work item has no current status' do
        it 'creates a new status record with correct status' do
          expect { service.execute }.to change { WorkItems::Statuses::CurrentStatus.count }.by(1)

          expect(work_item_status).to eq(new_status)
        end
      end

      context 'when work item has an existing status' do
        let!(:current_status) { create(:work_item_current_status, work_item: work_item, status: status) }

        it 'udpates status record with correct status' do
          expect { service.execute }.not_to change { WorkItems::Statuses::CurrentStatus.count }

          expect(work_item_status).to eq(new_status)
        end
      end

      context 'when using custom lifecycle' do
        let!(:status_lifecycle) do
          create(:work_item_custom_lifecycle, namespace: group).tap do |lifecycle|
            create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type)
          end
        end

        let(:status) { status_lifecycle.default_open_status }
        let(:new_status) { status_lifecycle.default_closed_status }

        it 'updates the status and creates a system note' do
          expect(::SystemNotes::IssuablesService).to receive_message_chain(:new, :change_work_item_status)
            .with(new_status)

          service.execute

          expect(work_item_status).to eq(new_status)
        end
      end

      context 'when the caller passed an Issue' do
        let_it_be_with_reload(:issue) { create(:issue, project: project) }

        subject(:service) { described_class.new(issue, user, new_status) }

        before do
          create(:work_item_current_status, work_item_id: issue.id, status: status)
          issue.association(:current_status).reset
        end

        it "resets the caller's stale current_status association so it reads the new value" do
          expect { service.execute }
            .to change { issue.status_with_fallback }.from(status).to(new_status)
        end
      end

      context 'when the caller passed a WorkItem' do
        let!(:current_status) { create(:work_item_current_status, work_item: work_item, status: status) }

        it "does not reset the caller's association, preserving previous_changes" do
          service.execute

          expect(work_item.current_status.previous_changes)
            .to include('system_defined_status_id')
        end
      end

      context 'when creating system note' do
        context 'when status has not changed' do
          before do
            work_item.build_current_status(status: new_status).save!
          end

          it 'does not create a system note' do
            expect(::SystemNotes::IssuablesService).not_to receive(:new)

            service.execute
          end
        end

        context 'when all conditions are met for system note creation' do
          let(:system_notes_service) { instance_double(::SystemNotes::IssuablesService) }

          it 'creates a system note' do
            expect(::SystemNotes::IssuablesService).to receive(:new).with(
              noteable: work_item,
              container: work_item.namespace,
              author: user
            ).and_return(system_notes_service)
            expect(system_notes_service).to receive(:change_work_item_status).with(new_status)

            service.execute
          end
        end
      end
    end
  end
end
