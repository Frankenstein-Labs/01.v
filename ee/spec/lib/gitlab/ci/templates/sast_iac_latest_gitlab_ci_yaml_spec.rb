# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SAST-IaC.latest.gitlab-ci.yml', feature_category: :static_application_security_testing do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('SAST-IaC.latest') }

  describe 'the created pipeline' do
    let_it_be(:default_branch) { 'master' }
    let_it_be(:feature_branch) { 'patch-1' }
    let_it_be(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }
    let_it_be(:user) { project.first_owner }
    let(:pipeline) { service.execute(:push).payload }

    before do
      stub_ci_pipeline_yaml_file(template.content)
    end

    context 'for all license tiers' do
      shared_examples 'common pipeline checks' do
        include_examples 'has expected jobs', %w[kics-iac-sast]
        include_examples 'has jobs that can be disabled', 'SAST_DISABLED', %w[true 1], %w[kics-iac-sast]
        include_examples 'has jobs that can be disabled', 'SAST_EXCLUDED_ANALYZERS', %w[kics], %w[kics-iac-sast]
      end

      context 'as a branch pipeline on the default branch' do
        include_context 'with default branch pipeline setup'

        include_examples 'common pipeline checks'
      end

      context 'as a branch pipeline on a feature branch' do
        include_context 'with feature branch pipeline setup'

        include_examples 'common pipeline checks'
      end

      context 'as an MR pipeline' do
        include_context 'with MR pipeline setup'

        include_examples 'common pipeline checks'

        context 'when AST_ENABLE_MR_PIPELINES=false' do
          include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'false' }

          include_examples 'has expected jobs', []
        end
      end
    end
  end
end
