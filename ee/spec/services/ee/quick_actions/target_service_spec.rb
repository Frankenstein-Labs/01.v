# frozen_string_literal: true

require 'spec_helper'

RSpec.describe QuickActions::TargetService, feature_category: :team_planning do
  let(:group) { create(:group) }
  let(:user) { create(:user) }
  let(:service) { described_class.new(container: group, current_user: user) }

  before do
    group.add_maintainer(user)
    stub_licensed_features(epics: true)
  end

  describe '#execute' do
    context 'for epic' do
      let(:type) { 'Epic' }

      it 'finds target with valid iid' do
        epic = create(:epic, group: group)

        target = service.execute(type, epic.iid)

        expect(target).to eq(epic)
      end

      it 'builds a new target if iid from a different group passed' do
        epic = create(:epic)

        target = service.execute(type, epic.iid)

        expect(target).to be_new_record
        expect(target.group).to eq(group)
      end
    end

    context 'for nil type' do
      let(:type) { nil }

      it 'does not raise error' do
        epic = create(:epic, group: group)

        expect { service.execute(type, epic.iid) }.not_to raise_error
      end
    end

    context 'for work item' do
      let(:target) { create(:work_item, :task, project: project) }
      let(:target_iid) { target.iid }
      let(:type) { 'WorkItem' }

      context 'when work item belongs to a group' do
        let(:container) { group }
        let(:target) { create(:work_item, :group_level, namespace: group) }

        context 'with group level work item license' do
          before do
            stub_licensed_features(epics: true)
          end

          it 'returns the target' do
            found_target = service.execute(type, target_iid)

            expect(found_target).to eq(target)
          end
        end

        context 'without group level work item license' do
          before do
            stub_licensed_features(epics: false)
          end

          it 'returns the target' do
            found_target = service.execute(type, target_iid)

            expect(found_target).to be_nil
          end
        end
      end
    end
  end
end
