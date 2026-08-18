# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ClosingIssueExtractor, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }

  let_it_be(:group_work_item) { create(:work_item, :group_level, namespace: group) }

  subject(:closing_issue_extractor) { described_class.new(project, project.creator) }

  before_all do
    group.add_developer(project.creator)
  end

  context 'when reference is a group level work item' do
    before do
      stub_licensed_features(epics: true)
    end

    specify do
      message = "Closes #{Gitlab::UrlBuilder.build(group_work_item)}"
      expect(closing_issue_extractor.closed_by_message(message)).to contain_exactly(group_work_item)
    end

    context 'when multiple references are used for the same work item' do
      it 'only returns the same work item once' do
        message =
          "Closes #{Gitlab::UrlBuilder.build(group_work_item)} Closes #{group_work_item.to_reference(full: true)}"
        expect(closing_issue_extractor.closed_by_message(message)).to contain_exactly(group_work_item)
      end
    end
  end
end
