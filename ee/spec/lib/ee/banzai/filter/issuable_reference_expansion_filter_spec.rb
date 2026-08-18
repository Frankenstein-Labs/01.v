# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::IssuableReferenceExpansionFilter, feature_category: :portfolio_management do
  include FilterSpecHelper

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:other_group, freeze: false) { create(:group) }
  let_it_be(:epic, freeze: false) { create(:epic, :opened, group: group, title: 'Some epic') }
  let_it_be(:closed_epic, freeze: false) { create(:epic, :closed, group: group) }

  let_it_be(:context, freeze: false) do
    { current_user: user, issuable_reference_expansion_enabled: true, group: group }
  end

  def create_link(text, data)
    ActionController::Base.helpers.link_to(text, '', class: 'gfm has-tooltip', data: data)
  end

  it 'ignores open epic references' do
    link = create_link(epic.to_reference, epic: epic.id, reference_type: 'epic')

    doc = filter(link, context)

    expect(doc.css('a').last.text).to eq(epic.to_reference)
  end

  it 'appends state to closed epic references' do
    link = create_link(closed_epic.to_reference, epic: closed_epic.id, reference_type: 'epic')

    doc = filter(link, context)

    expect(doc.css('a').last.text).to eq("#{closed_epic.to_reference} (closed)")
  end

  it 'shows title for references with +' do
    link = create_link(epic.to_reference, epic: epic.id, reference_type: 'epic', reference_format: '+')

    doc = filter(link, context)

    expect(doc.css('a').last.text).to eq("#{epic.title} (#{epic.to_reference})")
  end

  it 'shows title for references with +s' do
    link = create_link(epic.to_reference, epic: epic.id, reference_type: 'epic', reference_format: '+s')

    doc = filter(link, context)

    expect(doc.css('a').last.text).to eq("#{epic.title} (#{epic.to_reference}) • Unassigned")
  end

  context 'when extended summary props are present' do
    let_it_be(:project, freeze: false) { create(:project, :public) }
    let_it_be(:milestone, freeze: false) { create(:milestone, project: project) }
    let_it_be(:assignees, freeze: false) { create_list(:user, 3) }

    before do
      stub_licensed_features(issuable_health_status: true)
    end

    it 'shows extended summary for references with +s' do
      issue = create(:issue, :opened,
        project: project,
        title: 'Some issue',
        milestone: milestone,
        assignees: assignees,
        health_status: Issue.health_statuses.values.sample)
      link = create_link(issue.to_reference, issue: issue.id, reference_type: 'issue', reference_format: '+s')
      doc = filter(link, context)

      expect(doc.css('a').last.text).to eq(
        "#{issue.title} (#{issue.to_reference}) • #{assignees[0].name}, #{assignees[1].name}+ • " \
        "#{milestone.title} • #{issue.health_status.humanize}"
      )
    end
  end

  context 'when epics are licensed' do
    let_it_be(:work_item, freeze: false) do
      create(:work_item, :epic_with_legacy_epic, assignees: [user], health_status: :at_risk)
    end

    let_it_be(:epic, freeze: false) { work_item.synced_epic }

    let_it_be(:context, freeze: false) do
      { current_user: user, issuable_reference_expansion_enabled: true, group: epic.group }
    end

    before do
      stub_licensed_features(issuable_health_status: true, epics: true)
    end

    it 'shows additional details for epic references with +s' do
      link = create_link(epic.to_reference, epic: epic.id, reference_type: 'epic', reference_format: '+s')

      doc = filter(link, context)

      expect(doc.css('a').last.text).to eq("#{epic.title} (#{epic.to_reference}) • #{user.name} • " \
                                           "#{work_item.health_status.humanize}")
    end
  end
end
