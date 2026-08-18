# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'DAST.gitlab-ci.yml', feature_category: :dynamic_application_security_testing do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('DAST') }

  describe 'the created pipeline' do
    let_it_be(:default_branch) { 'master' }
    let_it_be(:feature_branch) { 'patch-1' }
    let_it_be(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }
    let_it_be(:user) { project.first_owner }
    let(:pipeline) { service.execute(:push).payload }

    context 'when stages list does not include dast' do
      before do
        stub_ci_pipeline_yaml_file(template.content)
      end

      include_context 'with default branch pipeline setup'

      include_examples 'missing stage', 'dast'
    end

    context 'when stages list includes dast' do
      let(:ci_pipeline_yaml) { "stages: [\"dast\"]\n" }

      before do
        stub_ci_pipeline_yaml_file(ci_pipeline_yaml + template.content)
      end

      context 'when project has no license' do
        include_context 'with default branch pipeline setup'

        include_examples 'has expected jobs', []
      end

      context 'when project has Ultimate license' do
        let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }
        # TODO: check why we need to re declare projet here in order to get the license applied
        let_it_be(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }
        let_it_be(:user) { project.first_owner }

        before do
          allow(License).to receive(:current).and_return(license)
        end

        shared_examples 'common pipeline checks' do
          include_examples 'has expected jobs', %w[dast]
          include_examples 'has jobs that can be disabled', 'DAST_DISABLED', %w[true 1], %w[dast]
          include_examples 'has FIPS compatible jobs', 'DAST_IMAGE_SUFFIX', %w[dast]
        end

        context 'as a branch pipeline on the default branch' do
          include_context 'with default branch pipeline setup'

          include_examples 'common pipeline checks'
          include_examples 'has jobs that can be disabled',
            'DAST_DISABLED_FOR_DEFAULT_BRANCH', %w[true 1], %w[dast]
        end

        context 'as a branch pipeline on a feature branch' do
          include_context 'with feature branch pipeline setup'

          include_examples 'common pipeline checks'
          include_examples 'has jobs that can be disabled', 'REVIEW_DISABLED', %w[true 1], %w[dast]
        end

        context 'as an MR pipeline' do
          include_context 'with MR pipeline setup'

          include_examples 'has expected jobs', []

          context 'when AST_ENABLE_MR_PIPELINES=true' do
            include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'true' }

            include_examples 'common pipeline checks'
            include_examples 'has jobs that can be disabled', 'REVIEW_DISABLED', %w[true 1], %w[dast]
          end
        end
      end
    end
  end
end
