# frozen_string_literal: true

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- View specs require real objects for proper rendering
require 'spec_helper'

RSpec.describe 'shared/milestones/_issuable.html.haml', feature_category: :portfolio_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:user_namespace_project) { create(:project) }

  subject(:rendered) { render 'shared/milestones/issuable', issuable: issuable, show_project_name: true }

  context 'when issuable is an epic' do
    let_it_be(:issuable) { create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group) }

    it 'links to the epic' do
      url = ::Gitlab::UrlBuilder.build(issuable)
      expect(rendered).to have_css("a[href$='#{url}']", class: 'issue-link')
    end

    it 'renders the epic work item type icon' do
      expect(rendered).to have_css(%(svg use[href$="#work-item-epic"]))
    end
  end

  context 'when issuable is an issue' do
    let_it_be_with_refind(:issuable) { create(:work_item, :issue, project: project) }

    let(:status) { build(:work_item_system_defined_lifecycle).default_open_status }

    it 'does not display status' do
      expect(rendered).not_to have_text(status.name)
    end

    context 'when work_item_status feature is available' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      it 'shows name' do
        expect(rendered).to have_text(status.name)
      end

      it 'includes color' do
        expect(rendered).to include(status.color)
      end

      it 'includes category icon' do
        expect(rendered).to have_css(%(svg use[href*="##{status.icon_name}"]))
      end

      context 'when project is in user namespace' do
        let_it_be_with_refind(:issuable) { create(:work_item, :issue, project: user_namespace_project) }

        it 'does not display status' do
          expect(rendered).not_to have_text(status.name)
        end
      end
    end

    context 'when issuable is merge request' do
      let_it_be_with_refind(:issuable) do
        create(:merge_request, source_project: project, target_project: project)
      end

      it 'does not display status' do
        expect(rendered).not_to have_text(status.name)
      end
    end
  end

  context 'when issuable is a project-level epic work item with a label' do
    let_it_be(:project_milestone) { create(:milestone, project: project) }
    let_it_be(:label) { create(:label, project: project, title: 'bug') }
    let_it_be(:project_epic) do
      create(:work_item, :epic, project: project, labels: [label], milestone: project_milestone)
    end

    before do
      assign(:project, project)
      assign(:milestone, project_milestone)
    end

    subject(:rendered) do
      render 'shared/milestones/issuable', issuable: project_epic, show_project_name: true
    end

    it 'renders without raising NoMethodError for project_epics_path' do
      expect { rendered }.not_to raise_error
    end

    it 'links the label to the project issues list filtered by the label' do
      expected_href = project_issues_path(
        project,
        milestone_title: project_milestone.title,
        label_name: label.title,
        state: 'all'
      )

      expect(rendered).to have_css("a[href='#{expected_href}']")
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
