# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::CustomFields, feature_category: :team_planning do
  describe '#after_save_commit' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:work_item) { create(:work_item) }
    let_it_be(:target_work_item) { create(:work_item) }
    let(:copy_service) { instance_double(WorkItems::Widgets::CopyCustomFieldValuesService) }

    subject(:callback) do
      described_class.new(
        work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: {}
      )
    end

    context 'when target work item does not have custom field widget' do
      before do
        allow(target_work_item).to receive(:get_widget).with(:custom_fields).and_return(nil)
      end

      it 'does not call the copy service' do
        expect(WorkItems::Widgets::CopyCustomFieldValuesService).not_to receive(:new)

        callback.after_save_commit
      end
    end

    context 'when target work item has custom field widget' do
      before do
        allow(target_work_item).to receive(:get_widget).with(:custom_fields).and_return(true)
        allow(WorkItems::Widgets::CopyCustomFieldValuesService).to receive(:new)
          .with(work_item: work_item, target_work_item: target_work_item)
          .and_return(copy_service)
      end

      it 'calls the copy service' do
        expect(copy_service).to receive(:execute)

        callback.after_save_commit
      end
    end
  end
end
