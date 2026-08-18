# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'API-Security.latest.gitlab-ci.yml', feature_category: :dynamic_application_security_testing do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('API-Security.latest') }

  specify { expect(template).not_to be_nil }

  describe 'the template file' do
    let(:template_filename) { Rails.root.join("lib/gitlab/ci/templates/" + template.full_name) }
    let(:contents) { File.read(template_filename) }
    let(:production_registry) { 'APISEC_IMAGE: api-security' }
    let(:staging_registry) { 'APISEC_IMAGE: api-fuzzing-src' }

    # Make sure future changes to the template use the production container registry.
    #
    # The API Security template is developed against a dev container registry.
    # The registry is switched when releasing new versions. The difference in
    # names between development and production is also quite small making it
    # easy to miss during review.
    it 'uses the production repository' do
      expect(contents.include?(production_registry)).to be true
    end

    it "doesn't use the staging repository" do
      expect(contents.include?(staging_registry)).to be false
    end
  end

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

        # job still runs to display an error
        include_examples 'has expected jobs', %w[api_security]
      end

      context 'when project has Ultimate license' do
        let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }

        before do
          allow(License).to receive(:current).and_return(license)
        end

        shared_examples 'common pipeline checks' do
          include_examples 'has expected jobs', %w[api_security]
          include_examples 'has jobs that can be disabled', 'APISEC_DISABLED', %w[true 1], %w[api_security]
          include_examples 'has FIPS compatible jobs', 'APISEC_IMAGE_SUFFIX', %w[api_security]
        end

        context 'as a branch pipeline on the default branch' do
          include_context 'with default branch pipeline setup'

          include_examples 'common pipeline checks'
          include_examples 'has jobs that can be disabled',
            'APISEC_DISABLED_FOR_DEFAULT_BRANCH', %w[true 1], %w[api_security]
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
end
