# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::BulkSetComponentService, feature_category: :static_application_security_testing do
  let_it_be(:project) { create(:project) }
  let_it_be(:finding_longest) { create_finding('app/services/auth/session.rb') }
  let_it_be(:finding_shortest) { create_finding('app/models/user.rb') }
  let_it_be(:finding_unmatched) { create_finding('lib/other.rb') }
  let_it_be(:finding_no_file) { create_finding(nil) }
  let(:finding_ids) do
    [finding_longest.id, finding_shortest.id, finding_unmatched.id, finding_no_file.id]
  end

  let_it_be(:scan) { create(:security_ascp_scan, project: project) }
  let_it_be(:component_app) { create(:security_ascp_component, project: project, scan: scan, sub_directory: 'app') }
  let_it_be(:component_services) do
    create(:security_ascp_component, project: project, scan: scan, sub_directory: 'app/services')
  end

  def create_finding(file)
    if file.nil?
      create(:vulnerabilities_finding, project: project, location: nil,
        raw_metadata: Gitlab::Json.dump({ description: 'no location' }))
    else
      create(:vulnerabilities_finding, project: project, location: { 'file' => file })
    end
  end

  subject(:execute) { described_class.new(project: project, finding_ids: finding_ids).execute }

  describe '#execute' do
    it 'returns a success response with matched/unmatched counts', :aggregate_failures do
      expect(execute).to be_success
      expect(execute.payload).to eq(matched: 2, unmatched: 2, removed: 0)
    end

    it 'links each finding to its longest-prefix component' do
      expect { execute }.to change { finding_longest.reload.ascp_component }.from(nil).to(component_services)
        .and change { finding_shortest.reload.ascp_component }.from(nil).to(component_app)
    end

    it 'does not create links for unmatched findings' do
      expect { execute }.to not_change { finding_unmatched.reload.ascp_component }.from(nil)
        .and not_change { finding_no_file.reload.ascp_component }.from(nil)
    end

    context 'when a finding no longer matches a component' do
      before do
        create(:vulnerability_finding_ascp_component_link,
          project: project, vulnerability_finding: finding_unmatched, ascp_component: component_app)
      end

      it 'removes the stale link' do
        expect { execute }.to change { finding_unmatched.reload.ascp_component }.from(component_app).to(nil)
      end
    end

    context 'when the association already exists' do
      before do
        create(:vulnerability_finding_ascp_component_link,
          project: project, vulnerability_finding: finding_longest, ascp_component: component_app)
      end

      it 'updates the component to the longest match' do
        expect { execute }.to change { finding_longest.reload.ascp_component }
          .from(component_app).to(component_services)
      end

      it 'does not create a duplicate link' do
        expect { execute }.not_to change {
          Vulnerabilities::AscpComponentLink.where(vulnerability_occurrence_id: finding_longest.id).count
        }.from(1)
      end

      it 'bumps updated_at when the component changes' do
        link = finding_longest.reload.ascp_component_link

        travel_to(1.hour.from_now) do
          expect { execute }.to change { link.reload.updated_at }.to(Time.current)
        end
      end
    end

    context 'when re-syncing links whose component is unchanged' do
      before do
        execute
      end

      it 'skips the no-op write and leaves updated_at untouched' do
        link = finding_longest.reload.ascp_component_link
        original_updated_at = link.updated_at

        travel_to(1.hour.from_now) do
          described_class.new(project: project, finding_ids: finding_ids).execute
        end

        expect(link.reload.updated_at).to be_within(1.second).of(original_updated_at)
      end
    end

    it 'logs an error with a sample of findings that have a file but match no component' do
      expect(Gitlab::AppJsonLogger).to receive(:error).with(
        hash_including(
          message: 'Findings with a file path did not match an ASCP component',
          project_id: project.id,
          unmatched_count: 1,
          unmatched_finding_ids: [finding_unmatched.id]
        )
      )

      execute
    end

    context 'when the only unmatched finding has no file path' do
      let(:finding_ids) { [finding_longest.id, finding_no_file.id] }

      it 'does not log an error for the benign skip' do
        expect(Gitlab::AppJsonLogger).not_to receive(:error)

        execute
      end
    end

    context 'when every finding with a file matches a component' do
      let(:finding_ids) { [finding_longest.id, finding_shortest.id] }

      it 'does not log an error' do
        expect(Gitlab::AppJsonLogger).not_to receive(:error)

        execute
      end
    end

    context 'when no ASCP scan exists for the project' do
      let_it_be(:empty_project) { create(:project) }
      let_it_be(:orphan_finding) do
        create(:vulnerabilities_finding, project: empty_project, location: { 'file' => 'app/x.rb' })
      end

      subject(:execute) { described_class.new(project: empty_project, finding_ids: [orphan_finding.id]).execute }

      it 'is a no-op', :aggregate_failures do
        expect { execute }.not_to change { Vulnerabilities::AscpComponentLink.count }
        expect(execute.payload).to eq(matched: 0, unmatched: 0, removed: 0)
      end
    end

    context 'when the scan has more components than the service can safely match' do
      before do
        stub_const("#{described_class}::MAX_COMPONENTS", 1)
        allow(Gitlab::AppJsonLogger).to receive(:error)
      end

      it 'returns an error without linking anything', :aggregate_failures do
        expect { execute }.not_to change { Vulnerabilities::AscpComponentLink.count }

        expect(execute).to be_error
        expect(execute.reason).to eq(:too_many_components)
        expect(execute.payload).to eq(matched: 0, unmatched: 0, removed: 0)
      end

      it 'leaves existing links untouched' do
        create(:vulnerability_finding_ascp_component_link,
          project: project, vulnerability_finding: finding_unmatched, ascp_component: component_app)

        expect { execute }.not_to change { finding_unmatched.reload.ascp_component }.from(component_app)
      end

      it 'logs the reason for skipping' do
        expect(Gitlab::AppJsonLogger).to receive(:error).with(
          hash_including(
            message: 'Skipped ASCP component matching because the scan has too many components',
            project_id: project.id,
            scan_id: scan.id,
            max_components: 1
          )
        )

        execute
      end
    end

    context 'when finding_ids is empty' do
      let(:finding_ids) { [] }

      it 'is a no-op', :aggregate_failures do
        expect { execute }.not_to change { Vulnerabilities::AscpComponentLink.count }
        expect(execute.payload).to eq(matched: 0, unmatched: 0, removed: 0)
      end
    end

    context 'when a file path merely shares a leading substring with a component sub_directory' do
      let_it_be(:finding_similar_prefix) { create_finding('application/foo.rb') }

      let(:finding_ids) { [finding_similar_prefix.id] }

      it 'does not treat it as a match' do
        expect { execute }.not_to change { finding_similar_prefix.reload.ascp_component }.from(nil)
      end
    end

    context 'when a finding belongs to another project' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:foreign_finding) do
        create(:vulnerabilities_finding, project: other_project, location: { 'file' => 'app/services/x.rb' })
      end

      let(:finding_ids) { [foreign_finding.id] }

      it 'does not link findings outside the project' do
        expect { execute }.not_to change { Vulnerabilities::AscpComponentLink.count }
      end
    end
  end
end
