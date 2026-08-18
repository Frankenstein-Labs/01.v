# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::EpicIssues::UpdateService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:guest) { create(:user) }
    let_it_be(:group) { create(:group, :public, guests: guest) }
    let_it_be(:project) { create(:project, :public, group: create(:group, :public), guests: guest) }
    let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:issue1) { create(:issue, project: project) }
    let_it_be(:issue2) { create(:issue, project: project) }
    let_it_be_with_reload(:epic_issue1) { create(:epic_issue, epic: epic, issue: issue1) }
    let_it_be_with_reload(:epic_issue2) { create(:epic_issue, epic: epic, issue: issue2) }

    let(:params) { { move_after_id: epic_issue2.id } }
    let(:user) { guest }

    subject(:execute) { described_class.new(epic_issue1, user, params).execute }

    context 'when epics feature is disabled' do
      it 'returns an error' do
        is_expected.to eq(
          message: 'No matching work item found. Make sure that you are adding a valid work item ID.',
          status: :error,
          http_status: 404
        )
      end
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when parent link does not exist' do
        before do
          allow(epic_issue1).to receive(:work_item_parent_link).and_return(nil)
        end

        it 'returns an error' do
          is_expected.to eq(message: 'No parent link found', status: :error, http_status: 404)
        end
      end

      context 'when parent link exists' do
        it 'delegates to WorkItems::ParentLinks::ReorderService' do
          expect(::WorkItems::ParentLinks::ReorderService).to receive(:new)
            .with(epic.work_item, user, hash_including(
              target_issuable: issue1,
              adjacent_work_item: issue2,
              relative_position: 'BEFORE'
            ))
            .and_call_original

          execute
        end

        it 'returns success' do
          is_expected.to include(status: :success)
        end

        context 'with move_before_id' do
          let(:params) { { move_before_id: epic_issue2.id } }

          it 'passes AFTER position' do
            expect(::WorkItems::ParentLinks::ReorderService).to receive(:new)
              .with(epic.work_item, user, hash_including(relative_position: 'AFTER'))
              .and_call_original

            execute
          end
        end

        context 'when adjacent epic_issue is not found' do
          let(:params) { { move_after_id: non_existing_record_id } }

          it 'returns an error' do
            is_expected.to eq(message: 'No parent link found', status: :error, http_status: 404)
          end
        end

        context 'when no move params are provided' do
          let(:params) { {} }

          it 'calls reorder service with nil adjacent_work_item and position' do
            expect(::WorkItems::ParentLinks::ReorderService).to receive(:new)
              .with(epic.work_item, user, hash_including(
                target_issuable: issue1,
                adjacent_work_item: nil,
                relative_position: nil
              ))
              .and_call_original

            execute
          end
        end

        context 'when reorder service fails' do
          before do
            allow_next_instance_of(::WorkItems::ParentLinks::ReorderService) do |service|
              allow(service).to receive(:execute).and_return({ status: :error, message: 'reorder failed' })
            end
          end

          it 'returns the error' do
            is_expected.to eq(status: :error, message: 'reorder failed')
          end
        end

        context 'when reordering epic issues' do
          let(:params) { { move_before_id: epic_issue2.id } }

          let!(:issue3) { create(:issue, project: project) }
          let!(:issue4) { create(:issue, project: project) }
          let!(:epic_issue3) { create(:epic_issue, epic: epic, issue: issue3, relative_position: 1200) }
          let!(:epic_issue4) { create(:epic_issue, epic: epic, issue: issue4, relative_position: 2000) }

          let(:parent_link1) { epic_issue1.work_item_parent_link }
          let(:parent_link2) { epic_issue2.work_item_parent_link }
          let(:parent_link3) { epic_issue3.work_item_parent_link }
          let(:parent_link4) { epic_issue4.work_item_parent_link }

          before do
            epic_issue1.update_attribute(:relative_position, 3)
            epic_issue2.update_attribute(:relative_position, 600)
            parent_link1.update_attribute(:relative_position, 3)
            parent_link2.update_attribute(:relative_position, 600)
            parent_link3.update_attribute(:relative_position, 1200)
            parent_link4.update_attribute(:relative_position, 2000)
          end

          it 'orders epic issues and parent links correctly' do
            execute

            expect(epic.epic_issues.order('relative_position, id'))
              .to eq([epic_issue2, epic_issue1, epic_issue3, epic_issue4])
            expect(WorkItems::ParentLink.where(work_item_parent: epic.work_item).order('relative_position, id'))
              .to eq([parent_link2, parent_link1, parent_link3, parent_link4])
          end
        end
      end
    end
  end
end
