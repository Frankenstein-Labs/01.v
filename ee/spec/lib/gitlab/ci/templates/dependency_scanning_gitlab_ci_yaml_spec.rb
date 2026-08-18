# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dependency-Scanning.gitlab-ci.yml', feature_category: :software_composition_analysis do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('Dependency-Scanning') }

  describe 'the created pipeline' do
    let_it_be(:default_branch) { 'master' }
    let_it_be(:feature_branch) { 'patch-1' }

    let(:pipeline) { service.execute(:push).payload }

    before do
      stub_ci_pipeline_yaml_file(template.content)
    end

    context 'when project has no license' do
      # Add necessary files to enable all analyzers jobs
      include_context 'when project has files', %w[Gemfile.lock pom.xml Poetry.lock]
      include_context 'with default branch pipeline setup'

      include_examples 'has expected jobs', []
    end

    context 'when project has Ultimate license' do
      let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      describe "DS_EXCLUDED_ANALYZERS" do
        using RSpec::Parameterized::TableSyntax
        # Add necessary files to enable all analyzers jobs
        include_context 'when project has files', %w[Gemfile.lock pom.xml poetry.lock]
        include_context 'with default branch pipeline setup'

        where(:case_name, :excluded_analyzers, :jobs) do
          # rubocop:disable Layout/LineLength -- TableSyntax
          'default'            | ''                            | %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning]
          'gemnasium'          | 'gemnasium'                   | %w[gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning]
          'gemnasium-maven'    | 'gemnasium-maven'             | %w[gemnasium-dependency_scanning gemnasium-python-dependency_scanning]
          'gemnasium-python'   | 'gemnasium-python'            | %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning]
          'multiple analyzers' | 'gemnasium, gemnasium-python' | %w[gemnasium-maven-dependency_scanning]
          # rubocop:enable Layout/LineLength
        end

        with_them do
          include_context 'with CI variables', { 'DS_EXCLUDED_ANALYZERS' => params[:excluded_analyzers] }

          include_examples 'has expected jobs', params[:jobs]
        end
      end

      describe "DEPENDENCY_SCANNING_DISABLED" do
        # Add necessary files to enable all analyzers jobs
        include_context 'when project has files', %w[Gemfile.lock pom.xml poetry.lock]
        include_context 'with default branch pipeline setup'

        include_examples 'has jobs that can be disabled', 'DEPENDENCY_SCANNING_DISABLED', %w[true 1],
          %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning]
      end

      describe "FIPS mode" do
        # Add necessary files to enable all analyzers jobs
        include_context 'when project has files', %w[Gemfile.lock pom.xml poetry.lock]

        context 'as a branch pipeline on the default branch' do
          include_context 'with default branch pipeline setup'

          include_examples 'has FIPS compatible jobs', 'DS_IMAGE_SUFFIX',
            %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning]
        end

        context 'as a branch pipeline on a feature branch' do
          include_context 'with feature branch pipeline setup'

          include_examples 'has FIPS compatible jobs', 'DS_IMAGE_SUFFIX',
            %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning]
        end

        context 'as an MR pipeline' do
          include_context 'with MR pipeline setup'
          include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'true' }

          include_examples 'has FIPS compatible jobs', 'DS_IMAGE_SUFFIX',
            %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning]
        end
      end

      describe "DS_REMEDIATE" do
        # Add necessary files to enable the analyzers compatible with Auto-Remediation (gemnasium only)
        include_context 'when project has files', %w[Gemfile.lock]

        context 'as a branch pipeline on the default branch' do
          include_context 'with default branch pipeline setup'

          let(:gemnasium_job) { pipeline.builds.find_by(name: 'gemnasium-dependency_scanning') }

          context 'when CI_GITLAB_FIPS_MODE=false', fips_mode: false do
            let(:expected) { '' }

            it 'sets DS_REMEDIATE to ""' do
              expect(String(gemnasium_job.variables.to_hash['DS_REMEDIATE'])).to eql(expected)
            end
          end

          context 'when CI_GITLAB_FIPS_MODE=true', :fips_mode do
            let(:expected) { 'false' }

            it 'sets DS_REMEDIATE to "false"' do
              expect(String(gemnasium_job.variables.to_hash['DS_REMEDIATE'])).to eql(expected)
            end
          end
        end
      end

      context "with project type" do
        using RSpec::Parameterized::TableSyntax
        where(:case_name, :files, :variables, :jobs) do
          # rubocop:disable Layout/LineLength -- TableSyntax
          'Go'                             | ['go.sum']                             | {} | %w[gemnasium-dependency_scanning]
          'Go (nested)'                    | ['a/b/go.sum']                         | {} | %w[gemnasium-dependency_scanning]
          'Java'                           | ['pom.xml']                            | {} | %w[gemnasium-maven-dependency_scanning]
          'Java Gradle'                    | ['build.gradle']                       | {} | %w[gemnasium-maven-dependency_scanning]
          'Java Gradle Kotlin DSL'         | ['build.gradle.kts']                   | {} | %w[gemnasium-maven-dependency_scanning]
          'Javascript package-lock.json'   | ['package-lock.json']                  | {} | %w[gemnasium-dependency_scanning]
          'Javascript yarn.lock'           | ['yarn.lock']                          | {} | %w[gemnasium-dependency_scanning]
          'Javascript pnpm-lock.yaml'      | ['pnpm-lock.yaml']                     | {} | %w[gemnasium-dependency_scanning]
          'Javascript npm-shrinkwrap.json' | ['npm-shrinkwrap.json']                | {} | %w[gemnasium-dependency_scanning]
          'Multiple languages'             | ['pom.xml', 'package-lock.json']       | {} | %w[gemnasium-maven-dependency_scanning gemnasium-dependency_scanning]
          'NuGet'                          | ['packages.lock.json']                 | {} | %w[gemnasium-dependency_scanning]
          'Conan'                          | ['conan.lock']                         | {} | %w[gemnasium-dependency_scanning]
          'PHP'                            | ['composer.lock']                      | {} | %w[gemnasium-dependency_scanning]
          'Python requirements.txt'        | ['requirements.txt']                   | {} | %w[gemnasium-python-dependency_scanning]
          'Python custom file'             | ['custom-req.txt']                     | { ' PIP_REQUIREMENTS_FILE' => 'custom-req.txt' } | %w[gemnasium-python-dependency_scanning]
          'Python requirements.pip'        | ['requirements.pip']                   | {} | %w[gemnasium-python-dependency_scanning]
          'Python Pipfile'                 | ['Pipfile']                            | {} | %w[gemnasium-python-dependency_scanning]
          'Python requires.txt'            | ['requires.txt']                       | {} | %w[gemnasium-python-dependency_scanning]
          'Python with setup.py'           | ['setup.py']                           | {} | %w[gemnasium-python-dependency_scanning]
          'Python with poetry.lock'        | ['poetry.lock']                        | {} | %w[gemnasium-python-dependency_scanning]
          'Python with uv.lock'            | ['uv.lock']                            | {} | %w[gemnasium-python-dependency_scanning]
          'Ruby Gemfile.lock'              | ['Gemfile.lock']                       | {} | %w[gemnasium-dependency_scanning]
          'Ruby gems.locked'               | ['gems.locked']                        | {} | %w[gemnasium-dependency_scanning]
          'Scala'                          | ['build.sbt']                          | {} | %w[gemnasium-maven-dependency_scanning]
          # rubocop:enable Layout/LineLength
        end

        with_them do
          include_context 'when project has files', params[:files]
          include_context 'with CI variables', params[:variables], if: params[:variables].any?

          context 'as a branch pipeline on the default branch' do
            include_context 'with default branch pipeline setup'

            include_examples 'has expected jobs', params[:jobs]
          end

          context 'as a branch pipeline on a feature branch' do
            include_context 'with feature branch pipeline setup'

            include_examples 'has expected jobs', params[:jobs]
          end

          context 'as an MR pipeline' do
            include_context 'with MR pipeline setup'

            include_examples 'has expected jobs', []

            context 'when AST_ENABLE_MR_PIPELINES=true' do
              include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'true' }

              include_examples 'has expected jobs', params[:jobs]
            end
          end
        end
      end
    end
  end
end
