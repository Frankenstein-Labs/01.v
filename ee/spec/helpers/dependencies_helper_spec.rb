# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependenciesHelper, feature_category: :dependency_management do
  shared_examples 'a helper method that returns shared dependencies data' do
    it 'returns data shared between all views' do
      is_expected.to include(
        has_dependencies: 'false',
        documentation_path: a_string_including("user/application_security/dependency_list/_index"),
        empty_state_svg_path: match(%r{illustrations/empty-state/empty-radar-md.*\.svg})
      )
    end
  end

  describe '#project_dependencies_data' do
    let_it_be(:project) { build_stubbed(:project) }
    let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project) }

    let(:expected_sbom_reports_errors) { "[]" }
    let(:expectations) do
      {
        endpoint: "/#{project.full_path}/-/dependencies.json",
        licenses_endpoint: "/#{project.full_path}/-/dependencies/licenses",
        export_endpoint: "/api/v4/projects/#{project.id}/dependency_list_exports",
        sbom_reports_errors: expected_sbom_reports_errors,
        latest_successful_scan_path: "/#{project.full_path}/-/pipelines/#{pipeline.id}",
        scan_finished_at: pipeline.finished_at
      }
    end

    subject { helper.project_dependencies_data(project) }

    before do
      allow(project).to receive(:latest_ingested_sbom_pipeline).and_return(pipeline)
    end

    it_behaves_like 'a helper method that returns shared dependencies data'

    it 'returns the exepected data' do
      is_expected.to include(**expectations)
    end

    context 'with sbom reports errors' do
      let(:sbom_errors) { [["Unsupported CycloneDX spec version. Must be one of: 1.4, 1.5"]] }
      let(:expected_sbom_reports_errors) { sbom_errors.to_json }

      before do
        allow(pipeline).to receive(:sbom_report_ingestion_errors).and_return(sbom_errors)
      end

      it { is_expected.to include(**expectations) }
    end

    context 'when project does not have an sbom pipeline' do
      let_it_be(:pipeline) { nil }

      it 'returns nil values for pipeline keys' do
        is_expected.to include(
          latest_successful_scan_path: nil,
          scan_finished_at: nil
        )
      end
    end

    context 'with a default branch context' do
      let(:default_branch_context) do
        build_stubbed(:security_project_tracked_context, project: project, context_name: 'main', context_type: :branch)
      end

      before do
        allow(Security::ProjectTrackedContext).to receive(:find_default_branch_context).with(project)
          .and_return(default_branch_context)
      end

      it 'returns a default branch context' do
        is_expected.to include(
          default_branch_context: {
            id: default_branch_context.id.to_s,
            name: default_branch_context.context_name,
            ref_type: default_branch_context.context_type
          }.to_json)
      end

      context 'when VAC is disabled' do
        before do
          allow(Security::VAC).to receive(:enabled?).with(project).and_return(false)
        end

        it { is_expected.not_to include(:default_branch_context) }
      end
    end
  end

  describe '#group_dependencies_data' do
    let_it_be(:group) { build_stubbed(:group, traversal_ids: [1]) }

    subject { helper.group_dependencies_data(group) }

    it_behaves_like 'a helper method that returns shared dependencies data'

    it 'returns the expected data' do
      is_expected.to include(
        endpoint: "/groups/#{group.full_path}/-/dependencies.json",
        licenses_endpoint: "/groups/#{group.full_path}/-/dependencies/licenses",
        locations_endpoint: "/groups/#{group.full_path}/-/dependencies/locations",
        export_endpoint: "/api/v4/groups/#{group.id}/dependency_list_exports"
      )
    end
  end

  describe '#dependencies_exportable_link' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:url_builder) { Gitlab::UrlBuilder.instance }

    subject(:exportable_link) { helper.dependencies_exportable_link(export) }

    context 'when exportable is a project' do
      let(:project) { build_stubbed(:project) }
      let(:export) { build_stubbed(:dependency_list_export, project: project) }

      it { is_expected.to eq("<a href=\"#{url_builder.project_url(project)}\">#{project.full_name}</a>") }
    end

    context 'when exportable is a group' do
      let(:group) { build_stubbed(:group) }
      let(:export) { build_stubbed(:dependency_list_export, group: group, project: nil) }

      it { is_expected.to eq("<a href=\"#{url_builder.group_canonical_url(group)}\">#{group.full_name}</a>") }
    end

    context 'when exportable is a pipeline' do
      let(:pipeline) { build_stubbed(:ci_pipeline) }
      let(:export) { build_stubbed(:dependency_list_export, pipeline: pipeline, project: pipeline.project) }

      it 'returns correct link text' do
        url = url_builder.project_pipeline_url(pipeline.project, pipeline)
        is_expected.to eq("<a href=\"#{url}\">##{pipeline.id}</a>")
      end
    end
  end
end
