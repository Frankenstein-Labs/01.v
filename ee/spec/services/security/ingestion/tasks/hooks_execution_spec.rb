# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::HooksExecution, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let_it_be(:tracked_context) do
      create(:security_project_tracked_context, :default, :tracked, project: pipeline.project)
    end

    let_it_be(:non_default_tracked_context) do
      create(:security_project_tracked_context, :tracked, context_name: 'dev', project: pipeline.project)
    end

    let_it_be(:vulnerabilities) { create_list(:vulnerability, 4) }

    let_it_be(:finding_map_1) do
      create(:finding_map, vulnerability: vulnerabilities[0], tracked_context: tracked_context, new_record: true)
    end

    let_it_be(:finding_map_2) do
      create(:finding_map, vulnerability: vulnerabilities[1], tracked_context: tracked_context, new_record: true)
    end

    let_it_be(:finding_map_3) do
      create(:finding_map, vulnerability: vulnerabilities[2], tracked_context: tracked_context)
    end

    let_it_be(:finding_map_4) do
      create(:finding_map, vulnerability: vulnerabilities[3],
        tracked_context: non_default_tracked_context, new_record: true)
    end

    let!(:service_object) do
      described_class.new(pipeline, [finding_map_1, finding_map_2, finding_map_3, finding_map_4])
    end

    subject(:ingest_finding_remediations) { service_object.execute }

    before do
      vulnerabilities.each do |vulnerability|
        allow(vulnerability).to receive(:execute_hooks)
        allow(vulnerability).to receive(:trigger_false_positive_detection)
      end

      allow(Vulnerability).to receive(:where).with(id: vulnerabilities[0..1].map(&:id)).and_return(
        [
          vulnerabilities[0],
          vulnerabilities[1]
        ])

      SecApplicationRecord.transaction { ingest_finding_remediations }
    end

    it 'executes the hooks associated with all new vulnerabilities' do
      expect(vulnerabilities[0]).to have_received(:execute_hooks)
      expect(vulnerabilities[1]).to have_received(:execute_hooks)
    end

    it 'triggers false positive detection associated with all new vulnerabilities' do
      expect(vulnerabilities[0]).to have_received(:trigger_false_positive_detection)
      expect(vulnerabilities[1]).to have_received(:trigger_false_positive_detection)
    end

    it 'does not execute the hooks associated with existing vulnerabilities' do
      expect(vulnerabilities[2]).not_to have_received(:execute_hooks)
    end

    it 'does not execute the hooks on non default branches' do
      expect(vulnerabilities[3]).not_to have_received(:execute_hooks)
    end

    it 'does not trigger false positive detection associated with existing vulnerabilities' do
      expect(vulnerabilities[2]).not_to have_received(:trigger_false_positive_detection)
    end

    it 'does not trigger false positive detection associated on non default branches' do
      expect(vulnerabilities[3]).not_to have_received(:trigger_false_positive_detection)
    end
  end
end
