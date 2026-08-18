# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::DependenciesFinder, feature_category: :dependency_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }

  let_it_be(:occurrence_1) do
    create(:sbom_occurrence, :mit, packager_name: 'nuget', project: project, highest_severity: 'low')
  end

  let_it_be(:occurrence_2) do
    create(:sbom_occurrence, :apache_2, packager_name: 'npm', project: project, highest_severity: 'critical')
  end

  let_it_be(:occurrence_3) do
    create(:sbom_occurrence, :mpl_2, source: nil, project: project)
  end

  before do
    stub_licensed_features(dependency_scanning: true)
  end

  shared_examples 'filter and sorting' do
    subject(:dependencies) { described_class.new(dependable, current_user: nil, params: params).execute }

    context 'without params' do
      let(:params) { {} }

      it 'returns the dependencies associated with the project ordered by id' do
        expect(dependencies.map(&:id)).to be_sorted
      end
    end

    context 'with params' do
      context 'when sorted asc by names' do
        let_it_be(:params, freeze: false) do
          {
            sort: 'asc',
            sort_by: 'name'
          }
        end

        it 'returns array of data properly sorted' do
          expect(dependencies.map(&:name)).to be_sorted
        end
      end

      context 'when sorted desc by names' do
        let_it_be(:params, freeze: false) do
          {
            sort: 'desc',
            sort_by: 'name'
          }
        end

        it 'returns array of data properly sorted' do
          expect(dependencies.map(&:name)).to be_sorted(verse: :desc)
        end
      end

      context 'when sorted asc by packager' do
        let_it_be(:params, freeze: false) do
          {
            sort: 'asc',
            sort_by: 'packager'
          }
        end

        it 'returns array of data properly sorted' do
          packagers = dependencies.map(&:packager)

          expect(packagers).to eq(['npm', 'nuget', nil])
        end
      end

      context 'when sorted desc by packager' do
        let_it_be(:params, freeze: false) do
          {
            sort: 'desc',
            sort_by: 'packager'
          }
        end

        it 'returns array of data properly sorted' do
          packagers = dependencies.map(&:packager)

          expect(packagers).to eq([nil, 'nuget', 'npm'])
        end
      end

      context 'when sorted asc by license' do
        let(:params) { { sort: 'asc', sort_by: 'license' } }

        it 'returns sorted results' do
          spdx_ids = dependencies.map { |dependency| dependency.licenses.first['spdx_identifier'] }

          expect(spdx_ids).to be_sorted
        end
      end

      context 'when sorted desc by license' do
        let(:params) { { sort: 'desc', sort_by: 'license' } }

        it 'returns sorted results' do
          spdx_ids = dependencies.map { |dependency| dependency.licenses.first['spdx_identifier'] }

          expect(spdx_ids).to be_sorted(verse: :desc)
        end
      end

      context 'when sorted asc by severity' do
        let_it_be(:params, freeze: false) do
          {
            sort: 'asc',
            sort_by: 'severity'
          }
        end

        it 'returns array of data properly sorted' do
          severities = dependencies.map(&:highest_severity)

          expect(severities).to eq([nil, 'low', 'critical'])
        end
      end

      context 'when sorted desc by severity' do
        let_it_be(:params, freeze: false) do
          {
            sort: 'desc',
            sort_by: 'severity'
          }
        end

        it 'returns array of data properly sorted' do
          severities = dependencies.map(&:highest_severity)

          expect(severities).to eq(['critical', 'low', nil])
        end
      end

      context 'when filtered by package name npm' do
        let_it_be(:params, freeze: false) do
          {
            package_managers: %w[npm]
          }
        end

        it 'returns only records with packagers related to npm' do
          packagers = dependencies.map(&:packager)

          expect(packagers).to eq(%w[npm])
        end
      end

      context 'when filtered by component name' do
        let_it_be(:params, freeze: false) do
          {
            component_names: [occurrence_1.name]
          }
        end

        it 'returns only records corresponding to the filter' do
          component_names = dependencies.map(&:name)

          expect(component_names).to eq([occurrence_1.name])
        end
      end

      context 'when filtered by component versions' do
        context 'when version filtering feature flag is enabled' do
          context 'when negated filter present' do
            let_it_be(:params, freeze: false) do
              {
                not: { component_versions: [occurrence_1.component_version.version] }
              }
            end

            it 'returns only records corresponding to the filter' do
              component_version_ids = dependencies.map(&:component_version_id)

              expect(component_version_ids).to match_array([occurrence_2.component_version_id,
                occurrence_3.component_version_id])
            end
          end

          context 'when negated filter is not present' do
            let_it_be(:params, freeze: false) do
              {
                component_versions: [occurrence_1.component_version.version]
              }
            end

            it 'returns only records corresponding to the filter' do
              component_version_ids = dependencies.map(&:component_version_id)

              expect(component_version_ids).to eq([occurrence_1.component_version_id])
            end
          end
        end
      end

      context 'when filtered by license' do
        let_it_be(:params, freeze: false) do
          {
            licenses: ['MIT', 'MPL-2.0']
          }
        end

        it 'returns only records corresponding to the filter' do
          expect(dependencies.map(&:id)).to match_array([occurrence_1.id, occurrence_3.id])
        end
      end

      context 'when filtering by policy violations' do
        let(:params) { { policy_violations: ['DISMISSED_IN_MR'] } }

        let(:dismissed_uuid) { occurrence_1.uuid }

        shared_examples_for 'returns an empty list' do
          it 'returns an empty list' do
            expect(dependencies).to be_empty
          end
        end

        context 'when there are dependencies dismissed by policies' do
          before do
            create(:policy_dismissal, :preserved, project: project, license_occurrence_uuids: [dismissed_uuid])
          end

          it 'returns only records dismissed by security policies' do
            expect(dependencies.map(&:id)).to match_array([occurrence_1.id])
          end
        end

        context 'when there are no dependencies dismissed by policies' do
          it_behaves_like 'returns an empty list'
        end
      end

      context 'when params is invalid' do
        let_it_be(:params, freeze: false) do
          {
            sort: 'invalid',
            sort_by: 'invalid'
          }
        end

        it 'returns the dependencies associated with the project ordered by id' do
          expect(dependencies.map(&:id)).to be_sorted
        end
      end
    end
  end

  shared_examples 'group with project_id filters' do
    context 'when filtering by project_id' do
      let_it_be(:authorized_project) { create(:project, group: subgroup) }
      let_it_be(:occurrence_from_authorized_project) do
        create(:sbom_occurrence, project: authorized_project)
      end

      let_it_be(:unauthorized_project) { create(:project) }
      let_it_be(:occurrence_from_unauthorized_project) do
        create(:sbom_occurrence, project: unauthorized_project)
      end

      let(:params) { { project_ids: [authorized_project, unauthorized_project].map(&:id) } }

      it 'returns records for authorized projects only' do
        expect(dependencies.map(&:id)).to match_array([occurrence_from_authorized_project.id])
      end
    end
  end

  context 'with project' do
    let(:dependable) { project }

    include_examples 'filter and sorting'

    context 'when filtering by project_id' do
      let_it_be(:other_project) { create(:project, group: group) }
      let_it_be(:occurrence_from_other_project) do
        create(:sbom_occurrence, project: other_project)
      end

      let(:params) { { project_ids: [other_project.id] } }

      it 'ignores the project_id param' do
        expect(dependencies).to match_array([occurrence_1, occurrence_2, occurrence_3])
      end
    end

    context 'when filtered by source types' do
      let_it_be(:occurrence_cs) do
        create(:sbom_occurrence, :os_occurrence, project: project)
      end

      let_it_be(:params, freeze: false) do
        {
          source_types: ['container_scanning']
        }
      end

      it 'returns only records corresponding to the filter' do
        expect(dependencies.map(&:id)).to match_array([occurrence_cs.id])
      end

      context 'when source type nil_source is also present' do
        let_it_be(:params, freeze: false) do
          {
            source_types: %w[container_scanning nil_source]
          }
        end

        it 'returns records with nil type' do
          expect(dependencies.map(&:id)).to match_array([occurrence_cs.id, occurrence_3.id])
        end
      end
    end
  end

  context 'with group' do
    let(:dependable) { group }

    include_examples 'filter and sorting'
    include_examples 'group with project_id filters'
  end

  context 'with subgroup' do
    let(:dependable) { subgroup }

    include_examples 'filter and sorting'
    include_examples 'group with project_id filters'
  end

  context 'with vulnerability' do
    let(:dependable) { create(:vulnerability, project: project) }

    before do
      occurrence_1.vulnerabilities << dependable
      occurrence_2.vulnerabilities << dependable
      occurrence_3.vulnerabilities << dependable
    end

    include_examples 'filter and sorting'
  end
end
