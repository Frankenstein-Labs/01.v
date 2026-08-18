# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dast::ProfilesPipeline, :dynamic_analysis,
  feature_category: :dynamic_application_security_testing do
  subject { create(:dast_profiles_pipeline) }

  describe 'associations' do
    it { is_expected.to belong_to(:ci_pipeline).class_name('Ci::Pipeline').required }
    it { is_expected.to belong_to(:dast_profile).class_name('Dast::Profile').required }

    describe '#ci_pipeline' do
      it_behaves_like 'a partition-pruned pipeline association', :ci_pipeline do
        # .reload clears the :pipeline target cached by the attribute writer
        let(:related_resource) { create(:dast_profiles_pipeline, ci_pipeline: pipeline).reload }
      end
    end
  end

  context 'loose foreign key on dast_profiles_pipelines.ci_pipeline_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let!(:parent) { create(:ci_pipeline) }
      let!(:model) { create(:dast_profiles_pipeline, ci_pipeline: parent) }
    end
  end
end
