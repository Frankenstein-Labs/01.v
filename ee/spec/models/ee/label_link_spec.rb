# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LabelLink, feature_category: :global_search do
  describe 'callback' do
    describe 'before_save' do
      describe '#rewrite_epic_type' do
        let_it_be(:label) { create(:label) }
        let_it_be(:issue) { create(:issue) }
        let_it_be(:epic) { create(:epic) }

        context 'when creating a label link with Epic target_type' do
          it 'rewrites target_type from Epic to Issue' do
            label_link = build(:label_link, target_type: 'Epic', target_id: epic.id, label: label)

            expect { label_link.save! }.to change { label_link.target_type }.from('Epic').to('Issue')
              .and change { label_link.target_id }.from(epic.id).to(epic.issue_id)
          end
        end

        context 'when updating an existing label link' do
          let_it_be_with_reload(:label_link) { create(:label_link, target: issue, label: label) }

          it 'does not rewrite target_type on update' do
            label_link.target_type = 'Epic'
            label_link.target_id = epic.id

            label_link.save!

            expect(label_link.reload.target_type).to eq('Epic')
            expect(label_link.reload.target_id).to eq(epic.id)
          end
        end

        context 'when target_type is not Epic' do
          it 'does not modify target_type for Issue' do
            label_link = build(:label_link, target: issue, label: label)

            label_link.save!

            expect(label_link.reload.target_type).to eq('Issue')
            expect(label_link.reload.target_id).to eq(issue.id)
          end
        end
      end
    end

    describe 'after_destroy' do
      let_it_be_with_reload(:label) { create(:label) }
      let_it_be(:label2) { create(:label) }

      context 'for issues' do
        let_it_be(:issue) { create(:labeled_issue, labels: [label]) }
        let_it_be(:issue2) { create(:labeled_issue, labels: [label]) }
        let_it_be(:issue3) { create(:labeled_issue, labels: [label2]) }

        it 'synchronizes elasticsearch only for issues which have deleted label attached' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(issue).once
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(issue2).once
          label.destroy!
        end
      end

      context 'for epics' do
        let_it_be(:epic) { create(:labeled_epic, labels: [label]) }
        let_it_be(:epic2) { create(:labeled_issue, labels: [label]) }
        let_it_be(:epic3) { create(:labeled_issue, labels: [label2]) }

        it 'synchronizes elasticsearch only for epics which have deleted label attached' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(Issue.find(epic.issue_id)).once
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(epic2).once
          label.destroy!
        end
      end

      context 'for merge requests' do
        let_it_be(:merge_request) { create(:labeled_merge_request, labels: [label]) }
        let_it_be(:merge_request2) { create(:labeled_merge_request, labels: [label]) }
        let_it_be(:merge_request3) { create(:labeled_merge_request, labels: [label2]) }

        it 'synchronizes elasticsearch only for merge requests which have deleted label attached' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(merge_request).once
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(merge_request2).once
          label.destroy!
        end
      end

      context 'for work items' do
        let_it_be(:work_item) { create(:work_item, labels: [label]) }
        let_it_be(:work_item2) { create(:work_item, labels: [label]) }
        let_it_be(:work_item3) { create(:work_item, labels: [label2]) }

        it 'synchronizes elasticsearch for work items which have deleted label attached' do
          # WorkItems are stored as Issues in the database due to inheritance,
          # so the callback receives Issue objects, not WorkItem objects
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).twice do |object|
            expect(object.class).to eq(Issue)
            expect([work_item.id, work_item2.id]).to include(object.id)
          end
          label.destroy!
        end
      end
    end
  end

  describe '.by_target_for_exists_query' do
    let_it_be(:label1) { create(:label) }
    let_it_be(:label2) { create(:label) }
    let_it_be(:label3) { create(:label) }

    context 'when target_type is Epic' do
      let_it_be(:epic1) { create(:labeled_epic, labels: [label1, label2]) }
      let_it_be(:epic2) { create(:labeled_epic, labels: [label1]) }
      let_it_be(:epic3) { create(:labeled_epic, labels: [label3]) }

      context 'with issue_id column' do
        subject(:query) do
          Epic.where(described_class.by_target_for_exists_query('Epic', Epic.arel_table['issue_id'],
            label_ids).arel.exists)
        end

        context 'without label_ids filter' do
          let(:label_ids) { nil }

          it 'returns epics with any labels' do
            expect(query.pluck(:id)).to match_array([epic1.id, epic2.id, epic3.id])
          end
        end

        context 'with label_ids filter' do
          let(:label_ids) { [label1.id] }

          it 'filters epics by specific label_ids' do
            expect(query.pluck(:id)).to match_array([epic1.id, epic2.id])
          end
        end
      end

      context 'with id column' do
        subject(:query) do
          Epic.where(described_class.by_target_for_exists_query('Epic', Epic.arel_table['id'], [label1.id]).arel.exists)
        end

        it 'rewrites the arel_join_column to use issue_id' do
          expect(query.pluck(:id)).to match_array([epic1.id, epic2.id])
        end
      end
    end

    context 'when target_type is Issue' do
      let_it_be(:issue1) { create(:labeled_issue, labels: [label1, label2]) }
      let_it_be(:issue2) { create(:labeled_issue, labels: [label1]) }
      let_it_be(:issue3) { create(:labeled_issue, labels: [label3]) }

      subject(:query) do
        Issue.where(described_class.by_target_for_exists_query('Issue', Issue.arel_table[:id], label_ids).arel.exists)
      end

      context 'without label_ids filter' do
        let(:label_ids) { nil }

        it 'returns issues with any labels' do
          expect(query.pluck(:id)).to match_array([issue1.id, issue2.id, issue3.id])
        end
      end

      context 'with label_ids filter' do
        let(:label_ids) { [label1.id] }

        it 'filters issues by specific label_ids' do
          expect(query.pluck(:id)).to match_array([issue1.id, issue2.id])
        end
      end
    end
  end
end
