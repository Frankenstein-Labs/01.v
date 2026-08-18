# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineMessage, feature_category: :continuous_integration do
  let_it_be_with_refind(:pipeline) do
    create(:ci_empty_pipeline)
  end

  describe 'scopes' do
    describe '.pipeline_execution_policy_failure' do
      subject(:pipeline_execution_policy_failure) { described_class.pipeline_execution_policy_failure }

      let!(:warning_message) do
        create(:ci_pipeline_message, pipeline: pipeline, content: 'Warning message', severity: :warning)
      end

      let!(:non_pipeline_execution_policy_error_message) do
        create(:ci_pipeline_message, pipeline: pipeline, content: 'Non Pipeline execution policy error',
          severity: :error)
      end

      context 'when content does not contains pipeline execution policy error' do
        specify do
          expect(pipeline_execution_policy_failure).to be_empty
        end
      end

      context 'when content contains pipeline execution policy error' do
        let(:security_policies_error_message) do
          'Pipeline execution policy error: Cyclic dependencies detected when enforcing policies.' \
            'Ensure stages across the project and policies are aligned.'
        end

        let!(:pipeline_execution_policy_error_message) do
          create(:ci_pipeline_message, pipeline: pipeline, content: security_policies_error_message, severity: :error)
        end

        it 'returns the pipeline_execution_policy_error_message' do
          expect(pipeline_execution_policy_failure).to contain_exactly(pipeline_execution_policy_error_message)
        end
      end
    end
  end
end
