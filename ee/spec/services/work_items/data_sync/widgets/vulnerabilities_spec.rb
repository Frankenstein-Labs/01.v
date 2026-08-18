# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::Vulnerabilities, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:work_item) { create(:work_item) }
  let_it_be(:vulnerabilities_issue_link) { create_list(:vulnerabilities_issue_link, 2, issue: work_item) }
  let_it_be_with_reload(:target_work_item) { create(:work_item) }

  let(:params) { { operation: :move } }

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: params
    )
  end

  describe '#after_save_commit' do
    context 'when cloning work item' do
      let(:params) { { operation: :clone } }

      it 'does not copy related vulnerabilities data' do
        expect { callback.after_save_commit }.not_to change { target_work_item.related_vulnerabilities.count }
      end
    end

    context 'when target work item has vulnerabilities data' do
      let(:params) { { operation: :move } }

      it 'when moving work item' do
        expected_related_vulnerabilities = work_item.related_vulnerabilities

        callback.after_save_commit

        expect(target_work_item.related_vulnerabilities).to match_array(expected_related_vulnerabilities)
      end
    end
  end

  describe "post_move_cleanup" do
    it 'removes original work item related_vulnerabilities' do
      expect(work_item.related_vulnerabilities.count).to eq(2)

      callback.post_move_cleanup

      expect(work_item.related_vulnerabilities).to be_empty
    end
  end
end
