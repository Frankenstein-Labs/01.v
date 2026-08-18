# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Jira::Requests::Issues::CloudListService, feature_category: :integrations do
  include AfterNextHelpers

  describe '#execute' do
    let_it_be(:jira_integration) { create(:jira_integration, url: 'https://jira.example.com') }

    let(:params) { {} }

    subject(:service) { described_class.new(jira_integration, params) }

    context 'with reconcile_issue_ids parameter' do
      context 'when reconcile_issue_ids is empty' do
        let(:params) { { reconcile_issue_ids: [] } }

        it 'does not include reconcileIssues in the request URL' do
          expect_next(JIRA::Client).to receive(:get)
            .with(exclude('reconcileIssues'))
            .and_return({ 'issues' => [{ 'id' => '12345', 'key' => 'TST-1' }] })

          service.execute
        end
      end

      context 'when reconcile_issue_ids is provided' do
        let(:params) { { reconcile_issue_ids: ['12345'] } }

        it 'includes reconcileIssues in the request URL with reconcile_issue_ids values' do
          expect_next(JIRA::Client).to receive(:get)
            .with(include('reconcileIssues=12345'))
            .and_return({ 'issues' => [{ 'id' => '12345', 'key' => 'TST-1' }] })

          service.execute
        end
      end

      context 'when reconcile_issue_ids is an array' do
        let(:params) { { reconcile_issue_ids: %w[12345 67890] } }

        it 'includes multiple reconcileIssues parameters in the request URL' do
          expect_next(JIRA::Client).to receive(:get)
            .with(include('reconcileIssues=12345', 'reconcileIssues=67890'))
            .and_return({ 'issues' => [{ 'id' => '12345', 'key' => 'TST-1' }, { 'id' => '67890', 'key' => 'TST-2' }] })

          service.execute
        end
      end

      context 'when reconcile_issue_ids is combined with pagination' do
        let(:params) { { reconcile_issue_ids: ['12345'], next_page_token: 'next_page_token', per_page: 25 } }

        it 'includes all parameters in the request URL' do
          expect_next(JIRA::Client).to receive(:get)
            .with(include('reconcileIssues=12345', 'nextPageToken=next_page_token', 'maxResults=25'))
            .and_return({ 'issues' => [{ 'id' => '12345', 'key' => 'TST-1' }] })

          service.execute
        end
      end
    end
  end
end
