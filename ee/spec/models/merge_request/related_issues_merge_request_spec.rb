# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequest, feature_category: :code_review_workflow do
  describe '#related_issues' do
    subject(:related_issues) { merge_request.related_issues(user) }

    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:user) { create(:user, guest_of: project) }
    let_it_be(:group) { create(:group) }

    let(:merge_request) do
      create(
        :merge_request,
        source_project: project,
        target_project: project,
        description: "See #{Gitlab::UrlBuilder.build(work_item)}"
      )
    end

    before_all do
      group.add_reporter(user)
    end

    before do
      stub_licensed_features(epics: true)
      allow(merge_request).to receive(:commits).and_return([])
    end

    context 'when a group-level issue is referenced by a work item URL' do
      let(:work_item) { create(:work_item, :issue, :group_level, namespace: group) }

      it 'returns the issue' do
        expect(related_issues).to include(work_item)
      end
    end

    context 'when an epic is referenced by a work item URL' do
      let(:work_item) { create(:work_item, :epic, :group_level, namespace: group) }

      it 'excludes the epic' do
        expect(related_issues).not_to include(work_item)
      end
    end
  end
end
