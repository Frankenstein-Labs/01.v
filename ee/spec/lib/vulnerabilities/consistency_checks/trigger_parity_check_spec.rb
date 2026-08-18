# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConsistencyChecks::TriggerParityCheck, factory_default: :keep, feature_category: :vulnerability_management do
  let_it_be(:namespace) { create_default(:namespace) }
  let_it_be(:project)   { create_default(:project) }

  subject(:execute) { described_class.execute(project) }

  describe '#execute' do
    context 'when vulnerability_occurrence_id differs from finding_id but points to valid occurrence' do
      let!(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
      let(:finding) { vulnerability.vulnerability_finding }
      let!(:other_finding) { create(:vulnerabilities_finding, project: project) }

      before do
        vulnerability.vulnerability_read.update_column(:vulnerability_occurrence_id, other_finding.id)
      end

      it 'fixes the vulnerability_occurrence_id to match vulnerabilities.finding_id' do
        expect { execute }.to change { vulnerability.vulnerability_read.reload.vulnerability_occurrence_id }
          .from(other_finding.id).to(finding.id)
      end
    end

    context 'when vulnerability_occurrence_id is NULL' do
      let!(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
      let(:finding) { vulnerability.vulnerability_finding }

      before do
        vulnerability.vulnerability_read.update_column(:vulnerability_occurrence_id, nil)
      end

      it 'backfills the vulnerability_occurrence_id' do
        expect { execute }.to change { vulnerability.vulnerability_read.reload.vulnerability_occurrence_id }
          .from(nil).to(finding.id)
      end
    end

    context 'when has_issues flag mismatches actual issue links' do
      let_it_be_with_reload(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
      let(:finding) { vulnerability.vulnerability_finding }

      context 'when has_issues is false but issue links exist with vulnerability_occurrence_id' do
        before do
          create(:vulnerabilities_issue_link, vulnerability: vulnerability,
            vulnerability_occurrence_id: finding.id)
          vulnerability.vulnerability_read.update_column(:has_issues, false)
        end

        it 'sets has_issues to true' do
          expect { execute }.to change { vulnerability.vulnerability_read.reload.has_issues }
            .from(false).to(true)
        end
      end

      context 'when has_issues is false and issue link has no vulnerability_occurrence_id' do
        before do
          create(:vulnerabilities_issue_link, vulnerability: vulnerability,
            vulnerability_occurrence_id: nil)
          vulnerability.vulnerability_read.update_column(:has_issues, false)
        end

        it 'does not set has_issues to true' do
          expect { execute }.not_to change { vulnerability.vulnerability_read.reload.has_issues }
        end
      end

      context 'when has_issues is true but no issue links exist' do
        before do
          vulnerability.vulnerability_read.update_column(:has_issues, true)
        end

        it 'sets has_issues to false' do
          expect { execute }.to change { vulnerability.vulnerability_read.reload.has_issues }
            .from(true).to(false)
        end
      end
    end

    context 'when has_merge_request flag mismatches actual MR links' do
      let_it_be_with_reload(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
      let(:finding) { vulnerability.vulnerability_finding }

      context 'when has_merge_request is false but MR links exist with vulnerability_occurrence_id' do
        before do
          create(:vulnerabilities_merge_request_link, vulnerability: vulnerability,
            vulnerability_occurrence_id: finding.id)
          vulnerability.vulnerability_read.update_column(:has_merge_request, false)
        end

        it 'sets has_merge_request to true' do
          expect { execute }.to change { vulnerability.vulnerability_read.reload.has_merge_request }
            .from(false).to(true)
        end
      end

      context 'when has_merge_request is false and MR link has no vulnerability_occurrence_id' do
        before do
          create(:vulnerabilities_merge_request_link, vulnerability: vulnerability,
            vulnerability_occurrence_id: nil)
          vulnerability.vulnerability_read.update_column(:has_merge_request, false)
        end

        it 'does not set has_merge_request to true' do
          expect { execute }.not_to change { vulnerability.vulnerability_read.reload.has_merge_request }
        end
      end

      context 'when has_merge_request is true but no MR links exist' do
        before do
          vulnerability.vulnerability_read.update_column(:has_merge_request, true)
        end

        it 'sets has_merge_request to false' do
          expect { execute }.to change { vulnerability.vulnerability_read.reload.has_merge_request }
            .from(true).to(false)
        end
      end
    end

    context 'when vulnerability_read is missing for a vulnerability' do
      let_it_be_with_reload(:vulnerability) do
        create(:vulnerability, :with_finding, project: project, present_on_default_branch: true)
      end

      let(:finding) { vulnerability.findings.first }

      before do
        Vulnerabilities::Read.where(vulnerability_id: vulnerability.id).delete_all
      end

      it 'creates the missing vulnerability_read' do
        expect { execute }.to change { Vulnerabilities::Read.exists?(vulnerability_id: vulnerability.id) }
          .from(false).to(true)
      end

      it 'creates the read with correct attributes from trigger logic' do
        execute

        read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id)
        expect(read).to have_attributes(
          project_id: vulnerability.project_id,
          scanner_id: finding.scanner_id,
          report_type: vulnerability.report_type,
          severity: vulnerability.severity,
          state: vulnerability.state,
          resolved_on_default_branch: vulnerability.resolved_on_default_branch,
          uuid: finding.uuid,
          vulnerability_occurrence_id: finding.id,
          has_issues: false,
          has_merge_request: false
        )
      end

      context 'when issue and MR links exist' do
        before do
          create(:vulnerabilities_issue_link, vulnerability: vulnerability)
          create(:vulnerabilities_merge_request_link, vulnerability: vulnerability)
        end

        it 'sets has_issues and has_merge_request' do
          execute

          read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id)
          expect(read).to have_attributes(has_issues: true, has_merge_request: true)
        end
      end
    end

    context 'when creating missing vulnerability reads' do
      def create_vulnerability_without_read
        vulnerability = create(:vulnerability, :with_finding, project: project, present_on_default_branch: true)
        Vulnerabilities::Read.where(vulnerability_id: vulnerability.id).delete_all
      end

      it 'does not have N+1 queries for loading associations' do
        create_vulnerability_without_read

        control = ActiveRecord::QueryRecorder.new { described_class.execute(project) }

        create_vulnerability_without_read
        create_vulnerability_without_read

        expect { described_class.execute(project) }
          .not_to exceed_query_limit(control)
          .for_query(/vulnerability_issue_links|vulnerability_merge_request_links/)
      end
    end

    context 'when vulnerability is not present_on_default_branch' do
      let!(:vulnerability) do
        create(:vulnerability, :with_finding, project: project, present_on_default_branch: false)
      end

      before do
        Vulnerabilities::Read.where(vulnerability_id: vulnerability.id).delete_all
      end

      it 'does not create a vulnerability_read' do
        expect { execute }.not_to change { Vulnerabilities::Read.count }
      end
    end

    context 'when vulnerability has no associated finding' do
      let!(:vulnerability) do
        create(:vulnerability, :with_finding, project: project, present_on_default_branch: true)
      end

      before do
        Vulnerabilities::Read.where(vulnerability_id: vulnerability.id).delete_all
        Vulnerabilities::Finding.where(vulnerability_id: vulnerability.id).delete_all
      end

      it 'skips creating a vulnerability_read' do
        expect { execute }.not_to change { Vulnerabilities::Read.count }
      end
    end

    context 'when finding location determines vulnerability_read fields' do
      let_it_be_with_reload(:vulnerability) do
        create(:vulnerability, :with_finding, project: project, present_on_default_branch: true)
      end

      let(:finding) { vulnerability.findings.first }

      before do
        Vulnerabilities::Read.where(vulnerability_id: vulnerability.id).delete_all
      end

      context 'when finding has empty location' do
        before do
          finding.update_column(:location, {})
        end

        it 'creates vulnerability_read with nil location fields' do
          execute

          read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id)
          expect(read).to have_attributes(
            location_image: nil,
            cluster_agent_id: nil,
            casted_cluster_agent_id: nil
          )
        end
      end

      context 'when finding location has no image key' do
        before do
          finding.update_column(:location, { 'file' => 'test.rb' })
        end

        it 'creates vulnerability_read with nil location_image' do
          execute

          read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id)
          expect(read.location_image).to be_nil
        end
      end

      context 'when finding location has no kubernetes_resource' do
        before do
          finding.update_column(:location, { 'image' => 'alpine:3.7' })
        end

        it 'creates vulnerability_read with nil cluster_agent_id fields' do
          execute

          read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id)
          expect(read).to have_attributes(
            location_image: 'alpine:3.7',
            cluster_agent_id: nil,
            casted_cluster_agent_id: nil
          )
        end
      end

      context 'when finding location has kubernetes_resource without agent_id' do
        before do
          finding.update_column(:location,
            { 'image' => 'alpine:3.7', 'kubernetes_resource' => { 'cluster_id' => '1' } })
        end

        it 'creates vulnerability_read with nil agent_id but populated location_image' do
          execute

          read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id)
          expect(read).to have_attributes(
            location_image: 'alpine:3.7',
            cluster_agent_id: nil,
            casted_cluster_agent_id: nil
          )
        end
      end

      context 'when finding location has kubernetes_resource with agent_id' do
        before do
          finding.update_column(:location, {
            'image' => 'nginx:latest',
            'kubernetes_resource' => { 'agent_id' => '42', 'cluster_id' => '1' }
          })
        end

        it 'creates vulnerability_read with populated cluster_agent_id fields' do
          execute

          read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id)
          expect(read).to have_attributes(
            location_image: 'nginx:latest',
            cluster_agent_id: '42',
            casted_cluster_agent_id: 42
          )
        end
      end
    end

    context 'when all data is consistent' do
      let!(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
      let(:finding) { vulnerability.vulnerability_finding }

      before do
        vulnerability.vulnerability_read.update_columns(
          scanner_id: finding.scanner_id,
          uuid: finding.uuid,
          vulnerability_occurrence_id: vulnerability.finding_id
        )
      end

      it 'does not modify the vulnerability_read' do
        expect { execute }.not_to change { vulnerability.vulnerability_read.reload.attributes }
      end
    end

    context 'when scanner_id mismatches' do
      let!(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
      let!(:other_scanner) { create(:vulnerabilities_scanner, project: project) }
      let(:finding) { vulnerability.vulnerability_finding }

      before do
        vulnerability.vulnerability_read.update_column(:scanner_id, other_scanner.id)
      end

      it 'fixes the scanner_id to match the finding linked via vulnerability_occurrence_id' do
        expect { execute }.to change { vulnerability.vulnerability_read.reload.scanner_id }
          .from(other_scanner.id).to(finding.scanner_id)
      end
    end

    context 'when uuid mismatches' do
      let!(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
      let(:finding) { vulnerability.vulnerability_finding }
      let(:wrong_uuid) { SecureRandom.uuid }

      before do
        vulnerability.vulnerability_read.update_column(:uuid, wrong_uuid)
      end

      it 'fixes the uuid to match the finding linked via vulnerability_occurrence_id' do
        expect { execute }.to change { vulnerability.vulnerability_read.reload.uuid }
          .from(wrong_uuid).to(finding.uuid)
      end
    end

    context 'when a fix method raises a StandardError' do
      let(:error) { StandardError.new('something went wrong') }

      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:fix_vulnerability_occurrence_id_mismatches).and_raise(error)
        end
      end

      it 'logs the error and re-raises' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(message: 'Failed to fix vulnerability_reads', error: error.message)
        )

        expect { execute }.to raise_error(StandardError, 'something went wrong')
      end
    end
  end
end
