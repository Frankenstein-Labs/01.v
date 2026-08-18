# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::AggregationsFinder, feature_category: :dependency_management do
  let_it_be(:target_group) { create(:group) }
  let(:params) { {} }
  let_it_be(:subgroup) { create(:group, parent: target_group) }
  let_it_be(:outside_group) { create(:group) }
  let_it_be(:outside_project) { create(:project, group: outside_group) }
  let_it_be(:archived_project) { create(:project, :archived, group: target_group) }

  let_it_be(:target_projects) do
    [
      create(:project, group: target_group),
      create(:project, group: subgroup)
    ]
  end

  let_it_be(:target_occurrences) do
    target_projects.map do |project|
      create(:sbom_occurrence, :unknown, :with_vulnerabilities, project: project)
    end
  end

  before_all do
    # Records that should not be returned in the results
    create(:sbom_occurrence, project: outside_project)
    create(:sbom_occurrence, project: archived_project)
  end

  describe '#execute' do
    subject(:execute) { described_class.new(target_group, params: params).execute }

    it 'returns occurrences in target group hierarchy' do
      expected = target_occurrences.map do |occurrence|
        an_object_having_attributes(
          component_id: occurrence.component_id,
          component_version_id: occurrence.component_version_id,
          licenses: occurrence.licenses,
          occurrence_count: 1,
          project_count: 1,
          vulnerability_count: 2
        )
      end

      expect(execute).to match_array(expected)
    end

    describe 'pagination' do
      let(:params) { { per_page: 1 } }

      it 'returns per_page + 1 items' do
        expect(execute.to_a.size).to eq(2)
      end

      context 'when per_page is over max page size' do
        let(:params) { { per_page: 2 } }
        let(:max) { 1 }

        before do
          stub_const("#{described_class}::MAX_PAGE_SIZE", max)
        end

        it 'returns max number of items + 1' do
          expect(execute.to_a.size).to eq(max + 1)
        end
      end
    end

    context 'when occurrences have licenses' do
      let_it_be(:occurrence_mit_apache_2) do
        create(:sbom_occurrence, :mit, :apache_2, :bundler, project: target_projects.first)
      end

      let_it_be(:occurrence_mpl) { create(:sbom_occurrence, :mpl_2, :nuget, project: target_projects.first) }
      let_it_be(:occurrence_apache_2) { create(:sbom_occurrence, :apache_2, :yarn, project: target_projects.first) }

      let_it_be(:occurrence_unknown_1) { target_occurrences.first }
      let_it_be(:occurrence_unknown_2) { target_occurrences.last }
      let_it_be(:unknown_license) { Gitlab::LicenseScanning::PackageLicenses::UNKNOWN_LICENSE.stringify_keys }
      let_it_be(:unknown_license_spdx_identifier) do
        Gitlab::LicenseScanning::PackageLicenses::UNKNOWN_LICENSE[:spdx_identifier]
      end

      it 'returns the first license' do
        expect(execute).to match_array([
          an_object_having_attributes(
            component_id: occurrence_mit_apache_2.component_id,
            component_version_id: occurrence_mit_apache_2.component_version_id,
            licenses: [{ "url" => "https://spdx.org/licenses/MIT.html", "name" => "MIT License",
                         "spdx_identifier" => "MIT" }],
            primary_license_spdx_identifier: "MIT"
          ),
          an_object_having_attributes(
            component_id: occurrence_mpl.component_id,
            component_version_id: occurrence_mpl.component_version_id,
            licenses: [{ "url" => "https://spdx.org/licenses/MPL-2.0.html",
                         "name" => "Mozilla Public License 2.0", "spdx_identifier" => "MPL-2.0" }],
            primary_license_spdx_identifier: "MPL-2.0"
          ),
          an_object_having_attributes(
            component_id: occurrence_apache_2.component_id,
            component_version_id: occurrence_apache_2.component_version_id,
            licenses: [{ "url" => "https://spdx.org/licenses/Apache-2.0.html",
                         "name" => "Apache 2.0 License", "spdx_identifier" => "Apache-2.0" }],
            primary_license_spdx_identifier: "Apache-2.0"
          ),
          an_object_having_attributes(
            component_id: occurrence_unknown_1.component_id,
            component_version_id: occurrence_unknown_1.component_version_id,
            licenses: [unknown_license],
            primary_license_spdx_identifier: unknown_license_spdx_identifier
          ),
          an_object_having_attributes(
            component_id: occurrence_unknown_2.component_id,
            component_version_id: occurrence_unknown_2.component_version_id,
            licenses: [unknown_license],
            primary_license_spdx_identifier: unknown_license_spdx_identifier
          )
        ])
      end
    end

    describe 'sorting' do
      let_it_be(:project) { target_projects.first }
      let_it_be(:occurrence_1) { occurrence(traits: [:npm], name: 'c', severity: 'low') }
      let_it_be(:occurrence_2) { occurrence(traits: [:mit, :apache_2, :bundler], name: 'b', severity: 'medium') }
      let_it_be(:occurrence_3) { occurrence(traits: [:mpl_2, :nuget], name: 'a', severity: 'high') }
      let_it_be(:occurrence_4) { occurrence(traits: [:apache_2, :yarn], name: 'd', severity: 'critical') }
      let_it_be(:null_fields) do
        create(:sbom_occurrence, component: create(:sbom_component), highest_severity: nil, project: project)
          .tap { |o| o.update!(package_manager: nil, component_name: nil) }
      end

      before_all do
        Sbom::Occurrence.id_in(target_occurrences.map(&:id)).delete_all
      end

      def occurrence(name:, severity:, traits: [])
        params = { component: create(:sbom_component, name: name), highest_severity: severity, project: project }

        create(:sbom_occurrence, *traits, **params)
      end

      shared_examples 'can sort in both asc and desc order' do |sort_by|
        let(:expected_order_pattern) do
          # overridden for :primary_license_spdx_identifier as that is
          # a jsonb column
          /ORDER BY "(?:sbom|inner)_occurrences"."#{sort_by}".*?(?=LIMIT)/im
        end

        context 'in ascending order' do
          let(:params) { { sort_by: sort_by, sort: direction } }
          let(:direction) { :asc }

          it "returns occurrences in ascending order of #{sort_by}" do
            expect(execute.to_a).to eq(expected_asc)
          end

          it 'ensures consistent sorting in all ordering clauses' do
            recorder = ActiveRecord::QueryRecorder.new { execute.to_a }

            sbom_order_clause, inner_order_clause = recorder.log.join(' ').scan(expected_order_pattern)
            sbom_order_clause.gsub!("sbom_occurrences", "occurrences")
            inner_order_clause.gsub!("inner_occurrences", "occurrences")

            expect(sbom_order_clause).not_to be_empty
            expect(inner_order_clause).not_to be_empty
            expect(sbom_order_clause).to eq(inner_order_clause)
          end
        end

        context 'in descending order' do
          let(:params) { { sort_by: sort_by, sort: direction } }
          let(:direction) { :desc }

          it "returns occurrences in descending order of #{sort_by}" do
            expect(execute.to_a).to eq(expected_desc)
          end

          it 'ensures consistent sorting in all ordering clauses' do
            recorder = ActiveRecord::QueryRecorder.new { execute.to_a }

            sbom_order_clause, inner_order_clause = recorder.log.join(' ').scan(expected_order_pattern)
            sbom_order_clause.gsub!("sbom_occurrences", "occurrences")
            inner_order_clause.gsub!("inner_occurrences", "occurrences")

            expect(sbom_order_clause).not_to be_empty
            expect(inner_order_clause).not_to be_empty
            expect(sbom_order_clause).to eq(inner_order_clause)
          end
        end
      end

      context 'when sorting by component_name' do
        it_behaves_like 'can sort in both asc and desc order', :component_name do
          let_it_be(:a_name) { occurrence_3 }
          let_it_be(:b_name) { occurrence_2 }
          let_it_be(:c_name) { occurrence_1 }
          let_it_be(:d_name) { occurrence_4 }

          let(:expected_asc) { [a_name, b_name, c_name, d_name, null_fields] }
          let(:expected_desc) { [null_fields, d_name, c_name, b_name, a_name] }
        end
      end

      context 'when sorting by highest_severity' do
        it_behaves_like 'can sort in both asc and desc order', :highest_severity do
          let_it_be(:low) { occurrence_1 }
          let_it_be(:medium) { occurrence_2 }
          let_it_be(:high) { occurrence_3 }
          let_it_be(:critical) { occurrence_4 }

          let(:expected_asc) { [null_fields, low, medium, high, critical] }
          let(:expected_desc) { [critical, high, medium, low, null_fields] }
        end
      end

      context 'when sorting by license id' do
        it_behaves_like 'can sort in both asc and desc order', :primary_license_spdx_identifier do
          let_it_be(:blank_license_array) { occurrence_1 }
          let_it_be(:mit_apache) { occurrence_2 }
          let_it_be(:mpl) { occurrence_3 }
          let_it_be(:apache) { occurrence_4 }

          let(:expected_order_pattern) do
            /ORDER BY \("(?:sbom|inner)_occurrences"."licenses" -> 0 ->> 'spdx_identifier'\)::text.*?(?=LIMIT)/im
          end

          let(:expected_asc) { [apache, mit_apache, mpl, blank_license_array, null_fields] }
          let(:expected_desc) { [null_fields, blank_license_array, mpl, mit_apache, apache] }
        end
      end

      context 'when sorting by package manager' do
        it_behaves_like 'can sort in both asc and desc order', :package_manager do
          let_it_be(:npm) { occurrence_1 }
          let_it_be(:bundler) { occurrence_2 }
          let_it_be(:nuget) { occurrence_3 }
          let_it_be(:yarn) { occurrence_4 }

          let(:expected_asc) { [bundler, npm, nuget, yarn, null_fields] }
          let(:expected_desc) { [null_fields, yarn, nuget, npm, bundler] }
        end
      end

      describe 'sort_by aliases' do
        using RSpec::Parameterized::TableSyntax

        where(:aliased_sort_by, :native_sort_by, :direction) do
          'name'            | :component_name                  | :asc
          'name'            | :component_name                  | :desc
          'packager'        | :package_manager                 | :asc
          'packager'        | :package_manager                 | :desc
          'severity'        | :highest_severity                | :asc
          'severity'        | :highest_severity                | :desc
          'license'         | :primary_license_spdx_identifier | :asc
          'license'         | :primary_license_spdx_identifier | :desc
          'component_name'  | :component_name                  | :asc
          'package_manager' | :package_manager                 | :desc
        end

        with_them do
          it 'orders identically to the native column name' do
            aliased = described_class.new(target_group, params: { sort_by: aliased_sort_by, sort: direction })
            native = described_class.new(target_group, params: { sort_by: native_sort_by, sort: direction })

            native_ids = native.execute.map(&:id)

            expect(native_ids.size).to be > 1 # guard against a vacuously equal comparison
            expect(aliased.execute.map(&:id)).to eq(native_ids)
          end
        end

        it 'falls back to the default ordering for unsupported values' do
          default_ids = described_class.new(target_group, params: {}).execute.map(&:id)

          expect(described_class.new(target_group, params: { sort_by: 'bogus' }).execute.map(&:id)).to eq(default_ids)
        end
      end
    end

    describe 'filtering by component IDs' do
      let_it_be(:component_1) { create(:sbom_component) }
      let_it_be(:component_2) { create(:sbom_component) }
      let_it_be(:occurrence_1) do
        create(:sbom_occurrence, component_id: component_1.id, project: target_projects.first)
      end

      let_it_be(:occurrence_2) { create(:sbom_occurrence, component_id: component_2.id, project: target_projects.last) }

      let(:params) { { component_ids: [component_1.id, component_2.id] } }

      it 'returns only matching Sbom::Occurrences' do
        expect(execute.to_a).to match_array([occurrence_1, occurrence_2])
      end
    end

    describe 'filtering by component names' do
      let_it_be(:component_1) { create(:sbom_component, name: 'activerecord') }
      let_it_be(:component_2) { create(:sbom_component, name: 'apollo') }
      let_it_be(:occurrence_1) do
        create(:sbom_occurrence,
          component: component_1,
          project: target_projects.first
        )
      end

      let_it_be(:occurrence_2) do
        create(:sbom_occurrence,
          component: component_2,
          project: target_projects.last
        )
      end

      let(:params) { { component_names: [component_1.name] } }

      it 'returns only matching Sbom::Occurrences' do
        expect(execute.to_a).to match_array([occurrence_1])
      end
    end

    describe 'filtering by license' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:occurrence_apache_2) { create(:sbom_occurrence, :apache_2, project: target_projects.first) }
      let_it_be(:occurrence_mit) { create(:sbom_occurrence, :mit, project: target_projects.first) }
      let_it_be(:occurrence_mpl_2) { create(:sbom_occurrence, :mpl_2, project: target_projects.first) }
      let_it_be(:occurrence_apache_2_mpl_2) do
        create(:sbom_occurrence, :apache_2, :mpl_2, project: target_projects.first)
      end

      let_it_be(:unknown_1) { target_occurrences.first }
      let_it_be(:unknown_2) { target_occurrences.second }

      let(:params) { { licenses: input } }

      where(:input, :expected_occurrences) do
        %w[MIT MPL-2.0]     | [ref(:occurrence_mit), ref(:occurrence_mpl_2)]
        %w[MPL-2.0 unknown] | [ref(:occurrence_mpl_2), ref(:unknown_1), ref(:unknown_2)]
        %w[Apache-2.0]      | [ref(:occurrence_apache_2), ref(:occurrence_apache_2_mpl_2)]
        %w[unknown]         | [ref(:unknown_1), ref(:unknown_2)]
        []                  | [ref(:occurrence_apache_2), ref(:occurrence_mit), ref(:occurrence_mpl_2),
          ref(:occurrence_apache_2_mpl_2), ref(:unknown_1), ref(:unknown_2)]
      end

      with_them do
        it 'returns expected output for each input' do
          expected = expected_occurrences.map do |occurrence|
            an_object_having_attributes(
              component_id: occurrence.component_id,
              component_version_id: occurrence.component_version_id
            )
          end

          expect(execute.to_a).to match_array(expected)
        end
      end
    end

    describe 'filtering by package manager' do
      using RSpec::Parameterized::TableSyntax

      subject { execute.to_a.pluck(:package_manager).uniq }

      before_all do
        create(:sbom_occurrence, :bundler, project: target_projects.first)
        create(:sbom_occurrence, :npm, project: target_projects.first)
        create(:sbom_occurrence, :nuget, project: target_projects.first)
        create(:sbom_occurrence, :yarn, project: target_projects.first)
      end

      let(:params) { { package_managers: input } }

      where(:input, :expected_uniq_package_managers) do
        %w[bundler npm] | %w[bundler npm]
        %w[nuget]       | %w[nuget]
        %w[yarn]        | %w[yarn]
        %w[unknown]     | []
        []              | %w[bundler npm nuget yarn]
      end

      with_them { it { is_expected.to match_array expected_uniq_package_managers } }

      context 'when the dependencies_page_filter_by_package_manager FF is disabled' do
        before do
          stub_feature_flags(dependencies_page_filter_by_package_manager: false)
        end

        where(:input, :expected_uniq_package_managers) do
          %w[bundler npm] | %w[bundler npm nuget yarn]
          %w[nuget]       | %w[bundler npm nuget yarn]
          %w[yarn]        | %w[bundler npm nuget yarn]
          %w[unknown]     | %w[bundler npm nuget yarn]
          []              | %w[bundler npm nuget yarn]
        end

        with_them { it { is_expected.to match_array expected_uniq_package_managers } }
      end
    end

    context 'when filtered by component versions' do
      context 'when negated filter present' do
        let_it_be(:params) do
          {
            not: { component_versions: [target_occurrences.first.component_version.version] }
          }
        end

        it 'returns only records corresponding to the filter' do
          component_version_ids = execute.map(&:component_version_id)

          expect(component_version_ids).to match_array([target_occurrences.second.component_version_id])
        end
      end

      context 'when negated filter is not present' do
        let_it_be(:params) do
          {
            component_versions: [target_occurrences.first.component_version.version]
          }
        end

        it 'returns only records corresponding to the filter' do
          component_version_ids = execute.map(&:component_version_id)

          expect(component_version_ids).to eq([target_occurrences.first.component_version_id])
        end
      end
    end
  end
end
