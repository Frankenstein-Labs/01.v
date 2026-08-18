# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IncreaseCountersTask, feature_category: :vulnerability_management do
  describe '#execute' do
    context 'when the task runs for report ingestion' do
      let(:pipeline) { create(:ci_pipeline) }
      let(:finding_map_1) { create(:finding_map, pipeline: pipeline, new_record: true) }
      let(:finding_map_2) { create(:finding_map, pipeline: pipeline, new_record: false) }

      let(:security_statistics) { pipeline.project.security_statistics }
      let(:service_object) { described_class.new(pipeline, [finding_map_1, finding_map_2]) }

      subject(:execute_task) { service_object.execute }

      it 'increases vulnerability count' do
        expect { execute_task }.to change { security_statistics.reload.vulnerability_count }.by(1)
      end
    end

    context 'when the task runs for continuous vulnerability scanning' do
      # I must create a pipeline, even though we pass nil in the described class
      # because creating a finding_map automatically creates a pipeline (with a different project)
      # if one isn't supplied
      let(:pipeline_1) { create(:ci_pipeline) }
      let(:pipeline_2) { create(:ci_pipeline) }
      let(:finding_map_1) { create(:vs_finding_map, pipeline: pipeline_1, new_record: false) }
      let(:finding_map_2) { create(:vs_finding_map, pipeline: pipeline_1, new_record: true) }
      let(:finding_map_3) { create(:vs_finding_map, pipeline: pipeline_2, new_record: true) }

      let(:service_object) { described_class.new(nil, [finding_map_1, finding_map_2, finding_map_3]) }

      subject(:execute_task) { service_object.execute }

      it 'increases the vulnerability count for projects' do
        expect { execute_task }.to change { pipeline_1.project.security_statistics.reload.vulnerability_count }.by(1)
                               .and change { pipeline_2.project.security_statistics.reload.vulnerability_count }.by(1)
      end
    end
  end
end
