# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'embedded views (GLQL) EE' do
  def submit_glql_view(title:, glql_lines:)
    stub_feature_flags(glql_load_on_click: false)
    refresh
    expect(page).to have_field('Title')

    fill_in 'Title', with: title

    textarea = find_field('Description')
    textarea.send_keys "```glql\n"
    glql_lines.each { |line| textarea.send_keys "#{line}\n" }
    textarea.send_keys "```"

    is_mac = page.evaluate_script('navigator.platform').include?('Mac')
    modifier_key = is_mac ? :command : :control
    textarea.send_keys [modifier_key, :enter]

    expect(page).to have_css("[data-testid='glql-facade']")
  end

  context 'with a CodeSuggestions analytics query', :click_house do
    include ClickHouseHelpers

    let(:shown_event) { Ai::UsageEvent.events[:code_suggestion_shown_in_ide] }
    let(:accepted_event) { Ai::UsageEvent.events[:code_suggestion_accepted_in_ide] }

    before do
      stub_licensed_features(ai_analytics: true)
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

      namespace_path = project.project_namespace.traversal_path(with_organization: false)

      events_data = [
        {
          user_id: user.id,
          event: shown_event,
          timestamp: 5.days.ago,
          namespace_path: namespace_path,
          extras: { unique_tracking_id: 'uid-1', language: 'ruby', ide_name: 'VSCode', suggestion_size: 10 }
        },
        {
          user_id: user.id,
          event: accepted_event,
          timestamp: 5.days.ago + 2.seconds,
          namespace_path: namespace_path,
          extras: { unique_tracking_id: 'uid-1', language: 'ruby', ide_name: 'VSCode', suggestion_size: 10 }
        },
        {
          user_id: user.id,
          event: shown_event,
          timestamp: 3.days.ago,
          namespace_path: namespace_path,
          extras: { unique_tracking_id: 'uid-2', language: 'python', ide_name: 'JetBrains', suggestion_size: 20 }
        }
      ]

      clickhouse_fixture(:ai_usage_events, events_data)
    end

    context 'when displayed as a table' do
      before do
        submit_glql_view(
          title: 'GLQL code suggestions analytics test',
          glql_lines: [
            "mode: analytics",
            "query: type = CodeSuggestion and timestamp >= -30d",
            "dimensions: language",
            "metrics: totalCount, acceptanceRate",
            "display: table"
          ]
        )
      end

      it 'renders the code suggestions analytics query' do
        expect(page).to have_css("[data-testid='glql-facade'] table")
        expect(page).to have_content('ruby')
        expect(page).to have_content('python')
      end
    end

    context 'when displayed as a column chart' do
      before do
        submit_glql_view(
          title: 'GLQL code suggestions chart test',
          glql_lines: [
            "mode: analytics",
            "query: type = CodeSuggestion and timestamp >= -30d",
            "dimensions: language",
            "metrics: totalCount",
            "display: columnChart"
          ]
        )
      end

      it 'renders a column chart' do
        within "[data-testid='glql-facade']" do
          expect(page).to have_css("svg")
          expect(page).to have_content('ruby')
          expect(page).to have_content('python')
        end
      end
    end

    context 'when displayed as a line chart' do
      before do
        submit_glql_view(
          title: 'GLQL code suggestions line chart test',
          glql_lines: [
            "mode: analytics",
            "query: type = CodeSuggestion and timestamp >= -30d",
            "dimensions: language",
            "metrics: totalCount",
            "display: lineChart"
          ]
        )
      end

      it 'renders a line chart' do
        within "[data-testid='glql-facade']" do
          expect(page).to have_css("svg")
          expect(page).to have_content('ruby')
          expect(page).to have_content('python')
        end
      end
    end

    context 'when displayed as a bar chart' do
      before do
        submit_glql_view(
          title: 'GLQL code suggestions bar chart test',
          glql_lines: [
            "mode: analytics",
            "query: type = CodeSuggestion and timestamp >= -30d",
            "dimensions: language",
            "metrics: totalCount",
            "display: barChart"
          ]
        )
      end

      it 'renders a bar chart' do
        within "[data-testid='glql-facade']" do
          expect(page).to have_css("svg")
          expect(page).to have_content('ruby')
          expect(page).to have_content('python')
        end
      end
    end

    context 'when displayed as an area chart' do
      before do
        submit_glql_view(
          title: 'GLQL code suggestions area chart test',
          glql_lines: [
            "mode: analytics",
            "query: type = CodeSuggestion and timestamp >= -30d",
            "dimensions: language",
            "metrics: shownCount, acceptedCount",
            "display: areaChart"
          ]
        )
      end

      it 'renders an area chart' do
        within "[data-testid='glql-facade']" do
          expect(page).to have_css("svg")
          expect(page).to have_content('ruby')
          expect(page).to have_content('python')
        end
      end
    end
  end
end
