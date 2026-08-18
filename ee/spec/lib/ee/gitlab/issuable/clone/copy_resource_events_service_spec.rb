# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Issuable::Clone::CopyResourceEventsService, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:project2) { create(:project, :public, group: group) }
  let_it_be(:cadence) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }
  let_it_be_with_reload(:original_issue) { create(:issue, project: project) }
  let_it_be(:new_issue) { create(:issue, project: project2) }

  subject { described_class.new(user, original_issue, new_issue) }

  context 'resource weight events' do
    before do
      create(:resource_weight_event, issue: original_issue, weight: 1)
      create(:resource_weight_event, issue: original_issue, weight: 42)
      create(:resource_weight_event, issue: original_issue, weight: 5)
    end

    it 'creates expected resource weight events' do
      subject.execute

      expect(new_issue.resource_weight_events.map(&:weight)).to contain_exactly(1, 42, 5)
      expect(new_issue.resource_weight_events.map(&:namespace_id)).to match_array([new_issue.namespace_id] * 3)
    end
  end

  context 'resource iteration events' do
    context 'when namespace_id is set to a real value' do
      before do
        create(:resource_iteration_event, issue: original_issue, iteration: cadence, action: :add)
        create(:resource_iteration_event, issue: original_issue, iteration: cadence, action: :remove)
      end

      it 'creates expected resource iteration events' do
        expect { subject.execute }.to change { ResourceIterationEvent.count }.by(2)

        expect(new_issue.resource_iteration_events.map(&:action)).to contain_exactly("add", "remove")
      end
    end

    context 'when namespace_id is defaulted to 0' do
      let_it_be(:another_group) { create(:group) }

      before do
        # Simulate the case when namespace_id is "0"
        # Remove constraint to allow creation of invalid records
        ApplicationRecord.connection.execute("ALTER TABLE resource_iteration_events DROP CONSTRAINT fk_d405f1c11a;")

        create(:resource_iteration_event, issue: original_issue, iteration: cadence, action: :add)
        create(:resource_iteration_event, issue: original_issue, iteration: cadence, action: :remove)

        original_issue.resource_iteration_events.update_all(namespace_id: 0)

        ApplicationRecord.connection.execute("ALTER TABLE ONLY resource_iteration_events
        ADD CONSTRAINT fk_d405f1c11a FOREIGN KEY (namespace_id) REFERENCES namespaces(id) ON DELETE CASCADE NOT VALID;")
      end

      it 'copies namespace_id from even iteration' do
        expect(original_issue.resource_iteration_events.map(&:namespace_id)).to match_array([0, 0])

        expect { subject.execute }.to change { ResourceIterationEvent.count }.by(2)

        namespace_ids = [
          original_issue.resource_iteration_events.first.iteration.group_id,
          original_issue.resource_iteration_events.second.iteration.group_id
        ]
        expect(new_issue.resource_iteration_events.map(&:namespace_id)).to match_array(namespace_ids)
      end
    end
  end

  context 'when a new object is a group entity' do
    context 'when entity is an epic' do
      let_it_be(:group2) { create(:group) }
      let_it_be_with_reload(:new_epic) { create(:epic, :with_synced_work_item, group: group2) }

      subject { described_class.new(user, original_issue, new_epic) }

      context 'when cloning state events' do
        before do
          create(:resource_state_event, issue: original_issue)
        end

        it 'ignores issue_id attribute' do
          milestone = create(:milestone, title: 'milestone', group: group)
          original_issue.update!(milestone: milestone)

          expect do
            subject.execute
          end.to change { ResourceStateEvent.count }.by(1)

          latest_state_event = ResourceStateEvent.last
          expect(latest_state_event).to be_valid
          expect(latest_state_event.issue_id).to be_nil
          expect(latest_state_event.epic).to eq(new_epic)
        end

        it 'sets the correct namespace_id on copied events' do
          expect do
            subject.execute
          end.to change { ResourceStateEvent.count }.by(1)

          latest_state_event = ResourceStateEvent.last
          expect(latest_state_event).to be_valid
          expect(latest_state_event.epic).to eq(new_epic)
          expect(latest_state_event.namespace_id).to eq(new_epic.group_id)
        end
      end

      context 'when cloning label events' do
        let_it_be(:label1) { create(:group_label, group: group) }
        let_it_be(:label2) { create(:group_label, group: group) }
        let_it_be_with_reload(:original_epic) { create(:epic, :with_synced_work_item, group: group) }
        let(:original_epic_work_item) { original_epic.work_item }
        let(:new_epic_work_item) { new_epic.work_item }

        before do
          create(:resource_label_event, issue: original_epic_work_item, label: label1, action: 'add')
          create(:resource_label_event, epic: original_epic, label: label2, action: 'add')
        end

        subject { described_class.new(user, original_epic_work_item, new_epic_work_item) }

        it 'copies resource_label_events, including those associated with the legacy epic', :aggregate_failures do
          expect do
            subject.execute
          end.to change { ResourceLabelEvent.count }.by(2)

          expect(
            ResourceLabelEvent.where(issue: new_epic_work_item).pluck(:label_id, :namespace_id)
          ).to contain_exactly(
            [label1.id, group2.id],
            [label2.id, group2.id]
          )
        end
      end

      context 'when issue has iteration events' do
        it 'ignores copying iteration events' do
          create(:resource_iteration_event, issue: original_issue, iteration: cadence, action: :add)

          expect(subject).not_to receive(:copy_events).with(ResourceIterationEvent.table_name, any_args)

          expect { subject.execute }.not_to change { ResourceIterationEvent.count }
        end
      end

      context 'when issue has weight events' do
        it 'ignores copying weight events' do
          create_list(:resource_weight_event, 2, issue: original_issue)

          expect(subject).not_to receive(:copy_events).with(ResourceWeightEvent.table_name, any_args)

          expect { subject.execute }.not_to change { ResourceWeightEvent.count }
        end
      end
    end
  end
end
