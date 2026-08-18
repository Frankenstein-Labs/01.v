# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion, feature_category: :vulnerability_management do
  describe '.ingest_pipeline?' do
    let_it_be(:project) { create(:project, :repository) }

    subject(:ingest_pipeline?) { described_class.ingest_pipeline?(pipeline) }

    context 'when pipeline is on the default branch' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch) }

      it { is_expected.to be true }
    end

    context 'when pipeline is not on the default branch' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch') }

      context 'when the pipeline ref is tracked' do
        before do
          create(:security_project_tracked_context, :tracked,
            project: project,
            context_name: pipeline.ref,
            context_type: :branch)
        end

        it { is_expected.to be true }
      end

      context 'when the pipeline ref is not tracked' do
        it { is_expected.to be false }
      end

      context 'when the pipeline is a tag' do
        let(:pipeline) { create(:ci_pipeline, :tag, project: project, ref: 'v1.0.0') }

        context 'when the tag is tracked' do
          before do
            create(:security_project_tracked_context, :tracked, :tag,
              project: project,
              context_name: pipeline.ref)
          end

          it { is_expected.to be true }
        end

        context 'when the tag is not tracked' do
          it { is_expected.to be false }
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(vulnerabilities_across_contexts: false)
        end

        it { is_expected.to be false }
      end
    end
  end
end
