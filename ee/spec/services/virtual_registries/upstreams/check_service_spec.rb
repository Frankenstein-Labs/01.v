# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Upstreams::CheckService, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let(:service) { described_class.new(upstreams:, params:) }
  let(:params) { { path: } }

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'with maven virtual registries' do
      include_context 'for check upstream service for maven packages'

      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }

      let_it_be(:package_name) { 'my/company/app/my-app' }
      let_it_be(:package_version) { '1.2.3' }
      let_it_be(:filename) { 'maven-metadata.xml' }

      let_it_be(:project1) { create(:project) }
      let_it_be(:project2) { create(:project) }

      let_it_be(:package_file1) do
        create(:maven_package, name: package_name, version: package_version, project: project1)
          .package_files.find { |pf| pf.file_name == filename }
      end

      let_it_be(:package_file2) do
        create(:maven_package, name: package_name, version: package_version, project: project2)
          .package_files.find { |pf| pf.file_name == filename }
      end

      let_it_be_with_reload(:project_upstream1) do
        create(
          :virtual_registries_packages_maven_local_upstream,
          local_project: project1,
          group: registry.group
        )
      end

      let_it_be_with_reload(:project_upstream2) do
        create(
          :virtual_registries_packages_maven_local_upstream,
          local_project: project2,
          group: registry.group
        )
      end

      let_it_be(:remote_upstream1) { create(:virtual_registries_packages_maven_upstream) }
      let_it_be(:remote_upstream2) { create(:virtual_registries_packages_maven_upstream) }

      let(:path) { "#{package_name}/#{package_version}/#{filename}" }

      # rubocop: disable Layout/LineLength -- table based specs
      where(:upstreams, :pinged_remote_upstreams, :expected_upstream, :expected_local_file) do
        [ref(:project_upstream1)] | [] | ref(:project_upstream1) | ref(:package_file1)
        [ref(:project_upstream2)] | [] | ref(:project_upstream2) | ref(:package_file2)

        [ref(:project_upstream1), ref(:project_upstream2)] | [] | ref(:project_upstream1) | ref(:package_file1)
        [ref(:project_upstream1), ref(:remote_upstream1)]  | [] | ref(:project_upstream1) | ref(:package_file1)

        [ref(:remote_upstream1), ref(:project_upstream1)] | { ref(:remote_upstream1) => 200 } | ref(:remote_upstream1) | nil
        [ref(:remote_upstream1), ref(:project_upstream1)] | { ref(:remote_upstream1) => 404 } | ref(:project_upstream1) | ref(:package_file1)

        [ref(:remote_upstream1), ref(:project_upstream1), ref(:remote_upstream2)] | { ref(:remote_upstream1) => 404 } | ref(:project_upstream1) | ref(:package_file1)
      end
      # rubocop: enable Layout/LineLength

      with_them do
        let(:wrapped_local_file) do
          break unless expected_local_file

          ::VirtualRegistries::Local::Upstream::File.from_raw_local_file(expected_local_file)
        end

        let(:payload) { { upstream: expected_upstream, local_file: wrapped_local_file }.compact_blank }

        before do
          pinged_remote_upstreams.each { |u, status| stub_upstream_request(u, status:) }
        end

        it { is_expected.to be_success.and have_attributes(payload:) }
      end

      context 'with no matches in local upstreams' do
        let(:path) { "test/test.pom" }
        let(:upstreams) { [project_upstream1, project_upstream2] }

        where(:remote_upstreams, :status, :expected_upstream) do
          [ref(:remote_upstream1)] | [200] | ref(:remote_upstream1)
          [ref(:remote_upstream1), ref(:remote_upstream2)] | [404, 200] | ref(:remote_upstream2)
        end

        with_them do
          let(:upstreams) { super() + remote_upstreams }

          before do
            remote_upstreams.each_with_index { |u, i| stub_upstream_request(u, status: status[i]) }
          end

          it_behaves_like 'returning a service success response with upstream'
        end
      end

      context 'with no matches in any upstream' do
        let(:path) { "test/test.pom" }
        let(:upstreams) { [project_upstream1, project_upstream2, remote_upstream1, remote_upstream2] }

        before do
          [remote_upstream1, remote_upstream2].each { |u| stub_upstream_request(u, status: 404) }
        end

        it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
      end
    end

    context 'for container virtual registries' do
      include_context 'for check upstream service for container images'

      let_it_be(:registry) { create(:virtual_registries_container_registry) }
      let_it_be_with_reload(:upstream1) { create(:virtual_registries_container_upstream, registries: [registry]) }
      let_it_be_with_reload(:upstream2) { create(:virtual_registries_container_upstream, registries: [registry]) }
      let_it_be_with_reload(:upstream3) { create(:virtual_registries_container_upstream, registries: [registry]) }

      let(:path) { 'library/alpine/manifests/3.19' }
      let(:scope) { 'repository:library/alpine:pull' }
      let(:upstreams) { [upstream1, upstream2, upstream3] }

      # statuses is an array giving the status for each upstream
      where(:statuses, :expected_upstream) do
        [200, 200, 200] | ref(:upstream1)
        [404, 200, 200] | ref(:upstream2)
        [404, 404, 200] | ref(:upstream3)
      end

      with_them do
        before do
          stub_upstream_request(upstream1, status: statuses[0], scope: scope)
          stub_upstream_request(upstream2, status: statuses[1], scope: scope)
          stub_upstream_request(upstream3, status: statuses[2], scope: scope)
        end

        it_behaves_like 'returning a service success response with upstream'
      end

      context 'when file not found in any upstream' do
        before do
          stub_upstream_request(upstream1, status: 404, scope: scope)
          stub_upstream_request(upstream2, status: 404, scope: scope)
          stub_upstream_request(upstream3, status: 404, scope: scope)
        end

        it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
      end

      context 'when an upstream fails' do
        before do
          stub_upstream_request(upstream1, status: 404, scope: scope)
          stub_upstream_request(upstream2, raise_error: true, scope: scope)
          stub_upstream_request(upstream3, status: 200, scope: scope)
        end

        it 'raises an error' do
          expect { execute }.to raise_error(Gitlab::HTTP::BlockedUrlError)
        end
      end

      context 'when an upstream after the one with the file fails' do
        let(:expected_upstream) { upstream2 }

        before do
          stub_upstream_request(upstream1, status: 404, scope: scope)
          stub_upstream_request(upstream2, status: 200, scope: scope)
          stub_upstream_request(upstream3, raise_error: true, scope: scope)
        end

        it_behaves_like 'returning a service success response with upstream'
      end
    end

    it_behaves_like 'a check upstream service handling no path set'
    it_behaves_like 'a check upstream service handling empty upstreams'
  end
end
