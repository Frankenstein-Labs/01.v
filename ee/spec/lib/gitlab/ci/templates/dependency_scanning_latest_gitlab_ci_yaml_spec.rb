# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dependency-Scanning.latest.gitlab-ci.yml', feature_category: :software_composition_analysis do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('Jobs/Dependency-Scanning.latest') }

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

      describe "Analyzer images" do
        using RSpec::Parameterized::TableSyntax

        # Add necessary files to enable all analyzers jobs
        include_context 'when project has files', %w[Gemfile.lock pom.xml poetry.lock Cargo.lock]
        include_context 'with default branch pipeline setup'

        context "with default config" do
          where(:job, :image) do
            'gemnasium-dependency_scanning'         | 'registry.gitlab.com/security-products/gemnasium:6'
            'gemnasium-maven-dependency_scanning'   | 'registry.gitlab.com/security-products/gemnasium-maven:6'
            'gemnasium-python-dependency_scanning'  | 'registry.gitlab.com/security-products/gemnasium-python:6'
            'dependency-scanning'                   | 'registry.gitlab.com/security-products/dependency-scanning:2'
          end

          with_them do
            include_examples 'has expected image', params[:job], params[:image]
          end
        end

        context 'when SECURE_ANALYZERS_PREFIX is set' do
          include_context 'with CI variables', { 'SECURE_ANALYZERS_PREFIX' => 'my.custom-registry' }

          include_examples 'uses SECURE_ANALYZERS_PREFIX',
            %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning
              dependency-scanning]
        end
      end

      describe "DS_EXCLUDED_ANALYZERS" do
        using RSpec::Parameterized::TableSyntax
        # Add necessary files to enable all analyzers jobs
        include_context 'when project has files', %w[Gemfile.lock pom.xml poetry.lock Cargo.lock]
        include_context 'with default branch pipeline setup'

        where(:case_name, :excluded_analyzers, :jobs) do
          # rubocop:disable Layout/LineLength -- TableSyntax
          'default'             | ''                            | %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning dependency-scanning]
          'gemnasium'           | 'gemnasium'                   | %w[gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning dependency-scanning]
          'gemnasium-maven'     | 'gemnasium-maven'             | %w[gemnasium-dependency_scanning gemnasium-python-dependency_scanning dependency-scanning]
          'gemnasium-python'    | 'gemnasium-python'            | %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning dependency-scanning]
          'dependency-scanning' | 'dependency-scanning'         | %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning gemnasium-python-dependency_scanning]
          'multiple analyzers'  | 'gemnasium, gemnasium-python' | %w[gemnasium-maven-dependency_scanning dependency-scanning]
          # rubocop:enable Layout/LineLength
        end

        with_them do
          include_context 'with CI variables', { 'DS_EXCLUDED_ANALYZERS' => params[:excluded_analyzers] }

          include_examples 'has expected jobs', params[:jobs]
        end
      end

      describe "DEPENDENCY_SCANNING_DISABLED" do
        # Add necessary files to enable all analyzers jobs
        include_context 'when project has files', %w[Gemfile.lock pom.xml poetry.lock Cargo.lock]
        include_context 'with default branch pipeline setup'

        include_examples 'has jobs that can be disabled', 'DEPENDENCY_SCANNING_DISABLED', %w[true 1],
          %w[gemnasium-dependency_scanning gemnasium-maven-dependency_scanning
            gemnasium-python-dependency_scanning dependency-scanning]
      end

      describe "FIPS mode" do
        # Add necessary files to enable all analyzers jobs
        # FIPS mode does not affect the new DS analyzer job (dependency-scanning)
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

      describe "DS_ENFORCE_NEW_ANALYZER" do
        # Add necessary files to enable the new DS analyzer
        include_context 'when project has files', %w[Cargo.lock]
        include_context 'with default branch pipeline setup'

        context 'when new DS analyzer is not enforced' do
          it "only scans the newly supported files and ignores project types already supported by Gemnasium" do
            new_ds_build = pipeline.builds.find { |b| b.name == 'dependency-scanning' }
            expect(String(new_ds_build.variables.to_hash['DS_EXCLUDED_PATHS']))
              .to eql(
                'spec, test, tests, tmp, node_modules, ' \
                  '**/build.gradle, **/build.gradle.kts, **/build.sbt, **/pom.xml, ' \
                  '**/requirements.txt, **/requirements.pip, **/Pipfile, **/Pipfile.lock, **/requires.txt, ' \
                  '**/setup.py, **/poetry.lock, **/uv.lock, **/packages.lock.json, **/conan.lock, ' \
                  '**/package-lock.json, **/npm-shrinkwrap.json, **/pnpm-lock.yaml, **/yarn.lock, **/composer.lock, ' \
                  '**/Gemfile.lock, **/gems.locked, **/go.graph, **/ivy-report.xml, **/maven.graph.json, ' \
                  '**/dependencies.lock, **/pipdeptree.json, **/pipenv.graph.json, **/dependencies-compile.dot')
          end
        end

        context 'when new DS analyzer is enforced' do
          include_context 'with CI variables', { 'DS_ENFORCE_NEW_ANALYZER' => 'true' }

          it "scans all supported files" do
            new_ds_build = pipeline.builds.find { |b| b.name == 'dependency-scanning' }
            expect(String(new_ds_build.variables.to_hash['DS_EXCLUDED_PATHS'])).to eql(
              'spec, test, tests, tmp, node_modules')
          end
        end
      end

      context "with project type" do
        using RSpec::Parameterized::TableSyntax
        where(:case_name, :files, :variables, :jobs) do
          # rubocop:disable Layout/LineLength -- TableSyntax
          'Go'                             | ['go.sum']                       | {} | %w[gemnasium-dependency_scanning]
          'Go (nested)'                    | ['a/b/go.sum']                   | {} | %w[gemnasium-dependency_scanning]
          'Java'                           | ['pom.xml']                      | {} | %w[gemnasium-maven-dependency_scanning]
          'Java Gradle'                    | ['build.gradle']                 | {} | %w[gemnasium-maven-dependency_scanning]
          'Java Gradle Kotlin DSL'         | ['build.gradle.kts']             | {} | %w[gemnasium-maven-dependency_scanning]
          'Javascript package-lock.json'   | ['package-lock.json']            | {} | %w[gemnasium-dependency_scanning]
          'Javascript yarn.lock'           | ['yarn.lock']                    | {} | %w[gemnasium-dependency_scanning]
          'Javascript pnpm-lock.yaml'      | ['pnpm-lock.yaml']               | {} | %w[gemnasium-dependency_scanning]
          'Javascript npm-shrinkwrap.json' | ['npm-shrinkwrap.json']          | {} | %w[gemnasium-dependency_scanning]
          'Multiple languages'             | ['pom.xml', 'package-lock.json'] | {} | %w[gemnasium-maven-dependency_scanning gemnasium-dependency_scanning]
          'NuGet'                          | ['packages.lock.json']           | {} | %w[gemnasium-dependency_scanning]
          'Conan'                          | ['conan.lock']                   | {} | %w[gemnasium-dependency_scanning]
          'PHP'                            | ['composer.lock']                | {} | %w[gemnasium-dependency_scanning]
          'Python requirements.txt'        | ['requirements.txt']             | {} | %w[gemnasium-python-dependency_scanning]
          'Python custom file'             | ['custom-req.txt']               | { 'PIP_REQUIREMENTS_FILE' => 'custom-req.txt' } | %w[gemnasium-python-dependency_scanning]
          'Python requirements.pip'        | ['requirements.pip']             | {} | %w[gemnasium-python-dependency_scanning]
          'Python Pipfile'                 | ['Pipfile']                      | {} | %w[gemnasium-python-dependency_scanning]
          'Python requires.txt'            | ['requires.txt']                 | {} | %w[gemnasium-python-dependency_scanning]
          'Python with setup.py'           | ['setup.py']                     | {} | %w[gemnasium-python-dependency_scanning]
          'Python with poetry.lock'        | ['poetry.lock']                  | {} | %w[gemnasium-python-dependency_scanning]
          'Python with uv.lock'            | ['uv.lock']                      | {} | %w[gemnasium-python-dependency_scanning]
          'Ruby Gemfile.lock'              | ['Gemfile.lock']                 | {} | %w[gemnasium-dependency_scanning]
          'Ruby gems.locked'               | ['gems.locked']                  | {} | %w[gemnasium-dependency_scanning]
          'Scala'                          | ['build.sbt']                    | {} | %w[gemnasium-maven-dependency_scanning]
          # New languages supported by default by the new DS analyzer
          'Dart'                           | ['pubspec.lock']                 | {} | %w[dependency-scanning]
          'Objective-C Cocoapods'          | ['Podfile.lock']                 | {} | %w[dependency-scanning]
          'Conda'                          | ['conda-lock.yml']               | {} | %w[dependency-scanning]
          'Rust Cargo'                     | ['Cargo.lock']                   | {} | %w[dependency-scanning]
          'Swift'                          | ['Package.resolved']             | {} | %w[dependency-scanning]
          'Javascript Bun bun.lock'        | ['bun.lock']                     | {} | %w[dependency-scanning]
          # All languages enforced on the new DS analyzer
          'new DS analyzer - Go go.mod'                      | ['go.mod']                       | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Go go.mod (nested)'             | ['a/b/go.mod']                   | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Go go.graph'                    | ['go.graph']                     | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Java'                           | ['pom.xml']                      | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Java maven.graph.json'          | ['maven.graph.json']             | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Java Gradle'                    | ['build.gradle']                 | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Java Gradle Kotlin DSL'         | ['build.gradle.kts']             | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Java Gradle dependencies.lock'  | ['dependencies.lock']            | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Java Gradle gradle.lockfile'    | ['gradle.lockfile']              | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Javascript package-lock.json'   | ['package-lock.json']            | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Javascript yarn.lock'           | ['yarn.lock']                    | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Javascript pnpm-lock.yaml'      | ['pnpm-lock.yaml']               | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Javascript npm-shrinkwrap.json' | ['npm-shrinkwrap.json']          | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Javascript bun.lock'            | ['bun.lock']                     | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Multiple languages'             | ['pom.xml', 'package-lock.json'] | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - NuGet'                          | ['packages.lock.json']           | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - NuGet (csproj)'                 | ['my.csproj']                    | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - NuGet (vbproj)'                 | ['my.vbproj']                    | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Conan'                          | ['conan.lock']                   | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - PHP'                            | ['composer.lock']                | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python requirements.txt'        | ['requirements.txt']             | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python custom file'             | ['custom-req.txt']               | { 'DS_ENFORCE_NEW_ANALYZER' => 'true', 'DS_PIPCOMPILE_REQUIREMENTS_FILE_NAME_PATTERN' => 'custom-req.txt' } | %w[dependency-scanning]
          'new DS analyzer - Python requirements.pip'        | ['requirements.pip']             | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python pipdeptree.json'         | ['pipdeptree.json']              | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python Pipfile'                 | ['Pipfile']                      | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python Pipfile.lock'            | ['Pipfile.lock']                 | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python pipenv.graph.json'       | ['pipenv.graph.json']            | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python requires.txt'            | ['requires.txt']                 | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python with setup.py'           | ['setup.py']                     | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python with poetry.lock'        | ['poetry.lock']                  | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Python with uv.lock'            | ['uv.lock']                      | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Ruby Gemfile.lock'              | ['Gemfile.lock']                 | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Ruby gems.locked'               | ['gems.locked']                  | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Scala'                          | ['build.sbt']                    | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Scala dependencies-compile.dot' | ['dependencies-compile.dot']     | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          'new DS analyzer - Ivy'                            | ['ivy-report.xml']               | { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } | %w[dependency-scanning]
          # Static Reachability
          'Static Reachability - Python ' | ['Pipfile'] | { 'DS_ENFORCE_NEW_ANALYZER' => 'true', 'DS_STATIC_REACHABILITY_ENABLED' => 'true' } | %w[dependency-scanning]
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

            include_examples 'has expected jobs', params[:jobs]

            context 'when AST_ENABLE_MR_PIPELINES=false' do
              include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'false' }

              include_examples 'has expected jobs', []
            end
          end
        end
      end
    end
  end
end
