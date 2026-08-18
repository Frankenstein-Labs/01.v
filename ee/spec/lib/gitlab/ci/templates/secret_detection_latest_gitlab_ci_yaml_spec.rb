# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Secret-Detection.latest.gitlab-ci.yml', feature_category: :secret_detection do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('Jobs/Secret-Detection.latest') }

  describe 'the created pipeline' do
    let_it_be(:default_branch) { 'master' }
    let_it_be(:feature_branch) { 'patch-1' }
    # refind so each example gets a project instance with no memoized
    # predefined_project_variables, which caches GITLAB_FEATURES.
    let_it_be_with_refind(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }
    let_it_be(:user) { project.first_owner }
    let(:pipeline) { service.execute(:push).payload }

    before do
      stub_ci_pipeline_yaml_file(template.content)
    end

    shared_examples 'common pipeline checks' do
      include_examples 'has expected jobs', %w[secret_detection]
      include_examples 'has jobs that can be disabled', 'SECRET_DETECTION_DISABLED', %w[true 1], %w[secret_detection]

      context 'when tier is ultimate' do
        let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }

        before do
          allow(License).to receive(:current).and_return(license)
        end

        context 'when SECRET_DETECTION_ENABLE_GSS is not set' do
          include_examples 'has expected image', 'secret_detection',
            'registry.gitlab.com/security-products/secrets:7'
        end

        %w[true 1].each do |enabled_value|
          context "when SECRET_DETECTION_ENABLE_GSS is set to '#{enabled_value}'" do
            include_context 'with CI variables', { 'SECRET_DETECTION_ENABLE_GSS' => enabled_value }

            include_examples 'has expected jobs', %w[secret_detection]
            include_examples 'has expected image', 'secret_detection',
              'registry.gitlab.com/security-products/gitlab-advanced-secrets:edge'

            context "when SECRET_DETECTION_IMAGE_SUFFIX is set to '-fips'" do
              include_context 'with CI variables', { 'SECRET_DETECTION_IMAGE_SUFFIX' => '-fips' }

              include_examples 'has expected image', 'secret_detection',
                'registry.gitlab.com/security-products/gitlab-advanced-secrets:edge-fips'
            end
          end
        end

        %w[false 0].each do |disabled_value|
          context "when SECRET_DETECTION_ENABLE_GSS is set to '#{disabled_value}'" do
            include_context 'with CI variables', { 'SECRET_DETECTION_ENABLE_GSS' => disabled_value }

            include_examples 'has expected image', 'secret_detection',
              'registry.gitlab.com/security-products/secrets:7'
          end
        end

        context 'with generic secret detection' do
          include_context 'with CI variables', { 'SECRET_DETECTION_ENABLE_GSS' => 'true' }

          let(:generic_secrets_variable) do
            build = pipeline.builds.find_by(name: 'secret_detection')
            build.variables.to_hash['SECRET_DETECTION_GSS_ENABLE_GENERIC_SECRETS']
          end

          it 'is enabled by default' do
            expect(generic_secrets_variable).to eql('true')
          end

          context "when SECRET_DETECTION_GSS_ENABLE_GENERIC_SECRETS is set to 'false'" do
            include_context 'with CI variables', { 'SECRET_DETECTION_GSS_ENABLE_GENERIC_SECRETS' => 'false' }

            it 'can be disabled' do
              expect(generic_secrets_variable).to eql('false')
            end
          end
        end
      end

      context 'when tier is premium' do
        let(:license) { build(:license, plan: License::PREMIUM_PLAN) }

        before do
          allow(License).to receive(:current).and_return(license)
        end

        %w[true 1].each do |enabled_value|
          context "when SECRET_DETECTION_ENABLE_GSS is set to '#{enabled_value}'" do
            include_context 'with CI variables', { 'SECRET_DETECTION_ENABLE_GSS' => enabled_value }

            include_examples 'has expected jobs', %w[secret_detection]
            include_examples 'has expected image', 'secret_detection',
              'registry.gitlab.com/security-products/secrets:7'
          end
        end
      end
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
