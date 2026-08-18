# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Color, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:group) { create(:group, reporters: reporter) }
  let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group, author: user) }
  let_it_be(:error_class) { ::Issuable::Callbacks::Base::Error }

  let(:current_user) { reporter }
  let(:params) { {} }
  let(:callback) { described_class.new(issuable: work_item, current_user: current_user, params: params) }

  def work_item_color
    work_item.reload.color&.color.to_s
  end

  shared_examples 'work item and color is unchanged' do
    it 'does not change work item color value' do
      expect { subject }
        .to not_change { work_item_color }
        .and not_change { work_item.updated_at }
    end
  end

  shared_examples 'color is updated' do |color|
    it 'updates work item color value' do
      expect { subject }.to change { work_item_color }.to(color)
    end
  end

  shared_examples 'raises a callback error' do
    it { expect { subject }.to raise_error(error_class, message) }
  end

  shared_examples 'when epic_colors feature is licensed' do
    before do
      stub_licensed_features(epics: true, epic_colors: true)
    end

    context 'when color param is present' do
      let(:params) { { color: '#454545' } }

      context 'when color param is valid' do
        it_behaves_like 'color is updated', '#454545'
      end

      context 'without group level work items license' do
        before do
          stub_licensed_features(epics: false, epic_colors: true)
        end

        it_behaves_like 'work item and color is unchanged'
      end
    end

    context 'when color param is not present' do
      let(:params) { {} }

      it_behaves_like 'work item and color is unchanged'

      context 'when widget does not exist in type' do
        let(:params) { {} }

        before do
          allow(callback).to receive(:excluded_in_new_type?).and_return(true)
        end

        it "does not set the color" do
          subject

          expect(work_item.reload.color).to be_nil
        end
      end
    end

    context 'when color param is nil' do
      let(:params) { { color: nil } }

      it_behaves_like 'raises a callback error' do
        let(:message) { "Color can't be blank" }
      end
    end

    context 'when user cannot admin_work_item' do
      let(:current_user) { user }
      let(:params) { { color: '#1068bf' } }

      it_behaves_like 'work item and color is unchanged'
    end
  end

  shared_examples 'when epic_colors feature is unlicensed' do
    before do
      stub_licensed_features(epics: true, epic_colors: false)
    end

    it_behaves_like 'work item and color is unchanged'
  end

  describe '#before_update' do
    subject(:before_update_callback) { callback.before_update }

    let_it_be_with_reload(:color) { create(:color, work_item: work_item, color: '#1068bf') }

    it_behaves_like 'when epic_colors feature is licensed'
    it_behaves_like 'when epic_colors feature is unlicensed'

    context 'when color is same as work item color' do
      let(:params) { { color: '#1068bf' } }

      it_behaves_like 'work item and color is unchanged'
    end
  end

  describe '#before_create' do
    subject(:before_create_callback) { callback.before_create }

    it_behaves_like 'when epic_colors feature is licensed'
    it_behaves_like 'when epic_colors feature is unlicensed'
  end

  describe '#after_update_commit' do
    subject(:after_update_commit_callback) { callback.after_update_commit }

    let_it_be_with_reload(:color) { create(:color, work_item: work_item, color: '#1068bf') }

    it "does not create system notes when color didn't change" do
      expect { after_update_commit_callback }.to not_change { work_item.notes.count }
    end

    context 'when color was reset' do
      before do
        allow(work_item.color).to receive(:destroyed?).and_return(true)
      end

      it 'creates system note' do
        expect { after_update_commit_callback }.to change { work_item.notes.count }.by(1)

        expect(work_item.notes.first.note).to eq("removed color `#{color.color}` **Blue**")
      end
    end

    context 'when color was updated' do
      before do
        allow(work_item.color).to receive_message_chain(:previous_changes, :include?).and_return(true)
      end

      it 'creates system note' do
        expect { after_update_commit_callback }.to change { work_item.notes.count }.by(1)

        expect(work_item.notes.first.note).to eq("set color to `#{color.color}` **Blue**")
      end
    end
  end
end
