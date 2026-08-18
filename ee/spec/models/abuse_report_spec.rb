# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AbuseReport, feature_category: :insider_threat do
  describe '.create' do
    it 'calls the new abuse report worker' do
      expect(AntiAbuse::NewAbuseReportWorker).to receive(:perform_async)
      create(:abuse_report)
    end
  end

  describe '#report_type' do
    let(:report) { build_stubbed(:abuse_report, reported_from_url: url) }
    let_it_be(:epic) { create(:epic) }

    subject(:report_type) { report.report_type }

    context 'when reported from an epic' do
      let(:url) { Gitlab::Routing.url_helpers.group_epic_url(epic.group, epic) }

      it { is_expected.to eq :epic }
    end
  end

  describe '#reported_content' do
    let(:report) { build_stubbed(:abuse_report, reported_from_url: url) }
    let_it_be(:epic) { create(:epic, description: 'epic description') }

    subject(:reported_content) { report.reported_content }

    context 'when reported from an epic' do
      let(:url) { Gitlab::Routing.url_helpers.group_epic_url(epic.group, epic) }

      it { is_expected.to eq epic.description_html }

      context 'when the cached HTML is empty' do
        let(:epic) { create(:epic, description: 'epic description') }

        before do
          epic.update_columns(description_html: nil)
        end

        it 're-renders and returns the cached HTML from the source description', :aggregate_failures do
          expect(reported_content).to eq(epic.reload.description_html)
          expect(reported_content).to include('epic description')
        end
      end

      context 'when the cached HTML version is stale' do
        let(:epic) { create(:epic, description: 'epic description') }

        before do
          epic.update_columns(description_html: '<p>outdated cached html</p>', cached_markdown_version: 1)
        end

        it 're-renders from the source description instead of returning the stale HTML', :aggregate_failures do
          expect(reported_content).not_to include('outdated cached html')
          expect(reported_content).to include('epic description')
          expect(reported_content).to eq(epic.reload.description_html)
        end
      end
    end
  end
end
