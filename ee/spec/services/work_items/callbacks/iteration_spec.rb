# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Iteration, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: cadence) }
  let_it_be_with_reload(:work_item) { create(:work_item, project: project, author: user) }

  let(:callback) { described_class.new(issuable: work_item, current_user: user, params: params) }

  describe '#before_create' do
    subject { callback.before_create }

    it_behaves_like 'iteration change is handled'
  end

  describe '#before_update' do
    subject(:before_update_callback) { callback.before_update }

    before do
      stub_licensed_features(iterations: true)
    end

    it_behaves_like 'iteration change is handled' do
      context 'when user can admin the work item' do
        let_it_be(:other_iteration) { create(:iteration, iterations_cadence: cadence) }

        before_all do
          project.add_reporter(user)
        end

        before do
          work_item.update!(iteration: iteration)
        end

        where(:new_iteration) do
          [[lazy { other_iteration }], [nil]]
        end

        with_them do
          let(:params) { { iteration: new_iteration } }

          it 'sets a new iteration value for the work item' do
            expect { before_update_callback }.to change { work_item.iteration }.to(new_iteration).from(iteration)
          end
        end

        context 'when widget does not exist in new type' do
          let(:params) { {} }

          before do
            allow(callback).to receive(:excluded_in_new_type?).and_return(true)
            work_item.iteration = iteration
          end

          it "resets the work item's iteration" do
            expect { before_update_callback }.to change { work_item.iteration }.from(iteration).to(nil)
          end
        end
      end
    end
  end

  describe '#after_update_commit' do
    let_it_be(:old_iteration) { create(:iteration, group: group) }
    let_it_be(:new_iteration) { create(:iteration, group: group) }
    let_it_be(:child_work_item) do
      create(:work_item, :task, project: project, sprint_id: old_iteration.id).tap do |child|
        create(:parent_link, work_item_parent: work_item, work_item: child)
      end
    end

    let(:params) { {} }

    subject(:after_update_commit) { callback.after_update_commit }

    before_all do
      work_item.update!(iteration: old_iteration)
    end

    RSpec.shared_examples "does not update children" do
      it 'does not update child work items' do
        expect { after_update_commit }.to not_change { child_work_item.iteration }
          .and not_change { ResourceIterationEvent.count }
      end
    end

    context 'when iteration has not changed' do
      it_behaves_like "does not update children"
    end

    context 'when iteration has changed' do
      before do
        work_item.update!(iteration: new_iteration)
      end

      context "when work_item does not have the iteration widget" do
        before do
          allow(work_item).to receive(:get_widget).with(:iteration).and_return(false)
        end

        it_behaves_like "does not update children"
      end

      context 'when work item has the iteration widget' do
        it 'updates iteration for child work items' do
          expect { after_update_commit }.to change { child_work_item.reload.iteration }
            .from(old_iteration).to(new_iteration)
            .and change { ResourceIterationEvent.count }.by(1)
        end

        it 'does not produce N+1 queries' do
          callback.after_update_commit # warm-up

          new_iteration1 = create(:iteration, group: group)
          work_item.update!(iteration: new_iteration1)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            callback.after_update_commit
          end

          create(:work_item, :task, project: project, sprint_id: new_iteration1.id).tap do |child|
            create(:parent_link, work_item_parent: work_item, work_item: child)
          end
          new_iteration2 = create(:iteration, group: group)
          work_item.update!(iteration: new_iteration2)

          expect { callback.after_update_commit }.to issue_same_number_of_queries_as(control)
        end

        context 'when child work item is closed' do
          before do
            child_work_item.update!(state: :closed)
          end

          it_behaves_like "does not update children"
        end

        context 'when child work item is not in the previous iteration' do
          before do
            child_work_item.update!(iteration: create(:iteration, group: group))
          end

          it_behaves_like "does not update children"
        end

        context "when children do not have the iteration widget" do
          before do
            stub_all_work_item_widgets(iteration: false)
          end

          it_behaves_like "does not update children"
        end

        context 'when there are multiple child work items' do
          let_it_be(:child_work_item2) do
            create(:work_item, :task, project: project, sprint_id: old_iteration.id).tap do |child|
              create(:parent_link, work_item_parent: work_item, work_item: child)
            end
          end

          it 'updates all child work items' do
            expect { after_update_commit }.to change { child_work_item.reload.iteration }
              .from(old_iteration).to(new_iteration)
              .and change { child_work_item2.reload.iteration }.from(old_iteration).to(new_iteration)
              .and change { ResourceIterationEvent.count }.by(2)
          end
        end
      end
    end
  end
end
