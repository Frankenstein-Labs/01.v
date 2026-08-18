# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::Labels, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:params) { {} }

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: params
    )
  end

  before_all do
    group.add_developer(current_user)
  end

  describe '#after_create' do
    context 'when target work item has labels widget' do
      context 'with group level work item(epic)' do
        let_it_be(:another_group) { create(:group) }
        let_it_be(:labels) { create_list(:group_label, 2, group: group) }
        let_it_be(:another_group_label1) { create(:group_label, group: another_group, title: labels[0].title) }
        let_it_be(:another_group_label2) { create(:group_label, group: another_group, title: labels[1].title) }
        let_it_be(:target_work_item) { create(:work_item, :epic, namespace: another_group) }
        let_it_be(:work_item) do
          create(:work_item, :epic_with_legacy_epic, namespace: group, labels: labels)
        end

        before do
          stub_licensed_features(epics: true)
        end

        it 'copies labels from work_item to target_work_item' do
          expect(work_item.reload.labels).to match_array(labels)

          expect(callback).to receive(:new_work_item_label_links).and_call_original
          expect(::LabelLink).to receive(:insert_all).and_call_original

          # 2 labels from group replaced by labels in another group => 2 removed + 2 added => 4
          expect { callback.after_create }.to change { ::ResourceLabelEvent.count }.by(4)

          expect(target_work_item.reload.labels.pluck(:title)).to match_array(labels.pluck(:title))
        end

        describe '#post_move_cleanup' do
          it 'removes original work item labels' do
            expect { callback.post_move_cleanup }.to change { work_item.reload.labels.count }.from(2).to(0)
          end
        end
      end
    end
  end
end
