# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ProjectsFinder, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax
  include NamespaceStorageHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group, :public) }
  let_it_be(:subgroup) { create(:group, parent: namespace) }
  let_it_be_with_reload(:project_1) { create(:project, :public, group: namespace, path: 'project', name: 'Project') }
  let_it_be_with_reload(:project_2) do
    create(:project, :public, group: namespace, path: 'test-project', name: 'Test Project')
  end

  let_it_be_with_reload(:project_3) do
    create(:project, :public, group: subgroup, path: 'test-subgroup', name: 'Subgroup Project')
  end

  let(:params) { {} }

  let(:finder) { described_class.new(namespace: namespace, params: params, current_user: current_user) }

  subject(:projects) { finder.execute }

  describe '#execute' do
    context 'when compliance framework is present' do
      let_it_be(:framework_1) { create(:compliance_framework, namespace: namespace, name: "Test1") }
      let_it_be(:framework_1_id) { framework_1.id }
      let_it_be(:framework_settings_1) do
        create(:compliance_framework_project_setting, project: project_1, compliance_management_framework: framework_1)
      end

      let_it_be(:framework_2) { create(:compliance_framework, namespace: namespace, name: "Test2") }
      let_it_be(:framework_2_id) { framework_2.id }
      let_it_be(:framework_settings_2) do
        create(:compliance_framework_project_setting, project: project_2, compliance_management_framework: framework_2)
      end

      let_it_be(:other_namespace) { create(:group, :public) }
      let_it_be(:other_project) { create(:project, :public, group: other_namespace) }
      let_it_be(:other_framework) { create(:compliance_framework, namespace: other_namespace) }
      let_it_be(:other_framework_id) { other_framework.id }
      let_it_be(:other_framework_settings) do
        create(:compliance_framework_project_setting, project: other_project,
          compliance_management_framework: other_framework)
      end

      let_it_be_with_reload(:project_without_framework) do
        create(:project, :public, group: namespace, path: 'project-without-framework',
          name: 'Project without framework')
      end

      let_it_be(:project_multiple_frameworks) do
        create(:project, :public, group: namespace, path: 'project-multiple-frameworks',
          name: 'Project with multiple frameworks')
      end

      let_it_be(:framework_settings_multiple_1) do
        create(:compliance_framework_project_setting, project: project_multiple_frameworks,
          compliance_management_framework: framework_1)
      end

      let_it_be(:framework_settings_multiple_2) do
        create(:compliance_framework_project_setting, project: project_multiple_frameworks,
          compliance_management_framework: framework_2)
      end

      context 'when no filters are present' do
        it 'returns all projects' do
          expect(projects).to contain_exactly(project_1, project_2, project_without_framework,
            project_multiple_frameworks)
        end
      end

      context 'when compliance framework id is passed' do
        let(:params) { { compliance_framework_filters: { id: framework_id } } }

        context 'when compliance_framework_id is of valid framework' do
          let(:framework_id) { framework_1.id }

          it 'returns projects with compliance framework' do
            expect(projects).to contain_exactly(project_1, project_multiple_frameworks)
          end
        end

        context 'when compliance_framework_id is of other namespace' do
          let(:framework_id) { other_framework.id }

          it 'returns no projects' do
            expect(projects).to be_empty
          end
        end

        context 'when provided with a non existing framework id' do
          let(:framework_id) { non_existing_record_id }

          it 'returns no projects' do
            expect(projects).to be_empty
          end
        end

        context 'when compliance_framework_id is nil' do
          let(:framework_id) { nil }

          # Issue https://gitlab.com/gitlab-org/gitlab/-/issues/478560 for fixing multiple projects
          it 'returns all projects' do
            expect(projects).to contain_exactly(project_1, project_2, project_without_framework,
              project_multiple_frameworks)
          end
        end
      end

      context 'when negated compliance framework id param is passed' do
        let(:params) { { compliance_framework_filters: { not: { id: framework_id } } } }

        context 'when compliance_framework_id is of valid framework' do
          let(:framework_id) { framework_1.id }

          it "returns projects where compliance framework id is not framework's id or nil" do
            expect(projects).to contain_exactly(project_2, project_without_framework)
          end
        end

        context 'when compliance_framework_id is of other namespace' do
          let(:framework_id) { other_framework.id }

          it 'returns all projects' do
            expect(projects).to contain_exactly(project_1, project_2, project_without_framework,
              project_multiple_frameworks)
          end
        end

        context 'when provided with a non existing framework id' do
          let(:framework_id) { non_existing_record_id }

          it 'returns all projects' do
            expect(projects).to contain_exactly(project_1, project_2, project_without_framework,
              project_multiple_frameworks)
          end
        end

        context 'when compliance_framework_id is nil' do
          let(:framework_id) { nil }

          it 'returns all projects' do
            expect(projects).to contain_exactly(project_1, project_2, project_without_framework,
              project_multiple_frameworks)
          end
        end
      end

      context 'when both framework id and negated compliance framework id is passed' do
        let(:params) { { compliance_framework_filters: { id: framework_id, not: { id: not_framework_id } } } }

        context 'when both ids are same' do
          let(:framework_id) { framework_1.id }
          let(:not_framework_id) { framework_1.id }

          it 'returns projects with other compliance framework' do
            expect(projects).to be_empty
          end
        end

        context 'when both ids are different' do
          let(:framework_id) { framework_1.id }
          let(:not_framework_id) { framework_2.id }

          it 'returns projects with other compliance framework' do
            expect(projects).to contain_exactly(project_1)
          end
        end
      end

      context 'when compliance framework presence filter is passed' do
        context "when presence filter is 'any'" do
          let(:params) { { compliance_framework_filters: { presence_filter: 'any' } } }

          it 'returns projects with any compliance framework' do
            expect(projects).to contain_exactly(project_1, project_2, project_multiple_frameworks)
          end
        end

        context "when presence filter is 'none'" do
          let(:params) { { compliance_framework_filters: { presence_filter: 'none' } } }

          it 'returns projects without a compliance framework' do
            expect(projects).to contain_exactly(project_without_framework)
          end
        end
      end

      context 'when compliance framework presence filter is not supported' do
        let(:params) { { compliance_framework_filters: { presence_filter: :invalid } } }

        it 'raises an ArgumentError' do
          expect { projects }.to raise_error(ArgumentError, "The presence filter is not supported: 'invalid'")
        end
      end

      context 'when compliance framework ids is passed' do
        # rubocop:disable Layout/LineLength -- Required for formatting of table
        where(:framework_ids, :output) do
          [ref(:framework_1_id), ref(:framework_2_id)] | [ref(:project_multiple_frameworks)]
          [ref(:framework_1_id)]                       | [ref(:project_1), ref(:project_multiple_frameworks)]
          [ref(:other_framework_id)]                   | []
          [ref(:non_existing_record_id)]               | []
          []                                           | [ref(:project_1), ref(:project_2), ref(:project_without_framework), ref(:project_multiple_frameworks)]
          nil                                          | [ref(:project_1), ref(:project_2), ref(:project_without_framework), ref(:project_multiple_frameworks)]
        end
        # rubocop:enable Layout/LineLength

        with_them do
          let(:params) { { compliance_framework_filters: { ids: framework_ids } } }

          it 'returns related projects' do
            expect(projects).to match_array(output)
          end
        end
      end

      context 'when negated compliance framework ids is passed' do
        # rubocop:disable Layout/LineLength -- Required for formatting of table
        where(:framework_ids, :output) do
          [ref(:framework_1_id), ref(:framework_2_id)] | [ref(:project_without_framework)]
          [ref(:framework_1_id)]                       | [ref(:project_2), ref(:project_without_framework)]
          [ref(:other_framework_id)]                   | [ref(:project_1), ref(:project_2), ref(:project_without_framework), ref(:project_multiple_frameworks)]
          [ref(:non_existing_record_id)]               | [ref(:project_1), ref(:project_2), ref(:project_without_framework), ref(:project_multiple_frameworks)]
          []                                           | [ref(:project_1), ref(:project_2), ref(:project_without_framework), ref(:project_multiple_frameworks)]
          nil                                          | [ref(:project_1), ref(:project_2), ref(:project_without_framework), ref(:project_multiple_frameworks)]
        end
        # rubocop:enable Layout/LineLength

        with_them do
          let(:params) { { compliance_framework_filters: { not: { ids: framework_ids } } } }

          it 'returns related projects' do
            expect(projects).to match_array(output)
          end
        end
      end

      context 'when combination of framework id, ids and negations are passed together' do
        # rubocop:disable Layout/LineLength -- Required for formatting of table
        where(:filters, :output) do
          { id: ref(:framework_1_id), ids: [ref(:framework_1_id), ref(:framework_2_id)] }                                   | [ref(:project_multiple_frameworks)]
          { ids: [ref(:framework_2_id)], not: { id: ref(:framework_1_id) } }                                                | [ref(:project_2)]
          { ids: [ref(:framework_1_id), ref(:framework_2_id)], not: { ids: [ref(:framework_1_id), ref(:framework_2_id)] } } | []
          { not: { id: ref(:framework_1_id), ids: [ref(:framework_2_id)] } }                                                | [ref(:project_without_framework)]
        end
        # rubocop:enable Layout/LineLength

        with_them do
          let(:params) { { compliance_framework_filters: filters } }

          it 'returns related projects' do
            expect(projects).to match_array(output)
          end
        end
      end
    end

    context 'when it has_vulnerabilities' do
      before do
        project_1.project_setting.update!(has_vulnerabilities: true)
      end

      context 'when has_vulnerabilities is provided' do
        let(:params) { { has_vulnerabilities: true } }

        it 'returns projects with vulnerabilities' do
          expect(projects).to contain_exactly(project_1)
        end
      end

      context 'when has_vulnerabilities is not provided' do
        it 'returns all projects' do
          expect(projects).to contain_exactly(project_1, project_2)
        end
      end
    end

    describe 'sorting' do
      let(:sort) { nil }
      let(:params) { { sort: sort, include_subgroups: true } }

      where(enforcement_type: [:project_repository_limit, :namespace_storage_limit])

      with_them do
        before do
          if enforcement_type == :project_repository_limit
            stub_ee_application_setting(repository_size_limit: 20)
          else
            enforce_namespace_storage_limit(namespace)
            set_enforcement_limit(namespace, megabytes: 20)
          end
        end

        context 'as excess repo storage size, descending' do
          let(:sort) { :excess_repo_storage_size_desc }

          before do
            project_1.statistics.update!(repository_size: 10, lfs_objects_size: 2)
            project_2.statistics.update!(repository_size: 12, lfs_objects_size: 3)
            project_3.statistics.update!(repository_size: 11, lfs_objects_size: 0)
          end

          it { is_expected.to eq([project_2, project_1, project_3]) }
        end

        context 'when sorting option is not defined' do
          it 'returns all projects' do
            expect(projects).to match_array [project_1, project_2, project_3]
          end
        end
      end
    end

    describe 'has_code_coverage' do
      context 'when has_code_coverage is provided' do
        let(:params) { { has_code_coverage: true } }

        before_all do
          create(:project_ci_feature_usage, feature: :code_coverage, project: project_1, default_branch: true)
          create(:ci_daily_build_group_report_result, project: project_1, default_branch: true)
          create(:project_ci_feature_usage, feature: :code_coverage, project: project_2, default_branch: false)
          create(:ci_daily_build_group_report_result, project: project_2, default_branch: false)
        end

        it 'returns projects with code coverage on default branch based on ci feature usages' do
          record = ActiveRecord::QueryRecorder.new do
            expect(projects).to contain_exactly(project_1)
          end

          queried_ci_table = record.log.any? { |l| l.include?('ci_daily_build_group_report_results') }

          expect(queried_ci_table).to be(false)
        end
      end

      context 'when has_code_coverage is not provided' do
        it 'returns all projects' do
          expect(projects).to contain_exactly(project_1, project_2)
        end
      end
    end

    context 'with existing SBOM occurrence records' do
      let(:occurrence) { create(:sbom_occurrence, project: project_1) }

      context 'when sbom_component_id is not provided' do
        it { is_expected.to match_array([project_2, project_1]) }
      end

      context 'when sbom_component_id is provided as part of params' do
        let(:params) { { sbom_component_id: occurrence.component_version_id } }

        it { is_expected.to eq([project_1]) }
      end
    end
  end
end
