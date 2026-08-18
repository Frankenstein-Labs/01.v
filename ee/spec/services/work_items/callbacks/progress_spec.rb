# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Progress, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:work_item) { create(:work_item, :objective, project: project, author: user) }
  let_it_be_with_reload(:progress) { create(:progress, work_item: work_item, progress: 5, current_value: 5) }

  let(:callback) { described_class.new(issuable: work_item, current_user: user, params: params) }

  def work_item_progress
    work_item.reload.progress&.progress
  end

  def work_item_current_value
    work_item.reload.progress&.current_value
  end

  def work_item_start_value
    work_item.reload.progress&.start_value
  end

  def work_item_end_value
    work_item.reload.progress&.end_value
  end

  describe '#before_update' do
    subject(:before_update_callback) { callback.before_update }

    shared_examples 'work item and progress is unchanged' do
      it 'does not change work item progress value' do
        expect { subject }
          .to not_change { work_item_progress }
          .and not_change { work_item_current_value }
          .and not_change { work_item.updated_at }
      end

      it 'does not create notes' do
        expect { subject }.to not_change(work_item.notes, :count)
      end
    end

    shared_examples 'current_value & progress are updated' do |current_value, progress|
      it 'updates work item progress value' do
        expect { subject }
          .to change { work_item_progress }.to(progress).and change { work_item_current_value }.to(current_value)
      end

      it 'creates notes' do
        subject

        work_item_note = work_item.notes.last
        expect(work_item_note.note).to eq("changed progress to **#{progress}%**")
      end
    end

    shared_examples 'start_value & end_value are updated' do |start_value, end_value|
      it 'updates work item start and end values' do
        expect { subject }
          .to change { work_item_start_value }.to(start_value).and change { work_item_end_value }.to(end_value)
      end
    end

    shared_examples 'raises a callback error' do
      it { expect { subject }.to raise_error(::Issuable::Callbacks::Base::Error, message) }
    end

    context 'when progress feature is licensed' do
      before do
        stub_licensed_features(okrs: true)
      end

      context 'when user cannot update work item' do
        let(:params) { { current_value: 10 } }

        before_all do
          project.add_guest(user)
        end

        it_behaves_like 'work item and progress is unchanged'
      end

      context 'when user can update work item' do
        before_all do
          project.add_reporter(user)
        end

        context 'when current_value param is present' do
          context 'when current_value param is valid' do
            context 'when start & end values are defaults' do
              let(:params) { { current_value: 20 } }

              it_behaves_like 'current_value & progress are updated', 20, 20
            end

            context 'when start & end values are non-defaults' do
              let(:params) { { current_value: 100, start_value: 20, end_value: 220 } }

              it_behaves_like 'current_value & progress are updated', 100, 40
              it_behaves_like 'start_value & end_value are updated', 20, 220
            end
          end

          context 'when widget does not exist in new type' do
            let(:params) { {} }

            before do
              allow(callback).to receive(:excluded_in_new_type?).and_return(true)
              work_item.progress = progress
            end

            it "removes the work item's progress" do
              expect { before_update_callback }.to change { work_item.reload.progress }.from(progress).to(nil)

              work_item_note = work_item.notes.last
              expect(work_item_note.note).to eq("removed the progress **5%**")
            end
          end
        end

        context 'when current_value param is not present' do
          let(:params) { {} }

          it_behaves_like 'work item and progress is unchanged'
        end

        context 'when progress is same as current value' do
          let(:params) { { current_value: 5 } }

          it_behaves_like 'work item and progress is unchanged'
        end

        context 'when current_value param is nil' do
          let(:params) { { current_value: nil } }

          it_behaves_like 'raises a callback error' do
            let(:message) { "Progress is not a number, Current value can't be blank" }
          end
        end
      end
    end
  end
end
