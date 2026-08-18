# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'API-Discovery.gitlab-ci.yml', feature_category: :dynamic_application_security_testing do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('API-Discovery') }

  specify { expect(template).not_to be_nil }

  describe 'the template file' do
    let(:template_filename) { Rails.root.join("lib/gitlab/ci/templates/#{template.full_name}") }
    let(:contents) { File.read(template_filename) }
    let(:production_registry) { 'API_DISCOVERY_PACKAGES: "$CI_API_V4_URL/projects/42503323/packages"' }
    let(:staging_registry) { 'API_DISCOVERY_PACKAGES: "$CI_API_V4_URL/projects/40229908/packages"' }

    # Make sure the staging package registry does not sneak into the production template.
    it 'uses the production registry' do
      expect(contents.include?(production_registry)).to be true
    end

    it "doesn't use the staging registry" do
      expect(contents.include?(staging_registry)).to be false
    end
  end

  describe 'the created pipeline' do
    let_it_be(:default_branch) { 'master' }
    let_it_be(:feature_branch) { 'patch-1' }
    let_it_be(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }
    let_it_be(:user) { project.first_owner }
    let(:pipeline) { service.execute(:push).payload }

    let(:ci_pipeline_job) do
      <<~YAML

      api_discovery:
        extends: .api_discovery_java_spring_boot
        image: openjdk:11-jre-slim
        variables:
          API_DISCOVERY_JAVA_CLASSPATH: build/libs/spring-boot-app-0.0.0.jar
      YAML
    end

    before do
      allow_next_instance_of(Ci::BuildScheduleWorker) do |worker|
        allow(worker).to receive(:perform).and_return(true)
      end

      allow(project).to receive(:default_branch).and_return(default_branch)
    end

    context 'when project defines no jobs' do
      before do
        stub_ci_pipeline_yaml_file(template.content)
      end

      include_context 'with default branch pipeline setup'

      it 'includes no jobs' do
        expect(pipeline.builds.pluck(:name)).to be_empty
        expect(pipeline.errors.full_messages).to match_array(['jobs config should contain at least one visible job'])
      end
    end

    context 'when project defines jobs' do
      before do
        stub_ci_pipeline_yaml_file(template.content + ci_pipeline_job)
      end

      context 'when project has no license' do
        include_context 'with default branch pipeline setup'

        # job still runs to display an error
        include_examples 'has expected jobs', %w[api_discovery]
      end

      context 'when project has Ultimate license' do
        let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }

        before do
          allow(License).to receive(:current).and_return(license)
        end

        shared_examples 'common pipeline checks' do
          include_examples 'has expected jobs', %w[api_discovery]
          include_examples 'has jobs that can be disabled', 'API_DISCOVERY_DISABLED', %w[true 1], %w[api_discovery]
        end

        context 'as a branch pipeline on the default branch' do
          include_context 'with default branch pipeline setup'

          include_examples 'common pipeline checks'
          include_examples 'has jobs that can be disabled',
            'API_DISCOVERY_DISABLED_FOR_DEFAULT_BRANCH', %w[true 1], %w[api_discovery]
        end

        context 'as a branch pipeline on a feature branch' do
          include_context 'with feature branch pipeline setup'

          include_examples 'common pipeline checks'
        end

        context 'as an MR pipeline' do
          include_context 'with MR pipeline setup'

          include_examples 'has expected jobs', []

          context 'when AST_ENABLE_MR_PIPELINES=true' do
            include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'true' }

            include_examples 'common pipeline checks'
          end
        end
      end
    end
  end
end
