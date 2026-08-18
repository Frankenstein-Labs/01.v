# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).dependencies', feature_category: :dependency_management do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:variables) { { full_path: project.full_path } }
  let_it_be(:fields) do
    <<~FIELDS
      id
      name
      version
      componentVersion {
        id
        version
      }
      packager
      location {
        blobPath
        path
      }
      licenses {
        name
        spdxIdentifier
        url
      }
    FIELDS
  end

  let(:query) { pagination_query }

  let!(:occurrences) { create_list(:sbom_occurrence, 5, project: project) }
  let(:nodes_path) { %i[project dependencies nodes] }

  def pagination_query(params = {})
    nodes = query_nodes(:dependencies, fields, include_pagination_info: true, args: params)
    graphql_query_for(:project, variables, nodes)
  end

  def package_manager_enum(value)
    Types::Sbom::PackageManagerEnum.values.find { |_, custom_value| custom_value.value == value }.first
  end

  before do
    stub_licensed_features(dependency_scanning: true, security_dashboard: true)
  end

  subject { post_graphql(query, current_user: current_user, variables: variables) }

  context 'with quarantine', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/545088' do
    it_behaves_like 'sbom dependency node'
  end

  it 'returns the expected dependency data with all fields' do
    subject

    actual = graphql_data_at(:project, :dependencies, :nodes)
    expected = occurrences.map do |occurrence|
      {
        'id' => occurrence.to_gid.to_s,
        'name' => occurrence.name,
        'version' => occurrence.version,
        'componentVersion' => {
          'id' => occurrence.component_version.to_gid.to_s,
          'version' => occurrence.component_version.version
        },
        'packager' => package_manager_enum(occurrence.packager),
        'location' => {
          'blobPath' => "/#{project.full_path}/-/blob/#{occurrence.commit_sha}/#{occurrence.source.input_file_path}",
          'path' => occurrence.source.input_file_path
        },
        'licenses' => occurrence.licenses.map do |license|
          {
            'name' => license['name'],
            'spdxIdentifier' => license['spdx_identifier'],
            'url' => license['url']
          }
        end
      }
    end

    expect(actual).to match_array(expected)
  end

  it_behaves_like 'when dependencies graphql query sorted paginated'
  it_behaves_like 'when dependencies graphql query sorted by license'

  context 'when dependencies have no source data' do
    let!(:occurrences) { create_list(:sbom_occurrence, 5, project: project, source: nil) }

    it 'returns nil for data which originates from a source' do
      subject

      actual = graphql_data_at(:project, :dependencies, :nodes)
      expected = occurrences.map do |occurrence|
        {
          'id' => occurrence.to_gid.to_s,
          'name' => occurrence.name,
          'version' => occurrence.version,
          'componentVersion' => {
            'id' => occurrence.component_version.to_gid.to_s,
            'version' => occurrence.component_version.version
          },
          'packager' => nil,
          'location' => {
            'blobPath' => nil,
            'path' => nil
          },
          'licenses' => occurrence.licenses.map do |license|
            {
              'name' => license['name'],
              'spdxIdentifier' => license['spdx_identifier'],
              'url' => license['url']
            }
          end
        }
      end

      expect(actual).to match_array(expected)
    end
  end

  context 'when dependencies have no version data' do
    let!(:occurrences) { create_list(:sbom_occurrence, 5, project: project, component_version: nil) }

    it 'returns a nil version' do
      subject

      actual = graphql_data_at(:project, :dependencies, :nodes)
      expected = occurrences.map do |occurrence|
        {
          'id' => occurrence.to_gid.to_s,
          'name' => occurrence.name,
          'version' => nil,
          'componentVersion' => nil,
          'packager' => package_manager_enum(occurrence.packager),
          'location' => {
            'blobPath' => "/#{project.full_path}/-/blob/#{occurrence.commit_sha}/#{occurrence.source.input_file_path}",
            'path' => occurrence.source.input_file_path
          },
          'licenses' => occurrence.licenses.map do |license|
            {
              'name' => license['name'],
              'spdxIdentifier' => license['spdx_identifier'],
              'url' => license['url']
            }
          end
        }
      end

      expect(actual).to match_array(expected)
    end
  end

  describe "hasDependencyPaths field" do
    let_it_be(:fields) do
      <<~FIELDS
        hasDependencyPaths
      FIELDS
    end

    it 'avoids N+1 database queries', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/567758' do
      parent = occurrences.first

      # create 1 occurrence and 1 graph path
      occ = create(:sbom_occurrence, project: project)
      create(:sbom_graph_path, descendant: occ, ancestor: parent, project: project)

      # capture control query count the current set of occurrences
      post_graphql(query, current_user: current_user, variables: variables)
      control_count = ActiveRecord::QueryRecorder.new do
        post_graphql(query, current_user: current_user, variables: variables)
      end.count

      # create multiple occurrences
      occurrence_list = create_list(:sbom_occurrence, 5, project: project)
      occurrence_list.each do |occ|
        create(:sbom_graph_path, descendant: occ, ancestor: parent, project: project)
      end

      expect do
        post_graphql(query, current_user: current_user, variables: variables)
      end.not_to exceed_query_limit(control_count)
    end
  end

  describe "trackedRefsCount field" do
    let_it_be(:fields) do
      <<~FIELDS
        id
        trackedRefsCount
      FIELDS
    end

    it 'returns the count of tracked refs for each dependency' do
      occurrence_with_refs = occurrences.first
      create_list(:sbom_occurrence_ref, 3, occurrence: occurrence_with_refs, project: project)

      subject

      actual = graphql_data_at(:project, :dependencies, :nodes)
      with_refs = actual.find { |node| node['id'] == occurrence_with_refs.to_gid.to_s }

      expect(with_refs['trackedRefsCount']).to eq(3)
    end

    it 'avoids N+1 database queries' do
      parent = occurrences.first
      create(:sbom_occurrence_ref, occurrence: parent, project: project)

      # capture control query count for the current set of occurrences
      post_graphql(query, current_user: current_user, variables: variables)
      control_count = ActiveRecord::QueryRecorder.new do
        post_graphql(query, current_user: current_user, variables: variables)
      end.count

      # create multiple occurrences, each with their own tracked ref
      occurrence_list = create_list(:sbom_occurrence, 5, project: project)
      occurrence_list.each do |occ|
        create(:sbom_occurrence_ref, occurrence: occ, project: project)
      end

      expect do
        post_graphql(query, current_user: current_user, variables: variables)
      end.not_to exceed_query_limit(control_count)
    end
  end

  it_behaves_like 'when dependencies graphql query filtered by component name'
  it_behaves_like 'when dependencies graphql query filtered by source type'
  it_behaves_like 'when dependencies graphql query sorted by severity'
  it_behaves_like 'when dependencies graphql query sorted by name'
  it_behaves_like 'when dependencies graphql query sorted by packager'
  it_behaves_like 'when dependencies graphql query filtered by component versions'
  it_behaves_like 'when dependencies graphql query filtered by not component versions'
  it_behaves_like 'when dependencies graphql query filtered by policy violations'

  describe 'policyViolations field on licenses' do
    let_it_be(:license_spdx) { 'MIT' }
    let_it_be(:another_license_spdx) { 'Apache-2.0' }
    let_it_be(:occurrence_with_dismissal) do
      create(:sbom_occurrence, project: project, licenses: [
        { 'name' => 'MIT License', 'spdx_identifier' => license_spdx, 'url' => 'https://opensource.org/licenses/MIT' }
      ])
    end

    let_it_be(:occurrence_without_dismissal) do
      create(:sbom_occurrence, project: project, licenses: [
        { 'name' => 'Apache License 2.0', 'spdx_identifier' => another_license_spdx, 'url' => 'https://www.apache.org/licenses/LICENSE-2.0' }
      ])
    end

    let_it_be(:merge_request) do
      create(:merge_request, target_project: project, source_project: project, source_branch: 'feature-dismissal')
    end

    let_it_be(:security_policy) { create(:security_policy, name: 'Test Security Policy') }

    let_it_be(:policy_dismissal) do
      create(:policy_dismissal,
        project: project,
        merge_request: merge_request,
        security_policy: security_policy,
        license_occurrence_uuids: [occurrence_with_dismissal.uuid],
        licenses: { 'MIT License' => [license_spdx] },
        status: :preserved)
    end

    let_it_be(:fields) do
      <<~FIELDS
        id
        name
        licenses {
          name
          spdxIdentifier
          policyViolations {
            id
            securityPolicy {
              id
              name
            }
          }
        }
      FIELDS
    end

    it 'returns policy dismissals for licenses' do
      subject

      actual = graphql_data_at(:project, :dependencies, :nodes)
      dependency_with_dismissal = actual.find { |node| node['id'] == occurrence_with_dismissal.to_gid.to_s }
      dependency_without_dismissal = actual.find { |node| node['id'] == occurrence_without_dismissal.to_gid.to_s }

      expect(dependency_with_dismissal['licenses'].first['policyViolations']).to contain_exactly(
        {
          'id' => policy_dismissal.to_gid.to_s,
          'securityPolicy' => {
            'id' => security_policy.to_gid.to_s,
            'name' => 'Test Security Policy'
          }
        }
      )

      expect(dependency_without_dismissal['licenses'].first['policyViolations']).to be_empty
    end

    context 'when multiple dismissals exist for the same license' do
      let_it_be(:another_merge_request) do
        create(:merge_request, target_project: project, source_project: project, source_branch: 'feature-another')
      end

      let_it_be(:another_security_policy) { create(:security_policy, name: 'Another Policy') }
      let_it_be(:another_policy_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: another_merge_request,
          security_policy: another_security_policy,
          license_occurrence_uuids: [occurrence_with_dismissal.uuid],
          licenses: { 'MIT License' => [license_spdx] },
          status: :preserved)
      end

      it 'returns all policy dismissals for the license' do
        subject

        actual = graphql_data_at(:project, :dependencies, :nodes)
        dependency_with_dismissal = actual.find { |node| node['id'] == occurrence_with_dismissal.to_gid.to_s }

        expect(dependency_with_dismissal['licenses'].first['policyViolations']).to contain_exactly(
          {
            'id' => policy_dismissal.to_gid.to_s,
            'securityPolicy' => {
              'id' => security_policy.to_gid.to_s,
              'name' => 'Test Security Policy'
            }
          },
          {
            'id' => another_policy_dismissal.to_gid.to_s,
            'securityPolicy' => {
              'id' => another_security_policy.to_gid.to_s,
              'name' => 'Another Policy'
            }
          }
        )
      end
    end

    context 'when dismissal has no security policy' do
      let_it_be(:mr_without_policy) do
        create(:merge_request, target_project: project, source_project: project, source_branch: 'feature-no-policy')
      end

      let_it_be(:dismissal_without_policy) do
        create(:policy_dismissal,
          project: project,
          merge_request: mr_without_policy,
          security_policy: nil,
          license_occurrence_uuids: [occurrence_without_dismissal.uuid],
          licenses: { 'Apache License 2.0' => [another_license_spdx] },
          status: :preserved)
      end

      it 'returns null for security policy fields' do
        subject

        actual = graphql_data_at(:project, :dependencies, :nodes)
        dependency = actual.find { |node| node['id'] == occurrence_without_dismissal.to_gid.to_s }

        expect(dependency['licenses'].first['policyViolations']).to contain_exactly(
          {
            'id' => dismissal_without_policy.to_gid.to_s,
            'securityPolicy' => nil
          }
        )
      end
    end

    context 'when dependency has multiple licenses with different dismissals' do
      let_it_be(:multi_license_occurrence) do
        create(:sbom_occurrence, project: project, licenses: [
          { 'name' => 'MIT License', 'spdx_identifier' => 'MIT', 'url' => 'https://opensource.org/licenses/MIT' },
          { 'name' => 'GPL-3.0', 'spdx_identifier' => 'GPL-3.0', 'url' => 'https://www.gnu.org/licenses/gpl-3.0.html' }
        ])
      end

      let_it_be(:mit_dismissal_mr) do
        create(:merge_request, target_project: project, source_project: project, source_branch: 'feature-mit')
      end

      let_it_be(:gpl_dismissal_mr) do
        create(:merge_request, target_project: project, source_project: project, source_branch: 'feature-gpl')
      end

      let_it_be(:mit_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: mit_dismissal_mr,
          security_policy: security_policy,
          license_occurrence_uuids: [multi_license_occurrence.uuid],
          licenses: { 'MIT License' => ['MIT'] },
          status: :preserved)
      end

      let_it_be(:gpl_dismissal) do
        create(:policy_dismissal,
          project: project,
          merge_request: gpl_dismissal_mr,
          security_policy: security_policy,
          license_occurrence_uuids: [multi_license_occurrence.uuid],
          licenses: { 'GPL-3.0' => ['GPL-3.0'] },
          status: :preserved)
      end

      it 'returns dismissals only for the matching license' do
        subject

        actual = graphql_data_at(:project, :dependencies, :nodes)
        dependency = actual.find { |node| node['id'] == multi_license_occurrence.to_gid.to_s }

        mit_license = dependency['licenses'].find { |l| l['name'] == 'MIT License' }
        gpl_license = dependency['licenses'].find { |l| l['name'] == 'GPL-3.0' }

        expect(mit_license['policyViolations']).to contain_exactly(
          {
            'id' => mit_dismissal.to_gid.to_s,
            'securityPolicy' => {
              'id' => security_policy.to_gid.to_s,
              'name' => 'Test Security Policy'
            }
          }
        )

        expect(gpl_license['policyViolations']).to contain_exactly(
          {
            'id' => gpl_dismissal.to_gid.to_s,
            'securityPolicy' => {
              'id' => security_policy.to_gid.to_s,
              'name' => 'Test Security Policy'
            }
          }
        )
      end
    end

    it 'avoids N+1 database queries' do
      2.times do |i|
        occ = create(:sbom_occurrence, project: project, licenses: [
          { 'name' => "License-#{i}", 'spdx_identifier' => "LIC-#{i}", 'url' => "https://example.com/license-#{i}" }
        ])
        mr = create(:merge_request,
          target_project: project,
          source_project: project,
          source_branch: "feature-n1-#{i}")
        create(:policy_dismissal,
          project: project,
          merge_request: mr,
          security_policy: security_policy,
          license_occurrence_uuids: [occ.uuid],
          licenses: { "License-#{i}" => ["LIC-#{i}"] },
          status: :preserved)
      end

      expect do
        post_graphql(query, current_user: current_user, variables: variables)
      end.not_to(
        exceed_query_limit(1).for_query(/SELECT "security_policy_dismissals"\.\* FROM "security_policy_dismissals"/)
      )
    end
  end

  describe 'trackedRefIds filter' do
    let_it_be(:tracked_context) { create(:security_project_tracked_context, project: project) }

    let(:query) do
      graphql_query_for(:project, variables,
        query_nodes(:dependencies, 'id', args: { tracked_ref_ids: [tracked_context.to_global_id] }))
    end

    context 'when vulnerabilities_across_contexts feature flag is disabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: false)
      end

      it 'returns an error' do
        subject

        expect_graphql_errors_to_include('The vulnerabilities_across_contexts feature flag is not enabled.')
      end
    end

    context 'when vulnerabilities_across_contexts feature flag is enabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: true)
      end

      it 'does not return an error' do
        subject

        expect_graphql_errors_to_be_empty
      end
    end
  end

  describe 'trackedRefsScope filter' do
    let(:query) do
      graphql_query_for(:project, variables,
        query_nodes(:dependencies, 'id', args: { tracked_refs_scope: :DEFAULT_BRANCHES }))
    end

    context 'when vulnerabilities_across_contexts feature flag is disabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: false)
      end

      it 'returns an error' do
        subject

        expect_graphql_errors_to_include('The vulnerabilities_across_contexts feature flag is not enabled.')
      end
    end

    context 'when vulnerabilities_across_contexts feature flag is enabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: true)
      end

      it 'does not return an error' do
        subject

        expect_graphql_errors_to_be_empty
      end
    end
  end

  describe 'malware field' do
    let_it_be(:fields) do
      <<~FIELDS
        id
        name
        malware
      FIELDS
    end

    before do
      stub_licensed_features(dependency_scanning: true, security_dashboard: true)
    end

    context 'when a dependency has a GLAM identifier' do
      before do
        vuln = create(:vulnerability, :with_finding, project: project)
        vuln.vulnerability_read.update!(identifier_names: ['GLAM-0001'])
        create(:sbom_occurrences_vulnerability, occurrence: occurrences.first, vulnerability: vuln)
      end

      it 'returns true' do
        post_graphql(query, current_user: current_user, variables: variables)

        node = graphql_data_at(:project, :dependencies, :nodes)
                 .find { |n| n['id'] == occurrences.first.to_gid.to_s }

        expect(node['malware']).to be true
      end
    end

    context 'when the feature flag is enabled and no GLAM identifier is present' do
      it 'returns false' do
        post_graphql(query, current_user: current_user, variables: variables)

        expect(graphql_data_at(:project, :dependencies, :nodes).first['malware']).to be false
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(dependency_malware_field_project: false)
      end

      it 'returns nil' do
        post_graphql(query, current_user: current_user, variables: variables)

        expect(graphql_data_at(:project, :dependencies, :nodes).first['malware']).to be_nil
      end
    end

    context 'when querying multiple dependencies' do
      before do
        occurrences.each do |occurrence|
          vuln = create(:vulnerability, :with_finding, project: project)
          vuln.vulnerability_read.update!(identifier_names: ['CVE-2021-1234'])
          create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vuln)
        end
      end

      it 'avoids N+1 database queries on vulnerability_reads' do
        create_list(:sbom_occurrence, 3, project: project).each do |occurrence|
          vuln = create(:vulnerability, :with_finding, project: project)
          vuln.vulnerability_read.update!(identifier_names: ['CVE-2021-1234'])
          create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vuln)
        end

        expect do
          post_graphql(query, current_user: current_user, variables: variables)
        end.not_to(
          exceed_query_limit(1).for_query(/SELECT "vulnerability_reads"\.\* FROM "vulnerability_reads"/)
        )
      end
    end
  end
end
