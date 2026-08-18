# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Upstreams::Local::CheckService, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:package_name) { 'my/company/app/my-app' }
  let_it_be(:package_version) { '1.2.3' }
  let_it_be(:filename) { 'maven-metadata.xml' }
  let_it_be(:top_level_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: top_level_group) }
  let_it_be(:top_level_project) { create(:project, namespace: top_level_group) }
  let_it_be(:subproject) { create(:project, namespace: subgroup) }
  let_it_be(:top_level_package_file) do
    create(:maven_package, name: package_name, version: package_version, project: top_level_project)
      .package_files.find { |pf| pf.file_name == filename }
  end

  let_it_be(:subproject_package_file) do
    create(:maven_package, name: package_name, version: package_version, project: subproject)
      .package_files.find { |pf| pf.file_name == filename }
  end

  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: top_level_group) }
  let_it_be_with_reload(:top_level_group_upstream) do
    create(
      :virtual_registries_packages_maven_local_upstream,
      :local_group,
      local_group: top_level_group,
      group: top_level_group
    )
  end

  let_it_be_with_reload(:top_level_project_upstream) do
    create(
      :virtual_registries_packages_maven_local_upstream,
      local_project: top_level_project,
      group: top_level_group
    )
  end

  let_it_be_with_reload(:subgroup_upstream) do
    create(
      :virtual_registries_packages_maven_local_upstream,
      :local_group,
      local_group: subgroup,
      group: top_level_group
    )
  end

  let_it_be_with_reload(:subproject_upstream) do
    create(
      :virtual_registries_packages_maven_local_upstream,
      local_project: subproject,
      group: top_level_group
    )
  end

  let(:service) { described_class.new(upstreams:, params:) }
  let(:path) { "#{package_name}/#{package_version}/#{filename}" }
  let(:params) { { path: } }

  describe '#execute' do
    subject(:execute) { service.execute }

    # rubocop: disable Layout/LineLength -- table based specs
    where(:upstreams, :expected_upstream, :expected_local_file) do
      [ref(:top_level_project_upstream)] | ref(:top_level_project_upstream) | ref(:top_level_package_file)
      [ref(:subproject_upstream)] | ref(:subproject_upstream) | ref(:subproject_package_file)
      [ref(:subgroup_upstream)] | ref(:subgroup_upstream) | ref(:subproject_package_file)
      [ref(:top_level_group_upstream)] | ref(:top_level_group_upstream) | ref(:subproject_package_file)

      [ref(:top_level_project_upstream), ref(:top_level_group_upstream)] | ref(:top_level_project_upstream) | ref(:top_level_package_file)
      [ref(:subproject_upstream), ref(:top_level_project_upstream)] | ref(:subproject_upstream) | ref(:subproject_package_file)
      [ref(:subproject_upstream), ref(:subgroup_upstream)] | ref(:subproject_upstream) | ref(:subproject_package_file)
      [ref(:subgroup_upstream), ref(:top_level_group_upstream)] | ref(:subgroup_upstream) | ref(:subproject_package_file)
    end
    # rubocop: enable Layout/LineLength

    with_them do
      let(:wrapped_local_file) { ::VirtualRegistries::Local::Upstream::File.from_raw_local_file(expected_local_file) }
      let(:payload) { { upstream: expected_upstream, local_file: wrapped_local_file }.compact_blank }

      it { is_expected.to be_success.and have_attributes(payload:) }
    end

    context 'with a path that is not in local upstreams' do
      let(:path) { "test/#{filename}" }
      let(:upstreams) { [top_level_group_upstream] }

      it_behaves_like 'returning an error service response',
        message: described_class::ERRORS[:file_not_found_on_upstreams].message
    end

    context 'with a not found finder instance' do
      let(:upstreams) { [top_level_group_upstream] }

      before do
        stub_const("#{described_class}::FINDERS_CLASSES_MAP", {})
      end

      it_behaves_like 'returning an error service response', message: described_class::NO_FINDER_INSTANCE_ERROR.message
    end

    it_behaves_like 'a check upstream service handling no path set'
    it_behaves_like 'a check upstream service handling empty upstreams'
  end
end
