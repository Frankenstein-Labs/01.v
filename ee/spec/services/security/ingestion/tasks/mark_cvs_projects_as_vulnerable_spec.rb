# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::MarkCvsProjectsAsVulnerable, feature_category: :software_composition_analysis do
  describe '#execute' do
    let(:project_setting_1) { create(:project_setting, has_vulnerabilities: false) }
    let(:project_setting_2) { create(:project_setting, has_vulnerabilities: true) }

    let(:project_1) { project_setting_1.project }
    let(:project_2) { project_setting_2.project }
    let(:project_3) { create(:project) }

    let(:pipeline_1) { create(:ci_pipeline, project: project_1) }
    let(:pipeline_2) { create(:ci_pipeline, project: project_2) }
    let(:pipeline_3) { create(:ci_pipeline, project: project_3) }

    let(:finding_map_1) { create(:vs_finding_map, pipeline: pipeline_1) }
    let(:finding_map_2) { create(:vs_finding_map, pipeline: pipeline_2) }
    let(:finding_map_3) { create(:vs_finding_map, pipeline: pipeline_3) }

    let(:task) { described_class.new(nil, [finding_map_1, finding_map_2, finding_map_3]) }

    subject(:execute) { task.execute }

    it 'marks projects as has_vulnerabilities' do
      expect { execute }.to change { project_1.reload.project_setting.has_vulnerabilities? }.to(true)
                        .and change { project_3.reload.project_setting.has_vulnerabilities? }.to(true)
                        .and not_change { project_2.reload.project_setting.has_vulnerabilities? }.from(true)
    end
  end
end
