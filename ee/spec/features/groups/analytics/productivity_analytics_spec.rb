# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups::ProductivityAnalytics', feature_category: :value_stream_management do
  let_it_be(:merged_after_date) { '2024-07-08' }
  let_it_be(:merged_before_date) { '2024-07-09' }

  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:project) { create(:project, group: group) }

  let(:params) do
    {
      author_username: 'user',
      label_name: %w[label1 label2],
      milestone_title: 'user',
      merged_after: merged_after_date.to_datetime,
      merged_before: merged_before_date.to_datetime,
      project_id: project.full_path
    }
  end

  before do
    stub_licensed_features(productivity_analytics: true)

    sign_in(user)

    group.add_reporter(user)
  end

  context 'when params are valid' do
    before do
      visit group_analytics_productivity_analytics_path(group, params)
    end

    it 'exposes valid url params in data attributes', :aggregate_failures do
      element = page.find('#js-productivity-analytics')

      expect(element['data-project-id']).to eq(project.id.to_s)
      expect(element['data-project-name']).to eq(project.name)
      expect(element['data-project-path-with-namespace']).to eq(project.path_with_namespace)
      expect(element['data-project-avatar-url']).to eq(project.avatar_url)

      expect(element['data-group-id']).to eq(group.id.to_s)
      expect(element['data-group-name']).to eq(group.name)
      expect(element['data-group-full-path']).to eq(group.full_path)
      expect(element['data-group-avatar-url']).to eq(group.avatar_url)

      expect(element['data-author-username']).to eq(params[:author_username])
      expect(element['data-label-name']).to eq(params[:label_name].join(','))
      expect(element['data-milestone-title']).to eq(params[:milestone_title])

      expect(element['data-merged-after']).to include(params[:merged_after].utc.iso8601.sub('Z', ''))
      expect(element['data-merged-before']).to include(params[:merged_before].utc.iso8601.sub('Z', ''))
    end

    context 'in date range picker', :js do
      it 'displays the correct dates and number of days selected', :aggregate_failures do
        expect(page.find(".js-daterange-picker-from input").value).to eq(merged_after_date)
        expect(page.find(".js-daterange-picker-to input").value).to eq(merged_before_date)
        expect(find_by_testid('daterange-picker-indicator')).to have_text _('1 day selected')
      end
    end
  end

  context 'when params are invalid' do
    before do
      params[:merged_before] = params[:merged_after] - 5.days # invalid
    end

    it 'does not expose params in data attributes', :aggregate_failures do
      visit group_analytics_productivity_analytics_path(group, params)

      element = page.find('#js-productivity-analytics')

      expect(element['data-project-id']).to be_nil
      expect(element['data-group-id']).to be_nil
      expect(element['data-author-username']).to be_nil

      expect(element['data-merged-before']).not_to be_nil
      expect(element['data-merged-after']).not_to be_nil
    end
  end
end
