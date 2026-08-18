# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dependency-Scanning.v2.gitlab-ci.yml', feature_category: :software_composition_analysis do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('Jobs/Dependency-Scanning.v2') }

  describe 'the created pipeline' do
    let_it_be(:default_branch) { 'master' }
    let_it_be(:feature_branch) { 'patch-1' }
    let(:inputs) { {} }

    let(:pipeline) { service.execute(:push, inputs: inputs).payload }

    before do
      stub_ci_pipeline_yaml_file(template.content)
    end

    shared_examples 'runs expected jobs across all pipeline types' do |jobs|
      context 'as a branch pipeline on the default branch' do
        include_context 'with default branch pipeline setup'

        include_examples 'has expected jobs', jobs
      end

      context 'as a branch pipeline on a feature branch' do
        include_context 'with feature branch pipeline setup'

        include_examples 'has expected jobs', jobs
      end

      context 'as an MR pipeline' do
        include_context 'with MR pipeline setup'

        include_examples 'has expected jobs', jobs

        context 'when AST_ENABLE_MR_PIPELINES=false' do
          include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'false' }

          include_examples 'has expected jobs', []
        end
      end
    end

    context "with project type" do
      # Default behavior (DS_SKIP_IF_NO_SUPPORTED_FILES unset).
      # The rules:exists clause on the main dependency-scanning job is bypassed,
      # so the job runs unconditionally, unless other specific rules apply.
      context "when DS jobs always run (default)" do
        using RSpec::Parameterized::TableSyntax
        where(:case_name, :files, :variables, :inputs_hash, :jobs) do
          # rubocop:disable Layout/LineLength -- TableSyntax
          'Any'                                         | ['any.txt']                     | {}                                                                   | {}                                                            | %w[dependency-scanning]
          'Any, skip flag explicitly false'             | ['any.txt']                     | { 'DS_SKIP_IF_NO_SUPPORTED_FILES' => "false" }                       | {}                                                            | %w[dependency-scanning]
          'Java Gradle settings.gradle'                 | ['settings.gradle']             | {}                                                                   | {}                                                            | %w[dependency-scanning dependency-scanning:gradle-resolution]
          'Java Gradle settings.gradle.kts'             | ['settings.gradle.kts']         | {}                                                                   | {}                                                            | %w[dependency-scanning dependency-scanning:gradle-resolution]
          'Python requirements.in'                      | ['requirements.in']             | {}                                                                   | {}                                                            | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python with setup.cfg'                       | ['setup.cfg']                   | {}                                                                   | {}                                                            | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python with pyproject.toml'                  | ['pyproject.toml']              | {}                                                                   | {}                                                            | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python custom pipcompile lockfile'           | ['custom-lock.txt']             | { 'DS_PIPCOMPILE_LOCKFILE_FILE_NAME_PATTERN' => 'custom-lock.txt' }  | {}                                                            | %w[dependency-scanning]
          'Python custom manifest'                      | ['custom-requirements.txt']     | { 'DS_PIP_MANIFEST_FILE_NAME_PATTERN' => 'custom-requirements.txt' } | {}                                                            | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python custom requirements'                  | ['custom-requirements.txt']     | { 'PIP_REQUIREMENTS_FILE' => 'custom-requirements.txt' }             | {}                                                            | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python custom pipcompile lockfile via input' | ['custom-lock.txt']             | {}                                                                   | { pipcompile_lockfile_file_name_pattern: 'custom-lock.txt' }  | %w[dependency-scanning]
          'Python custom manifest via input'            | ['custom-requirements.txt']     | {}                                                                   | { pip_manifest_file_name_pattern: 'custom-requirements.txt' } | %w[dependency-scanning dependency-scanning:python-resolution]
          # rubocop:enable Layout/LineLength
        end

        with_them do
          let(:inputs) { inputs_hash }

          include_context 'when project has files', params[:files]
          include_context 'with CI variables', params[:variables], if: params[:variables].any?

          include_examples 'runs expected jobs across all pipeline types', params[:jobs]

          context 'when files exists in a subdirectory' do
            include_context 'when project has files', params[:files].map { |f| "submodule/#{f}" }
            include_context 'with default branch pipeline setup'

            include_examples 'has expected jobs', params[:jobs]
          end
        end
      end

      # Skip-flag behavior (DS_SKIP_IF_NO_SUPPORTED_FILES=true).
      # The rules:exists clause on the main dependency-scanning job is evaluated
      # against the project files using the .ds-supported-files glob in
      # lib/gitlab/ci/templates/Jobs/Dependency-Scanning.v2.gitlab-ci.yml.
      # Keep this table in sync with that glob.
      #
      # Note on edge cases (rows with empty :jobs):
      #   When the only matching files are resolution-trigger files NOT in the
      #   supported-files glob (e.g., settings.gradle only, or requirements.in only),
      #   the main job is excluded. The resolution job's own rules:exists still
      #   matches, but since it runs in .pre stage, a pipeline of only .pre jobs is
      #   rejected by GitLab as empty, so no jobs run.
      context "when DS_SKIP_IF_NO_SUPPORTED_FILES=true" do
        using RSpec::Parameterized::TableSyntax

        include_context 'with CI variables', { 'DS_SKIP_IF_NO_SUPPORTED_FILES' => 'true' }

        where(:case_name, :files, :extra_variables, :inputs_hash, :jobs) do
          # rubocop:disable Layout/LineLength -- TableSyntax
          'Any, no supported file'                      | ['any.txt']                     | {} | {} | %w[]
          'Multiple languages'                          | ['pom.xml', 'requirements.txt'] | {} | {} | %w[dependency-scanning dependency-scanning:maven-resolution dependency-scanning:python-resolution]
          'C# .csproj'                                  | ['MyProject.csproj']            | {} | {} | %w[dependency-scanning]
          'C# .vbproj'                                  | ['MyProject.vbproj']            | {} | {} | %w[dependency-scanning]
          'Cargo'                                       | ['Cargo.lock']                  | {} | {} | %w[dependency-scanning]
          'Conan'                                       | ['conan.lock']                  | {} | {} | %w[dependency-scanning]
          'Conda'                                       | ['conda-lock.yml']              | {} | {} | %w[dependency-scanning]
          'Dart'                                        | ['pubspec.lock']                | {} | {} | %w[dependency-scanning]
          'Go (go.mod)'                                 | ['go.mod']                      | {} | {} | %w[dependency-scanning]
          'Go (go.graph)'                               | ['go.graph']                    | {} | {} | %w[dependency-scanning]
          'Java Maven'                                  | ['pom.xml']                     | {} | {} | %w[dependency-scanning dependency-scanning:maven-resolution]
          'Java Maven maven.graph.json'                 | ['maven.graph.json']            | {} | {} | %w[dependency-scanning]
          'Java Gradle'                                 | ['build.gradle']                | {} | {} | %w[dependency-scanning dependency-scanning:gradle-resolution]
          'Java Gradle Kotlin DSL'                      | ['build.gradle.kts']            | {} | {} | %w[dependency-scanning dependency-scanning:gradle-resolution]
          'Java Gradle gradle.lockfile'                 | ['gradle.lockfile']             | {} | {} | %w[dependency-scanning]
          'Java Gradle dependencies-compile.dot'        | ['dependencies-compile.dot']    | {} | {} | %w[dependency-scanning]
          'Java Gradle dependencies.lock'               | ['dependencies.lock']           | {} | {} | %w[dependency-scanning]
          'Java Gradle settings.gradle only'            | ['settings.gradle']             | {} | {} | %w[] # see edge-case note above
          'Java Gradle settings.gradle.kts only'        | ['settings.gradle.kts']         | {} | {} | %w[] # see edge-case note above
          'Java Ivy'                                    | ['ivy-report.xml']              | {} | {} | %w[dependency-scanning]
          'JS package-lock.json'                        | ['package-lock.json']           | {} | {} | %w[dependency-scanning]
          'JS npm-shrinkwrap.json'                      | ['npm-shrinkwrap.json']         | {} | {} | %w[dependency-scanning]
          'JS yarn.lock'                                | ['yarn.lock']                   | {} | {} | %w[dependency-scanning]
          'JS pnpm-lock.yaml'                           | ['pnpm-lock.yaml']              | {} | {} | %w[dependency-scanning]
          'JS bun.lock'                                 | ['bun.lock']                    | {} | {} | %w[dependency-scanning]
          'PHP composer'                                | ['composer.lock']               | {} | {} | %w[dependency-scanning]
          'Python requirements.txt'                     | ['requirements.txt']            | {} | {} | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python requirements.pip'                     | ['requirements.pip']            | {} | {} | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python requires.txt'                         | ['requires.txt']                | {} | {} | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python with setup.py'                        | ['setup.py']                    | {} | {} | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python Pipfile'                              | ['Pipfile']                     | {} | {} | %w[dependency-scanning]
          'Python Pipfile.lock'                         | ['Pipfile.lock']                | {} | {} | %w[dependency-scanning]
          'Python pipenv.graph.json'                    | ['pipenv.graph.json']           | {} | {} | %w[dependency-scanning]
          'Python pipdeptree.json'                      | ['pipdeptree.json']             | {} | {} | %w[dependency-scanning]
          'Python poetry'                               | ['poetry.lock']                 | {} | {} | %w[dependency-scanning]
          'Python uv'                                   | ['uv.lock']                     | {} | {} | %w[dependency-scanning]
          'Python requirements.in only'                 | ['requirements.in']             | {} | {} | %w[] # see edge-case note above
          'Python setup.cfg only'                       | ['setup.cfg']                   | {} | {} | %w[] # see edge-case note above
          'Python pyproject.toml only'                  | ['pyproject.toml']              | {} | {} | %w[] # see edge-case note above
          'Python custom pipcompile lockfile'           | ['custom-lock.txt']             | { 'DS_PIPCOMPILE_LOCKFILE_FILE_NAME_PATTERN' => 'custom-lock.txt' }  | {} | %w[dependency-scanning]
          'Python custom manifest'                      | ['custom-requirements.txt']     | { 'DS_PIP_MANIFEST_FILE_NAME_PATTERN' => 'custom-requirements.txt' } | {} | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python custom requirements'                  | ['custom-requirements.txt']     | { 'PIP_REQUIREMENTS_FILE' => 'custom-requirements.txt' }             | {} | %w[dependency-scanning dependency-scanning:python-resolution]
          'Python custom pipcompile lockfile via input' | ['custom-lock.txt']             | {} | { pipcompile_lockfile_file_name_pattern: 'custom-lock.txt' }  | %w[dependency-scanning]
          'Python custom manifest via input'            | ['custom-requirements.txt']     | {} | { pip_manifest_file_name_pattern: 'custom-requirements.txt' } | %w[dependency-scanning dependency-scanning:python-resolution]
          'Ruby Gemfile.lock'                           | ['Gemfile.lock']                | {} | {} | %w[dependency-scanning]
          'Ruby gems.locked'                            | ['gems.locked']                 | {} | {} | %w[dependency-scanning]
          'Scala sbt'                                   | ['build.sbt']                   | {} | {} | %w[dependency-scanning]
          'Swift Package.resolved'                      | ['Package.resolved']            | {} | {} | %w[dependency-scanning]
          'Swift Podfile.lock'                          | ['Podfile.lock']                | {} | {} | %w[dependency-scanning]
          # rubocop:enable Layout/LineLength
        end

        with_them do
          let(:inputs) { inputs_hash }

          include_context 'when project has files', params[:files]
          include_context 'with CI variables', params[:extra_variables], if: params[:extra_variables].any?

          include_examples 'runs expected jobs across all pipeline types', params[:jobs]

          context 'when files exists in a subdirectory' do
            include_context 'when project has files', params[:files].map { |f| "submodule/#{f}" }
            include_context 'with default branch pipeline setup'

            include_examples 'has expected jobs', params[:jobs]
          end
        end
      end
    end

    describe "DEPENDENCY_SCANNING_DISABLED" do
      # Add necessary files to enable all analyzers jobs
      include_context 'when project has files', %w[pom.xml build.gradle requirements.txt]
      include_context 'with default branch pipeline setup'

      include_examples 'has jobs that can be disabled', 'DEPENDENCY_SCANNING_DISABLED', %w[true 1],
        %w[dependency-scanning dependency-scanning:maven-resolution dependency-scanning:gradle-resolution
          dependency-scanning:python-resolution]
    end

    context "when resolution jobs are disabled" do
      using RSpec::Parameterized::TableSyntax
      include_context 'when project has files', ["pom.xml", "requirements.txt", "build.gradle"]
      include_context 'with default branch pipeline setup'

      where(:case_name, :disabled_resolution_jobs, :jobs) do
        # rubocop:disable Layout/LineLength -- TableSyntax
        'default'       | ''              | %w[dependency-scanning dependency-scanning:maven-resolution dependency-scanning:python-resolution dependency-scanning:gradle-resolution]
        'maven'         | 'maven'         | %w[dependency-scanning dependency-scanning:python-resolution dependency-scanning:gradle-resolution]
        'python'        | 'python'        | %w[dependency-scanning dependency-scanning:maven-resolution dependency-scanning:gradle-resolution]
        'gradle'        | 'gradle'        | %w[dependency-scanning dependency-scanning:maven-resolution dependency-scanning:python-resolution]
        'multiple jobs' | 'maven, python' | %w[dependency-scanning dependency-scanning:gradle-resolution]
        # rubocop:enable Layout/LineLength -- TableSyntax
      end

      with_them do
        context 'and input is specified' do
          let(:inputs) { { disabled_resolution_jobs: disabled_resolution_jobs } }

          include_examples 'has expected jobs', params[:jobs]
        end

        context 'and CI/CD variable is specified' do
          include_context 'with CI variables', { 'DS_DISABLED_RESOLUTION_JOBS' => params[:disabled_resolution_jobs] }

          include_examples 'has expected jobs', params[:jobs]
        end
      end
    end

    describe 'Dependency Scanning job' do
      include_context 'when project has files', ["any.file"]
      include_context 'with default branch pipeline setup'

      let(:ds_job) { pipeline.builds.find_by(name: 'dependency-scanning') }

      include_examples 'has expected image', 'dependency-scanning',
        'registry.gitlab.com/security-products/dependency-scanning:2'

      it 'has expected defaults', :aggregate_failures do
        expect(ds_job.stage).to eq('test')
        expect(ds_job.allow_failure).to be(true)
        expect(ds_job.options[:artifacts][:paths]).to contain_exactly(
          '**/gl-sbom-*.cdx.json', 'gl-dependency-scanning-report.json'
        )
        expect(ds_job.options[:artifacts][:reports]).to eq(
          cyclonedx: ['**/gl-sbom-*.cdx.json'],
          dependency_scanning: ['gl-dependency-scanning-report.json']
        )
      end

      context 'when job stage is specified' do
        let(:inputs) { { stage: 'build' } }

        it 'uses job stage from input' do
          expect(ds_job.stage).to eq('build')
        end
      end

      context 'when failure mode is specified' do
        let(:inputs) { { allow_failure: false } }

        it 'uses failure mode from input' do
          expect(ds_job.allow_failure).to be(false)
        end
      end

      context 'when job name is specified' do
        let(:inputs) { { job_name: 'dependency-scanning-1a' } }

        include_examples 'has expected jobs', %w[dependency-scanning-1a]
      end

      context 'when analyzer image is specified' do
        using RSpec::Parameterized::TableSyntax

        where do
          {
            'set prefix input' => {
              variables: {},
              inputs: {
                analyzer_image_prefix: 'registry.example.com'
              },
              expected_analyzer_image: 'registry.example.com/dependency-scanning:2'
            },
            'set name input' => {
              variables: {},
              inputs: {
                analyzer_image_name: 'foo'
              },
              expected_analyzer_image: 'registry.gitlab.com/security-products/foo:2'
            },
            'set version input' => {
              variables: {},
              inputs: {
                analyzer_image_version: '0'
              },
              expected_analyzer_image: 'registry.gitlab.com/security-products/dependency-scanning:0'
            },
            'set all inputs' => {
              variables: {},
              inputs: {
                analyzer_image_prefix: 'registry.example.com/security',
                analyzer_image_name: 'bar',
                analyzer_image_version: 'v9.8.7'
              },
              expected_analyzer_image: 'registry.example.com/security/bar:v9.8.7'
            },
            'SECURE_ANALYZERS_PREFIX is set' => {
              variables: {
                SECURE_ANALYZERS_PREFIX: "registry.other.com/appsec-team"
              },
              inputs: {
                analyzer_image_name: 'bar',
                analyzer_image_version: 'v9.8.7'
              },
              expected_analyzer_image: 'registry.other.com/appsec-team/bar:v9.8.7'
            },
            'DS_ANALYZER_IMAGE is set' => {
              variables: {
                DS_ANALYZER_IMAGE: "my-analyzer-image"
              },
              inputs: {},
              expected_analyzer_image: 'my-analyzer-image'
            }
          }
        end

        with_them do
          include_context 'with CI variables', params[:variables]

          include_examples 'has expected image', 'dependency-scanning', params[:expected_analyzer_image]
        end
      end

      context "when options for DS analyzer are set" do
        using RSpec::Parameterized::TableSyntax

        where(:variable_name, :input_name, :input_value) do
          'ADDITIONAL_CA_CERT_BUNDLE' | :additional_ca_cert_bundle | 'ANOTHER PEM CERTIFICATE'
          'DS_PIPCOMPILE_REQUIREMENTS_FILE_NAME_PATTERN' | :pipcompile_requirements_file_name_pattern | '**/*.txt'
          'DS_PIPCOMPILE_LOCKFILE_FILE_NAME_PATTERN' | :pipcompile_lockfile_file_name_pattern | '**/*.txt'
          'DS_PIP_MANIFEST_FILE_NAME_PATTERN' | :pip_manifest_file_name_pattern | '**/*.txt'
          'DS_MAX_DEPTH' | :max_scan_depth | 5
          'DS_EXCLUDED_PATHS' | :excluded_paths | '**/custom'
          'DS_INCLUDE_DEV_DEPENDENCIES' | :include_dev_dependencies | false
          'DS_STATIC_REACHABILITY_ENABLED' | :enable_static_reachability | true
          'SECURE_LOG_LEVEL' | :analyzer_log_level | 'debug'
          'DS_ENABLE_VULNERABILITY_SCAN' | :enable_vulnerability_scan | false
          'DS_API_TIMEOUT' | :vulnerability_scan_api_timeout | 20
          'DS_API_SCAN_DOWNLOAD_DELAY' | :vulnerability_scan_api_download_delay | 5
          'DS_ENABLE_MANIFEST_FALLBACK' | :enable_manifest_fallback | true
        end

        with_them do
          let(:inputs) { { input_name => input_value } }

          it 'sets the variable in the script with the input value if not already set' do
            script = ds_job.options[:script].join("\n")
            expect(script).to include("export #{variable_name}=\"${#{variable_name}:-#{input_value}}\"")
          end
        end
      end
    end

    shared_examples 'configures resolution job' do |job_name, project_type, artifact_pattern, default_image|
      let(:resolution_job) { pipeline.builds.find_by(name: job_name) }

      include_examples 'has expected image', job_name, default_image

      it 'has expected defaults', :aggregate_failures do
        expect(resolution_job.stage).to eq('.pre')
        expect(resolution_job.allow_failure).to be(true)
        expect(resolution_job.options[:artifacts][:paths]).to contain_exactly(artifact_pattern)
        expect(resolution_job.options[:artifacts][:when]).to eq('always')
      end

      it 'configures the DS analyzer service', :aggregate_failures do
        service = resolution_job.options[:services].first

        expect(service[:name]).to eq('$DS_ANALYZER_IMAGE')
        expect(service[:alias]).to eq('ds-analyzer')
        expect(service[:command]).to eq(['/analyzer', 'dependency-resolution-service', '--project-types', project_type])
      end

      context 'when resolution job stage is specified' do
        let(:inputs) { { resolution_jobs_stage: 'build' } }

        it 'uses job stage from input' do
          expect(resolution_job.stage).to eq('build')
        end
      end

      context 'when resolution job failure mode is specified' do
        let(:inputs) { { resolution_jobs_allow_failure: false } }

        it 'uses failure mode from input' do
          expect(resolution_job.allow_failure).to be(false)
        end
      end

      context 'when resolution job name is specified' do
        let(:inputs) { { "#{project_type}_resolution_job_name": 'custom-resolution-job-name' } }

        include_examples 'has expected jobs', %w[dependency-scanning custom-resolution-job-name]
      end

      context "when resolution image is specified" do
        using RSpec::Parameterized::TableSyntax

        where do
          {
            'image input is set' => {
              variables: {},
              inputs: {
                "#{project_type}_resolution_image": 'registry.example.com/custom:latest'
              },
              expected_image: 'registry.example.com/custom:latest'
            },
            "image variable is set" => {
              variables: {
                "DS_#{project_type.upcase}_RESOLUTION_IMAGE": 'my-custom-image'
              },
              inputs: {},
              expected_image: 'my-custom-image'
            }
          }
        end

        with_them do
          include_context 'with CI variables', params[:variables]

          include_examples 'has expected image', job_name, params[:expected_image]
        end
      end
    end

    describe 'Maven resolution job' do
      include_context 'when project has files', ["pom.xml"]
      include_context 'with default branch pipeline setup'

      include_examples 'configures resolution job',
        'dependency-scanning:maven-resolution', 'maven', '**/maven.graph.json',
        'registry.gitlab.com/security-products/dependency-resolution/ubi9/openjdk-21:1'

      context "when options for DS analyzer service are set" do
        using RSpec::Parameterized::TableSyntax

        let(:maven_job) { pipeline.builds.find_by(name: 'dependency-scanning:maven-resolution') }

        where(:variable_name, :input_name, :input_value) do
          'ADDITIONAL_CA_CERT_BUNDLE' | :additional_ca_cert_bundle | 'ANOTHER PEM CERTIFICATE'
          'DS_MAX_DEPTH' | :max_scan_depth | 5
          'DS_EXCLUDED_PATHS' | :excluded_paths | '**/custom'
          'DS_INCLUDE_DEV_DEPENDENCIES' | :include_dev_dependencies | false
          'SECURE_LOG_LEVEL' | :analyzer_log_level | 'debug'
          'DS_MAVEN_DEPENDENCY_PLUGIN_VERSION' | :maven_dependency_plugin_version | '3.8.0'
          'MAVEN_ARGS' | nil | nil
        end

        with_them do
          let(:inputs) { input_name.present? ? { input_name => input_value } : {} }

          it 'sets the variable with the input value if not already set, and export it for the service container' do
            script = maven_job.options[:script].join("\n")
            expect(script).to include("export #{variable_name}=\"${#{variable_name}:-#{input_value}}\"") if input_name
            expect(String(maven_job.variables.to_hash['DS_MAVEN_RESOLUTION_EXPORTED_VARS']))
              .to match(/\b#{variable_name}\b/)
          end
        end

        it 'MAVEN_ARGS fallback to the legacy variable MAVEN_CLI_OPTS' do
          script = maven_job.options[:script].join("\n")
          expect(script).to include("export MAVEN_ARGS=\"${MAVEN_ARGS:-$MAVEN_CLI_OPTS}\"")
        end
      end
    end

    describe 'Python resolution job' do
      include_context 'when project has files', ["requirements.txt"]
      include_context 'with default branch pipeline setup'

      include_examples 'configures resolution job',
        'dependency-scanning:python-resolution', 'python', '**/pipcompile.lock.txt',
        'registry.gitlab.com/security-products/dependency-resolution/ubi9/python-312-minimal-with-piptools-7:9'

      context "when options for DS analyzer service are set" do
        using RSpec::Parameterized::TableSyntax

        where(:variable_name, :input_name, :input_value) do
          # rubocop:disable Layout/LineLength -- TableSyntax
          'ADDITIONAL_CA_CERT_BUNDLE' | :additional_ca_cert_bundle | 'ANOTHER PEM CERTIFICATE'
          'DS_PIPCOMPILE_REQUIREMENTS_FILE_NAME_PATTERN' | :pipcompile_requirements_file_name_pattern | 'some-*-requirement.txt'
          'DS_PIPCOMPILE_LOCKFILE_FILE_NAME_PATTERN' | :pipcompile_lockfile_file_name_pattern | '**/*.txt'
          'DS_PIP_MANIFEST_FILE_NAME_PATTERN' | :pip_manifest_file_name_pattern | '**/*.txt'
          'DS_PIP_DEPENDENCY_PATH' | nil | nil
          'PIP_REQUIREMENTS_FILE' | nil | nil
          'DS_MAX_DEPTH' | :max_scan_depth | 5
          'DS_EXCLUDED_PATHS' | :excluded_paths | '**/custom'
          'DS_INCLUDE_DEV_DEPENDENCIES' | :include_dev_dependencies | false
          'SECURE_LOG_LEVEL' | :analyzer_log_level | 'debug'
          # rubocop:enable Layout/LineLength -- TableSyntax
        end

        with_them do
          let(:inputs) { input_name.present? ? { input_name => input_value } : {} }
          let(:python_job) { pipeline.builds.find_by(name: 'dependency-scanning:python-resolution') }

          it 'sets the variable with the input value if not already set, and export it for the service container' do
            script = python_job.options[:script].join("\n")
            expect(script).to include("export #{variable_name}=\"${#{variable_name}:-#{input_value}}\"") if input_name
            expect(String(python_job.variables.to_hash['DS_PYTHON_RESOLUTION_EXPORTED_VARS']))
              .to match(/\b#{variable_name}\b/)
          end
        end
      end
    end

    describe 'Gradle resolution job' do
      include_context 'when project has files', ["build.gradle"]
      include_context 'with default branch pipeline setup'

      include_examples 'configures resolution job',
        'dependency-scanning:gradle-resolution', 'gradle', '**/gradle.graph.txt',
        'registry.gitlab.com/security-products/dependency-resolution/ubi9/openjdk-17-with-gradle-8:1'

      context "when options for DS analyzer service are set" do
        using RSpec::Parameterized::TableSyntax

        let(:gradle_job) { pipeline.builds.find_by(name: 'dependency-scanning:gradle-resolution') }

        where(:variable_name, :input_name, :input_value) do
          'ADDITIONAL_CA_CERT_BUNDLE' | :additional_ca_cert_bundle | 'ANOTHER PEM CERTIFICATE'
          'DS_MAX_DEPTH' | :max_scan_depth | 5
          'DS_EXCLUDED_PATHS' | :excluded_paths | '**/custom'
          'DS_INCLUDE_DEV_DEPENDENCIES' | :include_dev_dependencies | false
          'SECURE_LOG_LEVEL' | :analyzer_log_level | 'debug'
          'GRADLE_CLI_OPTS' | nil | nil
        end

        with_them do
          let(:inputs) { input_name.present? ? { input_name => input_value } : {} }

          it 'sets the variable with the input value if not already set, and export it for the service container' do
            script = gradle_job.options[:script].join("\n")
            expect(script).to include("export #{variable_name}=\"${#{variable_name}:-#{input_value}}\"") if input_name
            expect(String(gradle_job.variables.to_hash['DS_GRADLE_RESOLUTION_EXPORTED_VARS']))
              .to match(/\b#{variable_name}\b/)
          end
        end
      end
    end
  end
end
