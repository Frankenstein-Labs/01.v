# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ProjectsGrade, feature_category: :vulnerability_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:other_group) { create(:group) }

  let_it_be(:projects_list) do
    {
      project_1: create(:project, group: group),
      project_2: create(:project, group: group),
      project_3: create(:project, group: group),
      project_4: create(:project, group: group),
      project_5: create(:project, group: group),
      project_6_subgroup: create(:project, group: subgroup),
      project_7_other_group: create(:project, group: other_group)
    }
  end

  let_it_be(:archived_project) do
    create(:project, :archived, group: group).tap do |p|
      create(:vulnerability_statistic, :grade_a, project: p)
    end
  end

  let_it_be(:unrelated_project) do
    create(:project).tap do |p|
      create(:vulnerability_statistic, :grade_a, project: p)
    end
  end

  # `freeze: false` is kept here because this `let_it_be` subject is not an
  # ActiveRecord record, so freezing gives no cross-example isolation benefit
  # and `let_it_be_with_reload`/`refind` are no-ops on it. Keep as-is (see
  # gitlab-org/gitlab#602925).
  let_it_be(:vulnerability_statistic_list, freeze: false) do
    {
      vul_statistic_project_1_grade_a: create(:vulnerability_statistic, :grade_a, project: projects_list[:project_1]),
      vul_statistic_project_2_grade_b: create(:vulnerability_statistic, :grade_b, project: projects_list[:project_2]),
      vul_statistic_project_3_grade_b: create(:vulnerability_statistic, :grade_b, project: projects_list[:project_3]),
      vul_statistic_project_4_grade_c: create(:vulnerability_statistic, :grade_c, project: projects_list[:project_4]),
      vul_statistic_project_5_grade_f: create(:vulnerability_statistic, :grade_f, project: projects_list[:project_5]),
      vul_statistic_project_6_subgroup_grade_d:
        create(:vulnerability_statistic, :grade_d, project: projects_list[:project_6_subgroup]),
      vul_statistic_project_7_other_group_grade_a:
        create(:vulnerability_statistic, :grade_a, project: projects_list[:project_7_other_group])
    }
  end

  describe '#projects' do
    let(:vulnerable) { group }

    it 'returns project records matching project_ids' do
      result = described_class.grades_for([vulnerable])
      grade_a = result[vulnerable].find { |g| g.grade == 'a' }

      expect(grade_a).to be_present

      projects = grade_a.projects

      expect(projects).to all(be_a(Project))
      expect(projects.map(&:id)).to match_array(grade_a.project_ids)
      expect(projects).to all(satisfy { |project| !project.archived? })
    end

    describe 'loading the counts' do
      let(:result) { described_class.grades_for([vulnerable]) }
      let(:grade_a) { result[vulnerable].find { |g| g.grade == 'a' } }

      it 'loads the projects only once' do
        grade_a.projects

        expect { grade_a.count }.not_to exceed_query_limit(0)
      end
    end
  end

  describe '.grades_for' do
    using RSpec::Parameterized::TableSyntax

    let(:include_subgroups) { false }
    let(:filter) { nil }
    let(:vulnerables) { [vulnerable] }
    let(:user) { create(:user) }

    subject(:projects_grades) do
      described_class.grades_for(
        vulnerables,
        filter: filter,
        include_subgroups: include_subgroups
      )
    end

    context 'when ordering projects by severity and grouping by letter grade' do
      let(:vulnerable) { group }

      where(:statistic, :attrs, :grade) do
        :vul_statistic_project_1_grade_a | { critical: 0, high: 0, medium: 3 }  | 'c'
        :vul_statistic_project_2_grade_b | { critical: 0, high: 4, unknown: 2 } | 'd'
        :vul_statistic_project_3_grade_b | { critical: 0, high: 4, medium: 1 }  | 'd'
        :vul_statistic_project_4_grade_c | { critical: 5, high: 0 }             | 'f'
        :vul_statistic_project_5_grade_f | { critical: 5, high: 1 }             | 'f'
      end

      with_them do
        before do
          vulnerability_statistic_list[statistic].update!(
            **attrs,
            letter_grade: grade
          )
        end

        it 'updates the statistics properly' do
          expect(vulnerability_statistic_list[statistic].reload.letter_grade).to eq(grade)
        end
      end

      it 'returns projects ordered by severity' do
        vulnerability_statistic_list[:vul_statistic_project_4_grade_c].update!(updated_at: Time.zone.now)

        result = described_class.grades_for([group])
        projects_grade_f = result[group].find { |pg| pg.grade == 'f' }

        expected_ids = Vulnerabilities::Statistic
                         .where(project_id: projects_grade_f.project_ids)
                         .ordered_by_severity
                         .pluck(:project_id)

        expect(projects_grade_f.project_ids).to eq(expected_ids)
      end
    end

    context 'when vulnerables respond differently' do
      shared_context 'with user having access to dashboard projects' do
        before do
          [projects_list[:project_1], projects_list[:project_2], archived_project].each do |project|
            project.add_developer(user)
            user.security_dashboard_projects << project unless user.security_dashboard_projects.include?(project)
          end
        end
      end

      let(:projects_map) do
        {
          project_1: projects_list[:project_1].id,
          project_2: projects_list[:project_2].id,
          project_3: projects_list[:project_3].id,
          project_4: projects_list[:project_4].id,
          project_5: projects_list[:project_5].id,
          project_7_other_group: projects_list[:project_7_other_group].id
        }
      end

      let(:vulnerables_map) do
        {
          group: group,
          other_group: other_group,
          project_namespace: projects_list[:project_1].project_namespace,
          project: projects_list[:project_1],
          instance_security_dashboard: InstanceSecurityDashboard.new(user),
          unknown_type: Class.new.new
        }
      end

      def ids_for(*keys)
        keys.flatten.map { |k| projects_map[k] }
      end

      include_context 'with user having access to dashboard projects'

      where(:vulnerable_key, :expected_grades) do
        [
          [:group, {
            'a' => [:project_1],
            'b' => [:project_2, :project_3],
            'c' => [:project_4],
            'd' => [],
            'f' => [:project_5]
          }],
          [:project_namespace, {
            'a' => [:project_1]
          }],
          [:project, {
            'a' => [:project_1]
          }],
          [:instance_security_dashboard, {
            'a' => [:project_1],
            'b' => [:project_2],
            'c' => [],
            'd' => [],
            'f' => []
          }],
          [:unknown_type, {}]
        ]
      end

      with_them do
        let(:vulnerable) { vulnerables_map[vulnerable_key] }

        it "returns correct letter grades for vulnerable" do
          result = described_class.grades_for([vulnerable])
          actual = result[vulnerable].index_by(&:grade)

          expect(actual.keys.sort).to match_array(expected_grades.keys.sort)

          expected_grades.each do |grade, expected_projects|
            expected_ids = ids_for(expected_projects)
            actual_ids = actual[grade]&.project_ids || []

            expect(actual_ids.sort).to eq(expected_ids.sort), "Mismatch for grade #{grade}"
          end
        end
      end

      context 'with filter' do
        let(:filter) { :b }
        let(:vulnerable) { InstanceSecurityDashboard.new(user) }

        it 'returns only the filtered grade when it exists' do
          result = described_class.grades_for([vulnerable], filter: filter)

          grades = result[vulnerable]

          expect(grades).not_to be_empty
          expect(grades.size).to eq(1)
          expect(grades.first.grade).to eq('b')
          expect(grades.first.project_ids.sort).to eq([projects_list[:project_2].id])
        end

        it 'returns no grades when the filtered grade does not exist' do
          result = described_class.grades_for([vulnerable], filter: :__fake_grade)
          expect(result[vulnerable]).to eq([])
        end
      end

      context 'when multiple vulnerables are passed together' do
        let(:vulnerables_map) do
          {
            group: group,
            other_group: other_group
          }
        end

        include_context 'with user having access to dashboard projects'

        def ids_for(*keys)
          keys.flatten.map { |k| projects_map[k] }
        end

        where(:vulnerable_key, :expected_grades) do
          [
            [:group, {
              'a' => [:project_1],
              'b' => [:project_2, :project_3],
              'c' => [:project_4],
              'd' => [],
              'f' => [:project_5]
            }],
            [:other_group, {
              'a' => [:project_7_other_group],
              'b' => [],
              'c' => [],
              'd' => [],
              'f' => []
            }]
          ]
        end

        with_them do
          let(:vulnerable) { vulnerables_map[vulnerable_key] }
          let(:all_vulnerables) { [vulnerables_map[:group], vulnerables_map[:other_group]] }

          it 'returns expected grades and project IDs per vulnerable' do
            results = described_class.grades_for(all_vulnerables)

            actual = results[vulnerable].index_by(&:grade)

            expect(actual.keys.sort).to match_array(expected_grades.keys.sort)

            expected_grades.each do |grade, expected_projects|
              expected_ids = ids_for(expected_projects)
              actual_ids = actual[grade]&.project_ids || []

              expect(actual_ids.sort).to eq(expected_ids.sort)
            end
          end

          it 'returns expected grades and project IDs' do
            result = described_class.grades_for(all_vulnerables)

            grades_by_letter = result[vulnerable].index_by(&:grade)
            expect(grades_by_letter.keys.sort).to match_array(expected_grades.keys.sort)

            expected_grades.each do |grade, expected_projects|
              expected_ids = ids_for(expected_projects)
              actual_ids = grades_by_letter[grade]&.project_ids || []

              expect(actual_ids.sort).to eq(expected_ids.sort), "Mismatch for grade #{grade} in #{vulnerable_key}"
            end
          end

          it 'includes subgroup projects when include_subgroups is true' do
            result = described_class.grades_for([group], include_subgroups: true)
            grade_d = result[group].find { |g| g.grade == 'd' }

            expect(grade_d).not_to be_nil
            expect(grade_d.project_ids).to include(projects_list[:project_6_subgroup].id)
          end
        end
      end
    end

    context 'when no grades match the filter' do
      let(:vulnerable) { group }
      let(:filter) { :nonexistent_grade }

      it 'returns grades with empty project lists' do
        result = described_class.grades_for([vulnerable], filter: filter, include_subgroups: false)

        expect(result[vulnerable]).to all(be_a(described_class))
        expect(result[vulnerable].flat_map(&:project_ids)).to be_empty
      end
    end

    context 'when vulnerable responds to #projects and returns no projects' do
      let(:vulnerable) do
        Class.new do
          def projects
            Project.none
          end
        end.new
      end

      it 'returns empty grades' do
        result = described_class.grades_for([vulnerable])
        expect(result[vulnerable]).to all(be_a(described_class))
        expect(result[vulnerable].flat_map(&:project_ids)).to be_empty
      end
    end

    context 'when vulnerable responds to #project' do
      let(:project_vulnerable) { create(:project) }
      let(:vulnerables) { [project_vulnerable] }

      it 'returns only one grade if statistics exist' do
        create(:vulnerability_statistic, :grade_a, project: project_vulnerable)

        result = described_class.grades_for(vulnerables)

        expect(result[project_vulnerable].size).to eq(1)
        expect(result[project_vulnerable].first.grade).to eq('a')
        expect(result[project_vulnerable].first.project_ids).to eq([project_vulnerable.id])
      end

      it 'returns empty list when there is no matching grade' do
        result = described_class.grades_for(vulnerables)

        expect(result[project_vulnerable]).to eq([])
      end
    end

    it 'does not execute N+1 queries when loading multiple grades for same vulnerable' do
      described_class.grades_for([group])

      control = ActiveRecord::QueryRecorder.new do
        described_class.grades_for([group])
      end

      expect do
        described_class.grades_for([group])
      end.not_to exceed_query_limit(control)
    end

    context 'when all vulnerables are nil or empty' do
      it 'raises ArgumentError for empty vulnerables' do
        expect { described_class.grades_for([]) }
          .to raise_error(ArgumentError, /No vulnerable entities provided/)
      end

      it 'raises ArgumentError when only nils are passed' do
        expect { described_class.grades_for([nil, nil]) }
          .to raise_error(ArgumentError, /No vulnerable entities provided/)
      end
    end

    context 'when vulnerables are of mixed types' do
      it 'ignores nil values when checking types' do
        expect do
          described_class.grades_for([create(:group), nil])
        end.not_to raise_error
      end
    end
  end
end
