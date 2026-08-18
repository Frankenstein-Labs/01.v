# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::JobBuilder, feature_category: :dependency_management do
  let_it_be(:namespace) { create(:namespace, path: 'my-group') }
  let_it_be(:project) { create(:project, path: 'my-project', namespace: namespace) }

  let(:sbom_component) { create(:sbom_component, purl_type: 'gem', name: 'rails') }

  let(:sbom_occurrence) do
    create(:sbom_occurrence,
      project: project,
      package_manager: 'bundler',
      input_file_path: 'Gemfile',
      component: sbom_component
    ).tap { |o| o.component_version&.update!(version: '6.0.0') }
  end

  let(:vulnerability) do
    create(:vulnerability, :with_finding, :detected, project: project, report_type: :dependency_scanning)
  end

  let(:request) do
    DependencyManagement::SecurityUpdate::Request.new(
      sbom_occurrence: sbom_occurrence,
      vulnerability: vulnerability
    )
  end

  let(:auto_remediation_configuration) { {} }

  subject(:builder) do
    described_class.new(
      request: request,
      project: project,
      auto_remediation_configuration: auto_remediation_configuration
    )
  end

  describe '#build' do
    it 'returns the expected job configuration hash' do
      expect(builder.build).to eq(
        'package-manager' => 'bundler',
        'source' => { 'repo' => 'my-group/my-project', 'directories' => ['/'] },
        'dependencies' => ['rails']
      )
    end

    context 'when a cooldown is configured' do
      let(:auto_remediation_configuration) { { cooldown: 7 } }

      it 'sets the default-days cooldown' do
        expect(builder.build['cooldown']).to eq('default-days' => 7)
      end
    end

    context 'when no cooldown is configured' do
      it 'omits the cooldown key' do
        expect(builder.build).not_to have_key('cooldown')
      end
    end

    context 'when mapping the upgrade policy to ignore-conditions' do
      using RSpec::Parameterized::TableSyntax

      context 'when the policy blocks certain update types' do
        where(:upgrade_policy, :expected_update_types) do
          'patch' | %w[version-update:semver-minor version-update:semver-major]
          'minor' | %w[version-update:semver-major]
        end

        with_them do
          let(:auto_remediation_configuration) { { upgrade_policy: upgrade_policy } }

          it 'sets the expected ignore-conditions' do
            expect(builder.build['ignore-conditions']).to eq(
              [{ 'dependency-name' => '*', 'update-types' => expected_update_types }]
            )
          end
        end
      end

      context 'when the policy does not block any update types' do
        where(:upgrade_policy) do
          ['major', nil]
        end

        with_them do
          let(:auto_remediation_configuration) { { upgrade_policy: upgrade_policy } }

          it 'omits the ignore-conditions key' do
            expect(builder.build).not_to have_key('ignore-conditions')
          end
        end
      end
    end

    context 'when filepath is in a subdirectory' do
      before do
        sbom_occurrence.update!(input_file_path: 'apps/backend/Gemfile')
      end

      it 'extracts the directory from the filepath' do
        expect(builder.build['source']['directories']).to eq(['/apps/backend'])
      end
    end

    context 'when filepath is blank' do
      before do
        sbom_occurrence.update!(input_file_path: nil)
      end

      it 'defaults to root directory' do
        expect(builder.build['source']['directories']).to eq(['/'])
      end
    end

    context 'when mapping the package manager to an orchestrator ecosystem' do
      using RSpec::Parameterized::TableSyntax

      where(:package_manager, :input_file_path, :expected_ecosystem) do
        'bundler'    | 'Gemfile'          | 'bundler'
        'maven'      | 'pom.xml'          | 'maven'
        'gradle'     | 'build.gradle'     | 'gradle'
        'pip'        | 'requirements.txt' | 'python'
        'pipenv'     | 'Pipfile'          | 'python'
        'poetry'     | 'pyproject.toml'   | 'python'
        'setuptools' | 'setup.py'         | 'python'
        'uv'         | 'uv.lock'          | 'uv'
        'npm'        | 'package.json'     | 'npm_and_yarn'
        'yarn'       | 'yarn.lock'        | 'npm_and_yarn'
        'pnpm'       | 'pnpm-lock.yaml'   | 'npm_and_yarn'
        'bun'        | 'bun.lock'         | 'bun'
        'go'         | 'go.mod'           | 'go_modules'
        'cargo'      | 'Cargo.toml'       | 'cargo'
      end

      with_them do
        before do
          sbom_occurrence.update!(package_manager: package_manager, input_file_path: input_file_path)
        end

        it 'sets the expected package-manager' do
          expect(builder.build['package-manager']).to eq(expected_ecosystem)
        end
      end
    end

    context 'when translating a Maven or Gradle component name' do
      using RSpec::Parameterized::TableSyntax

      where(:package_manager, :component_name, :expected_dependency) do
        'maven'  | 'org.apache.logging.log4j/log4j-core' | 'org.apache.logging.log4j:log4j-core'
        'gradle' | 'org.apache.logging.log4j/log4j-core' | 'org.apache.logging.log4j:log4j-core'
        'maven'  | 'com.google.guava/guava'              | 'com.google.guava:guava'
        'gradle' | 'com.google.guava/guava'              | 'com.google.guava:guava'
        'maven'  | 'standalone-artifact'                 | 'standalone-artifact'
      end

      with_them do
        before do
          sbom_component.update!(name: component_name, purl_type: 'maven')
          sbom_occurrence.update!(package_manager: package_manager)
        end

        it 'converts the namespace/name boundary to a colon, leaving names without one unchanged' do
          expect(builder.build['dependencies']).to eq([expected_dependency])
        end
      end
    end
  end

  describe '#to_json' do
    it 'returns valid JSON that matches the build hash' do
      parsed = ::Gitlab::Json.safe_parse(builder.to_json)

      expect(parsed).to eq(builder.build)
    end
  end
end
