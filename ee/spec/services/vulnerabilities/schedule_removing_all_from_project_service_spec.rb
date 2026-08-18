# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ScheduleRemovingAllFromProjectService, feature_category: :vulnerability_management do
  let_it_be(:project1) { create(:project) }
  let_it_be(:project2) { create(:project) }
  let_it_be(:user) { create(:user) }

  before do
    stub_licensed_features(security_dashboard: true)
    create_list(:vulnerability, 2, :with_findings, project: project1)
    create_list(:vulnerability, 2, :with_findings, project: project2)
  end

  describe '#execute' do
    subject(:service) { described_class.new(projects, true).execute }

    context 'when not all arguments are a Project' do
      let(:projects) { [1, 2] }

      it 'returns an error' do
        expect(service).to be_error
      end

      it 'does not schedule any jobs' do
        expect(Vulnerabilities::RemoveAllVulnerabilitiesWorker).not_to receive(:bulk_perform_async_with_contexts)

        service
      end
    end

    context 'with valid arguments', :clean_gitlab_redis_queues do
      let(:projects) { [project1, project2] }

      it 'does not fail' do
        expect(service).to be_success
      end

      it 'schedules jobs in bulk' do
        service

        scheduled_job_args = Vulnerabilities::RemoveAllVulnerabilitiesWorker.jobs.pluck('args')

        expect(scheduled_job_args).to match_array([
          [project1.id, { 'resolved_on_default_branch' => true }],
          [project2.id, { 'resolved_on_default_branch' => true }]
        ])
      end

      it 'returns all Projects affected' do
        expect(service.payload[:projects]).to eq(projects)
      end
    end
  end
end
