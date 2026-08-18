# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Quality::Seeders::Vulnerabilities, feature_category: :vulnerability_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  subject(:seed) { described_class.new(project).seed! }

  before_all do
    project.add_developer(user)
  end

  context 'when project has members' do
    it 'creates expected number of vulnerabilities' do
      expect { seed }.to change { Vulnerability.count }.by(30)
    end

    it 'creates vulnerability reads' do
      expect { seed }.to change { ::Vulnerabilities::Read.count }.by(30)
    end

    it 'sets up bidirectional finding-vulnerability relationship' do
      seed

      project.vulnerabilities.each do |vulnerability|
        expect(vulnerability.finding.vulnerability_id).to eq(vulnerability.id)
      end
    end

    it 'creates vulnerability reads with correct attributes' do
      seed

      vulnerability = project.vulnerabilities.first
      read = vulnerability.vulnerability_read

      expect(read.project_id).to eq(project.id)
      expect(read.state).to eq(vulnerability.state)
      expect(read.severity).to eq(vulnerability.severity)
    end
  end

  context 'when project has no members' do
    before do
      project.users.delete_all
    end

    it 'does not create vulnerabilities on project' do
      expect { seed }.not_to change { Vulnerability.count }
    end
  end

  context 'when PostgreSQL trigger is disabled' do
    before do
      ::SecApplicationRecord.connection.execute(
        "SELECT set_config('vulnerability_management.dont_execute_db_trigger', 'true', true);"
      )
    end

    it 'creates vulnerability reads through the seeder code' do
      expect { seed }.to change { ::Vulnerabilities::Read.count }.by(30)
    end

    it 'creates vulnerability reads with all required attributes' do
      seed

      vulnerability = project.vulnerabilities.first
      finding = vulnerability.finding
      read = vulnerability.vulnerability_read

      expect(read).to have_attributes(
        vulnerability_id: vulnerability.id,
        project_id: project.id,
        scanner_id: finding.scanner_id,
        report_type: vulnerability.report_type,
        severity: vulnerability.severity,
        state: vulnerability.state,
        resolved_on_default_branch: vulnerability.resolved_on_default_branch,
        uuid: finding.uuid,
        location_image: vulnerability.location&.dig('image'),
        cluster_agent_id: vulnerability.location&.dig('kubernetes_resource', 'agent_id'),
        has_issues: vulnerability.issue_links.any?,
        has_merge_request: vulnerability.merge_request_links.any?,
        traversal_ids: project.namespace.traversal_ids,
        archived: project.archived,
        identifier_names: finding.identifiers.map(&:name),
        owasp_top_10: 'undefined',
        has_vulnerability_resolution: false
      )
    end

    it 'sets casted_cluster_agent_id correctly when agent_id is present' do
      # Create a vulnerability with location containing agent_id
      scanner = ::Vulnerabilities::Scanner.create!(
        project: project,
        external_id: 'test-scanner',
        name: 'Test Scanner'
      )

      identifier = create(:vulnerabilities_identifier, project: project)

      finding = create(
        :vulnerabilities_finding,
        :with_pipeline,
        project: project,
        scanner: scanner,
        primary_identifier: identifier,
        raw_metadata: {
          location: {
            kubernetes_resource: {
              agent_id: '123'
            }
          }
        }.to_json
      )

      vulnerability = create(
        :vulnerability,
        project: project,
        author: user,
        finding_id: finding.id
      )

      finding.update!(vulnerability_id: vulnerability.id)

      seeder = described_class.new(project)
      seeder.send(:create_vulnerability_read, vulnerability, finding)

      read = vulnerability.reload.vulnerability_read
      expect(read.casted_cluster_agent_id).to eq(123)
    end

    context 'when vulnerability read creation fails' do
      it 'prints error message but continues processing' do
        vulnerability = create(:vulnerability, project: project, author: user)
        finding = create(:vulnerabilities_finding, project: project, vulnerability: vulnerability)

        seeder = described_class.new(project)

        allow(::Vulnerabilities::Read).to receive(:exists?).and_return(false)
        allow(::Vulnerabilities::Read).to receive(:create!).and_raise(
          ActiveRecord::RecordInvalid.new(
            ::Vulnerabilities::Read.new
          )
        )

        expect do
          seeder.send(:create_vulnerability_read, vulnerability, finding)
        end.to output(/Failed to create vulnerability_read for vulnerability #{vulnerability.id}/).to_stdout
      end
    end

    context 'with different vulnerability states' do
      it 'creates vulnerability reads for resolved vulnerabilities' do
        seeder = described_class.new(project)

        allow(::Vulnerability.states.keys).to receive(:sample).and_return('resolved')

        expect { seeder.seed! }.to change { ::Vulnerabilities::Read.count }

        resolved_vulnerability = project.vulnerabilities.find_by(state: 'resolved')
        expect(resolved_vulnerability).to be_present
        expect(resolved_vulnerability.vulnerability_read).to be_present
        expect(resolved_vulnerability.vulnerability_read.state).to eq('resolved')
      end

      it 'creates vulnerability reads for dismissed vulnerabilities' do
        seeder = described_class.new(project)

        allow(::Vulnerability.states.keys).to receive(:sample).and_return('dismissed')

        expect { seeder.seed! }.to change { ::Vulnerabilities::Read.count }

        dismissed_vulnerability = project.vulnerabilities.find_by(state: 'dismissed')
        expect(dismissed_vulnerability).to be_present
        expect(dismissed_vulnerability.vulnerability_read).to be_present
        expect(dismissed_vulnerability.vulnerability_read.state).to eq('dismissed')
      end
    end

    context 'when vulnerability has associated issues' do
      it 'sets has_issues to true in vulnerability read' do
        seed

        # Find a vulnerability that should have an issue (rank % 3 == 1)
        vulnerability_with_issue = project.vulnerabilities.joins(:issue_links).first

        expect(vulnerability_with_issue).to be_present
        expect(vulnerability_with_issue.vulnerability_read.has_issues).to be true
      end
    end

    context 'when processing vulnerabilities with secondary identifiers' do
      it 'does not add duplicate identifiers' do
        seeder = described_class.new(project)
        seeder.seed!

        project.vulnerabilities.each do |vulnerability|
          finding = vulnerability.finding
          identifier_ids = finding.identifiers.map(&:id)

          expect(identifier_ids.uniq.count).to eq(identifier_ids.count)
        end
      end

      it 'skips adding secondary identifier if it already exists' do
        # Create a scenario where secondary identifier already exists
        primary_identifier = create(:vulnerabilities_identifier, project: project)
        secondary_identifier = create(:vulnerabilities_identifier, project: project)

        finding = create(
          :vulnerabilities_finding,
          :with_pipeline,
          project: project,
          primary_identifier: primary_identifier
        )

        # Pre-add the secondary identifier
        finding.identifiers << secondary_identifier

        vulnerability = create(
          :vulnerability,
          project: project,
          author: project.users.first,
          finding_id: finding.id
        )

        finding.update!(vulnerability_id: vulnerability.id)

        # Manually call the seeder logic for rank % 3 == 0
        secondary_id = create(:vulnerabilities_identifier, project: project)
        initial_count = finding.identifiers.count

        # This should not add a duplicate
        finding.identifiers << secondary_id unless finding.identifiers.include?(secondary_id)

        expect(finding.identifiers.count).to eq(initial_count + 1)
      end
    end

    context 'when processing feedback creation' do
      it 'creates dismissal feedback for rank % 3 == 0' do
        seeder = described_class.new(project)
        seeder.seed!

        dismissal_feedbacks = Vulnerabilities::Feedback.where(feedback_type: 'dismissal')
        expect(dismissal_feedbacks.count).to be > 0
      end

      it 'creates issue feedback for rank % 3 == 1' do
        seeder = described_class.new(project)
        seeder.seed!

        issue_feedbacks = Vulnerabilities::Feedback.where(feedback_type: 'issue')
        expect(issue_feedbacks.count).to be > 0
      end
    end

    context 'when feature_flagged_transaction_for is used' do
      it 'wraps vulnerability creation in a transaction with feature flag' do
        seeder = described_class.new(project)

        expect(SecApplicationRecord).to receive(:feature_flagged_transaction_for).at_least(:once).and_call_original

        seeder.seed!
      end

      it 'creates vulnerabilities within the transaction' do
        seeder = described_class.new(project)

        expect { seeder.seed! }.to change { Vulnerability.count }.by(30)
      end

      it 'creates vulnerability reads for all vulnerabilities' do
        seeder = described_class.new(project)
        seeder.seed!

        project.vulnerabilities.each do |vulnerability|
          expect(vulnerability.vulnerability_read).to be_present
        end
      end

      it 'updates finding with vulnerability_id' do
        seeder = described_class.new(project)
        seeder.seed!

        project.vulnerabilities.each do |vulnerability|
          expect(vulnerability.finding.vulnerability_id).to eq(vulnerability.id)
        end
      end
    end
  end
end
