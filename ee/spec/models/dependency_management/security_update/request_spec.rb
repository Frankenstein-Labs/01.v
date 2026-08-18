# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::Request, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }

  let_it_be(:vulnerability) do
    create(:vulnerability, :with_finding, :detected, project: project, report_type: :dependency_scanning)
  end

  let_it_be(:sbom_occurrence) do
    create(:sbom_occurrence,
      project: project,
      package_manager: 'bundler',
      input_file_path: 'Gemfile',
      component_name: 'rails'
    ).tap { |o| o.component_version.update!(version: '6.0.0') }
  end

  let(:target_ref) { nil }

  subject(:request) do
    described_class.new(
      sbom_occurrence: sbom_occurrence,
      vulnerability: vulnerability,
      target_ref: target_ref
    )
  end

  describe '#initialize' do
    context 'with an explicit target_ref' do
      let(:target_ref) { 'feature-branch' }

      it 'uses the provided target_ref' do
        expect(request.target_ref).to eq('feature-branch')
      end
    end

    context 'without a target_ref' do
      before do
        allow(project).to receive(:default_branch).and_return('main')
      end

      it 'defaults to the project default branch' do
        expect(request.target_ref).to eq('main')
      end
    end

    context 'when sbom_occurrence is nil' do
      let(:sbom_occurrence) { nil }

      it 'raises ArgumentError' do
        expect { request }.to raise_error(ArgumentError, 'sbom_occurrence is required')
      end
    end

    context 'when vulnerability is nil' do
      let(:vulnerability) { nil }

      it 'raises ArgumentError' do
        expect { request }.to raise_error(ArgumentError, 'vulnerability is required')
      end
    end

    context 'when sbom_occurrence and vulnerability do not belong to the same project' do
      before do
        allow(vulnerability).to receive(:project_id).and_return(sbom_occurrence.project_id + 1)
      end

      it 'raises ArgumentError' do
        expect { request }.to raise_error(ArgumentError,
          'vulnerability and sbom_occurrence must belong to the same project')
      end
    end
  end

  describe 'delegated attributes' do
    it 'exposes the expected sbom_occurrence attributes' do
      aggregate_failures do
        expect(request.sbom_occurrence).to eq(sbom_occurrence)
        expect(request.ecosystem).to eq('bundler')
        expect(request.filepath).to eq('Gemfile')
        expect(request.dependency).to eq('rails')
        expect(request.current_version).to eq('6.0.0')
      end
    end

    it 'exposes the vulnerability' do
      expect(request.vulnerability).to eq(vulnerability)
    end
  end

  describe 'source branch name generation' do
    using RSpec::Parameterized::TableSyntax

    # Eligibility::SUPPORTED_PACKAGE_MANAGERS lists 13 package managers, but they
    # collapse onto these 5 purl types: gradle shares maven,
    # pip/pipenv/poetry/setuptools/uv share pypi, and npm/yarn/pnpm/bun share npm.
    where(:purl_type, :dep_name, :version, :expected_branch) do
      # gem (bundler)
      :gem    | 'rails'                    | '6.0.0'                | 'dependency-management/rails-6.x'
      :gem    | 'rails'                    | '7.0.0.beta1'          | 'dependency-management/rails-7.x'
      :gem    | 'nokogiri'                 | '2.6.14.3'             | 'dependency-management/nokogiri-2.x'
      :gem    | 'rails'                    | 'abc123'               | 'dependency-management/rails-0.x'
      # npm (npm, yarn, pnpm, bun)
      :npm    | '@scope/my-pkg'            | '1.2.3'                | 'dependency-management/scope-my-pkg-1.x'
      :npm    | 'lodash'                   | '4.17.21'              | 'dependency-management/lodash-4.x'
      :npm    | 'ws'                       | '7.0.0-beta.3'         | 'dependency-management/ws-7.x'
      :npm    | 'left-pad'                 | '0.1.0'                | 'dependency-management/left-pad-0.x'
      # pypi (pip, pipenv, poetry, setuptools, uv)
      :pypi   | 'requests'                 | '2.31.0'               | 'dependency-management/requests-2.x'
      :pypi   | 'django'                   | '4.0.0rc1'             | 'dependency-management/django-4.x'
      :pypi   | 'urllib3'                  | '2.0.0.post1'          | 'dependency-management/urllib3-2.x'
      # PEP 440 epochs are not valid semver, so this exercises the fallback path
      :pypi   | 'urllib3'                  | '1!2.0.0'              | 'dependency-management/urllib3-1.x'
      # maven (maven, gradle)
      :maven  | 'com.example:widget'       | '2.0.0-M1'             | 'dependency-management/com-example-widget-2.x'
      :maven  | 'com.example:widget'       | '1.2.3-SNAPSHOT'       | 'dependency-management/com-example-widget-1.x'
      :maven  | 'org.springframework:spring-core' | '5.3.0.RELEASE' |
        'dependency-management/org-springframework-spring-core-5.x'
      # date-style Maven versions are legal and really do yield a huge major
      :maven  | 'commons-collections:commons-collections' | '20030203.000550' |
        'dependency-management/commons-collections-commons-collections-20030203.x'
      # single-segment versions are only resolved correctly by semver_dialects >= 4.1.3
      :maven  | 'javax.inject:javax.inject' | '1'         | 'dependency-management/javax-inject-javax-inject-1.x'
      # golang (go)
      :golang | 'github.com/moby/term'     | 'v0.5.2'               | 'dependency-management/github-com-moby-term-0.x'
      :golang | 'gopkg.in/yaml.v2'         | 'v2.2.2'               | 'dependency-management/gopkg-in-yaml-v2-2.x'
      :golang | 'github.com/docker/docker' | 'v28.5.2+incompatible' |
        'dependency-management/github-com-docker-docker-28.x'
      :golang | 'github.com/gorilla/websocket' | 'v1.4.0'           |
        'dependency-management/github-com-gorilla-websocket-1.x'
      :golang | 'golang.org/x/net' | 'v0.0.0-20210220032951-036812b2e83c' |
        'dependency-management/golang-org-x-net-0.x'
    end

    with_them do
      let(:component) { create(:sbom_component, purl_type: purl_type, name: dep_name) }

      let(:sbom_occurrence) do
        create(:sbom_occurrence,
          project: project,
          component_name: dep_name,
          component_version: create(:sbom_component_version, component: component, version: version)
        )
      end

      it 'generates the correct target branch name' do
        expect(request.source_ref).to eq(expected_branch)
      end
    end
  end
end
