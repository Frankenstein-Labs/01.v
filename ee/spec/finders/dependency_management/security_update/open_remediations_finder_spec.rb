# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::OpenRemediationsFinder,
  feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }

  describe '#execute' do
    context 'when there is no dependency management service account' do
      subject(:finder) { described_class.new(project: project) }

      it 'returns an empty relation' do
        result = finder.execute
        expect(result).to be_a(ActiveRecord::Relation)
        expect(result.count).to eq(0)
      end
    end

    context 'when there is a dependency management service account' do
      let_it_be(:service_account) do
        create(:user, :service_account, name: DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME)
      end

      before_all do
        project.add_member(service_account, :guest)
      end

      subject(:finder) { described_class.new(project: project) }

      before do
        allow(project).to receive(:dependency_management_service_account).and_return(service_account)
      end

      it 'returns an ActiveRecord::Relation' do
        result = finder.execute
        expect(result).to be_a(ActiveRecord::Relation)
      end

      it 'returns an empty relation when there are no merge requests' do
        result = finder.execute
        expect(result.count).to eq(0)
      end

      it 'filters by target project' do
        # Verify the scope is applied by checking the SQL includes the target_project_id condition
        result = finder.execute
        expect(result.to_sql).to include('target_project_id')
      end

      it 'filters by author' do
        # Verify the scope is applied by checking the SQL includes the author_id condition
        result = finder.execute
        expect(result.to_sql).to include('author_id')
      end

      it 'filters by opened state' do
        # Verify the scope is applied by checking the SQL includes the state_id condition
        result = finder.execute
        expect(result.to_sql).to include('state_id')
      end

      it 'preloads everything the scheduler reaches for' do
        merge_request = create(:merge_request, :opened,
          target_project: project, source_project: project, author: service_account,
          source_branch: 'dependency-management/rails-6.x', target_branch: 'main',
          skip_branch_existence_check: true)
        vulnerability = create(:vulnerability, :detected, :critical, project: project,
          report_type: :dependency_scanning,
          findings: [build(:vulnerabilities_finding, :identifier, project: project,
            report_type: :dependency_scanning, solution: 'Upgrade.', raw_metadata: '{}')])
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)

        result = finder.execute.first

        expect(result.association(:latest_merge_request_diff)).to be_loaded
        expect(result.association(:vulnerability_merge_request_links)).to be_loaded

        linked_vulnerability = result.vulnerability_merge_request_links.first.vulnerability
        expect(linked_vulnerability.association(:findings)).to be_loaded
        expect(linked_vulnerability.association(:sbom_occurrences)).to be_loaded
      end
    end
  end
end
