# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Statistics::AdjustmentService, feature_category: :vulnerability_management do
  let_it_be_with_refind(:project) { create(:project) }

  describe '.execute' do
    let(:project_ids) { [1, 2, 3] }
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute_for_project_ids) { described_class.execute(project_ids) }

    before do
      allow(described_class).to receive(:new).with([1, 2, 3]).and_return(mock_service_object)
    end

    it 'instantiates the service object for given project ids and calls `execute` on them' do
      execute_for_project_ids

      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:statistics) { project.vulnerability_statistic.as_json(only: expected_statistics.keys) }
    let(:project_ids) { [project.id] }

    subject(:adjust_statistics) { described_class.new(project_ids).execute }

    shared_examples_for 'ignoring the non-existing project IDs' do
      let(:project_ids) { [non_existing_record_id, project.id] }

      it 'does not raise an exception' do
        expect { adjust_statistics }.not_to raise_error
      end

      it 'adjusts the statistics for the project with existing IDs' do
        adjust_statistics

        expect(statistics).to eq(expected_statistics)
      end
    end

    context 'when more than 1000 projects is provided' do
      let(:project_ids) { (1..1001).to_a }

      it 'raises error' do
        expect { adjust_statistics }.to raise_error(described_class::TooManyProjectsError, 'Cannot adjust statistics for more than 1000 projects')
      end
    end

    context 'when no project exist for the given ids' do
      let(:project_ids) { [non_existing_record_id] }

      it 'returns empty structure' do
        expect(adjust_statistics).to eq({ diff: [], affected_project_ids: [] })
      end
    end

    context 'when the project has detected and confirmed vulnerabilities' do
      let(:expected_statistics) do
        {
          'total' => 2,
          'critical' => 1,
          'high' => 1,
          'medium' => 0,
          'low' => 0,
          'info' => 0,
          'unknown' => 0,
          'letter_grade' => 'f'
        }
      end

      before do
        create(:vulnerability, :with_finding, :critical_severity, project: project)
        create(:vulnerability, :with_finding, :high_severity, project: project)
        create(:vulnerability, :with_finding, :medium_severity, project: project, present_on_default_branch: false)
      end

      context 'when there is no vulnerability_statistic record for project' do
        let_it_be_with_refind(:project) { create(:project, archived: true) }

        it 'creates a new record' do
          expect { adjust_statistics }.to change { Vulnerabilities::Statistic.count }.by(1)
        end

        it 'sets the correct values for the record' do
          adjust_statistics

          expect(statistics).to eq(expected_statistics)

          expect(project.vulnerability_statistic).to have_attributes(
            archived: project.archived, traversal_ids: project.namespace.traversal_ids)
        end

        it_behaves_like 'ignoring the non-existing project IDs'
      end

      context 'when there is already a vulnerability_statistic record for project' do
        before_all do
          create(:vulnerability_statistic, project: project, critical: 0, total: 0)
        end

        it 'does not create a new record in database' do
          expect { adjust_statistics }.not_to change { Vulnerabilities::Statistic.count }
        end

        it 'sets the correct values for the record' do
          adjust_statistics

          expect(statistics).to eq(expected_statistics)
        end

        it_behaves_like 'ignoring the non-existing project IDs'
      end
    end

    context 'when the project does not have any detected or confirmed vulnerabilities' do
      let(:expected_statistics) do
        {
          'total' => 0,
          'critical' => 0,
          'high' => 0,
          'medium' => 0,
          'low' => 0,
          'info' => 0,
          'unknown' => 0,
          'letter_grade' => 'a'
        }
      end

      before do
        create(:vulnerability, :with_finding, :dismissed, :critical_severity, project: project)
      end

      context 'when there is no vulnerability_statistic record for project' do
        it 'creates a new record' do
          expect { adjust_statistics }.to change { Vulnerabilities::Statistic.count }.by(1)
        end

        it 'sets the correct values for the record' do
          adjust_statistics

          expect(statistics).to eq(expected_statistics)
        end

        it_behaves_like 'ignoring the non-existing project IDs'
      end

      context 'when there is already a vulnerability_statistic record for project' do
        before_all do
          create(:vulnerability_statistic, project: project, critical: 1, total: 1, letter_grade: 'f')
        end

        it 'does not create a new record in database' do
          expect { adjust_statistics }.not_to change { Vulnerabilities::Statistic.count }
        end

        it 'sets the correct values for the record' do
          adjust_statistics

          expect(statistics).to eq(expected_statistics)
        end

        it_behaves_like 'ignoring the non-existing project IDs'
      end
    end

    context 'with the diff return value' do
      let_it_be(:namespace) { project.namespace }
      let(:result) { adjust_statistics }
      let(:diffs) { result[:diff] }
      let(:affected_project_ids) { result[:affected_project_ids] }

      context 'when statistics change' do
        before do
          create(:vulnerability, :with_finding, :critical_severity, project: project)
          create(:vulnerability, :with_finding, :high_severity, project: project)
        end

        context 'with a single project' do
          it 'returns namespace diff with project_ids array' do
            expect(diffs).to contain_exactly(
              hash_including(
                'namespace_id' => namespace.id,
                'traversal_ids' => "{#{namespace.traversal_ids.join(',')}}",
                'total' => 2,
                'critical' => 1,
                'high' => 1,
                'medium' => 0,
                'low' => 0,
                'info' => 0,
                'unknown' => 0
              )
            )
          end

          it 'returns affected_project_ids containing the project' do
            expect(affected_project_ids).to eq([project.id])
          end
        end

        context 'with multiple projects in the same namespace' do
          let_it_be(:project2) { create(:project, namespace: namespace) }
          let(:project_ids) { [project.id, project2.id] }

          before do
            create(:vulnerability, :with_finding, :medium_severity, project: project2)
          end

          it 'returns namespace diff with all affected project_ids' do
            expect(diffs).to contain_exactly(
              hash_including(
                'namespace_id' => namespace.id,
                'traversal_ids' => "{#{namespace.traversal_ids.join(',')}}",
                'total' => 3,
                'critical' => 1,
                'high' => 1,
                'medium' => 1,
                'low' => 0,
                'info' => 0,
                'unknown' => 0
              )
            )
          end

          it 'returns affected_project_ids containing both projects' do
            expect(affected_project_ids).to match_array([project.id, project2.id])
          end
        end

        context 'with multiple projects across different namespaces' do
          let_it_be(:namespace2) { create(:namespace) }
          let_it_be(:project2) { create(:project, namespace: namespace2) }
          let(:project_ids) { [project.id, project2.id] }

          before do
            create(:vulnerability, :with_finding, :low_severity, project: project2)
          end

          it 'returns diffs for each namespace with only their affected project_ids' do
            result_by_namespace = diffs.index_by { |row| row['namespace_id'] }

            expect(result_by_namespace[namespace.id]).to include(
              'namespace_id' => namespace.id,
              'traversal_ids' => "{#{namespace.traversal_ids.join(',')}}",
              'total' => 2,
              'critical' => 1,
              'high' => 1,
              'medium' => 0,
              'low' => 0,
              'info' => 0,
              'unknown' => 0
            )

            expect(result_by_namespace[namespace2.id]).to include(
              'namespace_id' => namespace2.id,
              'traversal_ids' => "{#{namespace2.traversal_ids.join(',')}}",
              'total' => 1,
              'critical' => 0,
              'high' => 0,
              'medium' => 0,
              'low' => 1,
              'info' => 0,
              'unknown' => 0
            )
          end

          it 'returns all affected_project_ids' do
            expect(affected_project_ids).to match_array([project.id, project2.id])
          end
        end

        context 'when updating existing statistics' do
          before do
            create(:vulnerability_statistic, project: project, critical: 2, high: 0, total: 2)
          end

          it 'returns the diff values (new - old)' do
            expect(diffs).to contain_exactly(
              hash_including(
                'namespace_id' => namespace.id,
                'traversal_ids' => "{#{namespace.traversal_ids.join(',')}}",
                'total' => 0,      # was 2, now 2, diff = 0
                'critical' => -1,  # was 2, now 1, diff = -1
                'high' => 1,       # was 0, now 1, diff = 1
                'medium' => 0,
                'low' => 0,
                'info' => 0,
                'unknown' => 0
              )
            )
          end

          it 'includes project in affected_project_ids' do
            expect(affected_project_ids).to eq([project.id])
          end
        end
      end

      context 'when no statistics change' do
        context 'when vulnerabilities match existing statistics' do
          before do
            create(:vulnerability_statistic, project: project, total: 1, high: 1)
            create(:vulnerability, :with_finding, :high_severity, project: project)
          end

          it 'returns empty diff array when no diffs exist' do
            expect(diffs).to eq([])
          end

          it 'returns empty affected_project_ids' do
            expect(affected_project_ids).to eq([])
          end
        end
      end

      context 'with non-existing project IDs' do
        let(:project_ids) { [non_existing_record_id, project.id] }

        before do
          create(:vulnerability, :with_finding, :critical_severity, project: project)
        end

        it 'only includes existing project ids in the project_ids array' do
          expect(diffs).to contain_exactly(
            hash_including(
              'namespace_id' => namespace.id,
              'traversal_ids' => "{#{namespace.traversal_ids.join(',')}}"
            )
          )
        end

        it 'only includes existing project in affected_project_ids' do
          expect(affected_project_ids).to eq([project.id])
        end
      end

      context 'when some projects have changes and others do not' do
        let_it_be(:project2) { create(:project, namespace: namespace) }
        let_it_be(:project3) { create(:project, namespace: namespace) }
        let(:project_ids) { [project.id, project2.id, project3.id] }

        before do
          create(:vulnerability, :with_finding, :critical_severity, project: project)

          create(:vulnerability_statistic, project: project2, total: 1, medium: 1)
          create(:vulnerability, :with_finding, :medium_severity, project: project2)

          create(:vulnerability_statistic, project: project3, total: 0)
          create(:vulnerability, :with_finding, :low_severity, project: project3)
        end

        it 'includes only projects with changes in namespace project_ids' do
          expect(diffs).to contain_exactly(
            hash_including(
              'namespace_id' => namespace.id,
              'traversal_ids' => "{#{namespace.traversal_ids.join(',')}}",
              'total' => 2,      # +1 from project, +1 from project3
              'critical' => 1,   # +1 from project
              'high' => 0,
              'medium' => 0,
              'low' => 1,        # +1 from project3
              'info' => 0,
              'unknown' => 0
            )
          )
        end

        it 'includes only projects with changes in affected_project_ids' do
          expect(affected_project_ids).to match_array([project.id, project3.id])
        end
      end
    end

    context 'with tracked contexts' do
      let_it_be(:tracked_project) { create(:project, :repository) }
      let_it_be(:default_branch_name) { tracked_project.default_branch }
      let(:project_ids) { [tracked_project.id] }

      let_it_be(:default_context) do
        create(:security_project_tracked_context, :default,
          project: tracked_project, context_name: default_branch_name)
      end

      let_it_be(:non_default_context) do
        create(:security_project_tracked_context, :tracked,
          project: tracked_project, context_name: 'release-1.0')
      end

      context 'when vulnerabilities span default and non-default branches' do
        before do
          create(:vulnerability_read,
            project: tracked_project,
            severity: :critical,
            state: :detected,
            tracked_context: default_context)
          create(:vulnerability_read,
            project: tracked_project,
            severity: :high,
            state: :detected,
            tracked_context: non_default_context)
        end

        it 'only counts default branch vulnerabilities' do
          adjust_statistics

          stat = tracked_project.vulnerability_statistic
          expect(stat).to have_attributes(
            total: 1,
            critical: 1,
            high: 0
          )
        end
      end

      context 'when vulnerability_reads have NULL tracked context (legacy data)' do
        let_it_be(:legacy_project) { create(:project, :repository) }
        let(:project_ids) { [legacy_project.id] }

        before do
          create(:vulnerability_read,
            project: legacy_project,
            severity: :medium,
            state: :detected,
            tracked_context: nil)
        end

        it 'includes legacy reads in the count' do
          adjust_statistics

          stat = legacy_project.vulnerability_statistic
          expect(stat).to have_attributes(
            total: 1,
            medium: 1
          )
        end
      end

      context 'when only non-default branch vulnerabilities exist' do
        let_it_be(:nondefault_only_project) { create(:project, :repository) }
        let_it_be(:nondefault_only_context) do
          create(:security_project_tracked_context, :tracked,
            project: nondefault_only_project, context_name: 'release-2.0')
        end

        let(:project_ids) { [nondefault_only_project.id] }

        before do
          create(:vulnerability_read,
            project: nondefault_only_project,
            severity: :high,
            state: :detected,
            tracked_context: nondefault_only_context)
        end

        it 'produces zero counts' do
          adjust_statistics

          stat = nondefault_only_project.vulnerability_statistic
          expect(stat).to have_attributes(
            total: 0,
            high: 0,
            letter_grade: 'a'
          )
        end
      end

      context 'when there are duplicate default tracked contexts' do
        let_it_be(:dup_project) { create(:project, :repository) }
        let(:project_ids) { [dup_project.id] }

        let_it_be(:correct_context) do
          create(:security_project_tracked_context, :default,
            project: dup_project, context_name: dup_project.default_branch)
        end

        let_it_be(:stale_context) do
          create(:security_project_tracked_context, :default,
            project: dup_project, context_name: 'old-main')
        end

        before do
          create(:vulnerability_read,
            project: dup_project,
            severity: :critical,
            state: :detected,
            tracked_context: correct_context)
          create(:vulnerability_read,
            project: dup_project,
            severity: :high,
            state: :detected,
            tracked_context: stale_context)
        end

        it 'only counts vulnerabilities on the actual default branch context' do
          adjust_statistics

          stat = dup_project.vulnerability_statistic
          expect(stat).to have_attributes(
            total: 1,
            critical: 1,
            high: 0
          )
        end
      end
    end

    context 'when vulnerabilities are no longer detected on the default branch' do
      before do
        create(:vulnerability_read,
          project: project,
          severity: :critical,
          state: :detected,
          resolved_on_default_branch: true,
          tracked_context: nil)
      end

      it 'excludes them from the count' do
        adjust_statistics

        stat = project.vulnerability_statistic
        expect(stat).to have_attributes(
          total: 0,
          critical: 0,
          letter_grade: 'a'
        )
      end
    end

    context 'when a previously counted vulnerability becomes no longer detected' do
      before do
        create(:vulnerability_statistic, project: project, critical: 1, total: 1, letter_grade: 'f')
        create(:vulnerability_read,
          project: project,
          severity: :critical,
          state: :detected,
          resolved_on_default_branch: true,
          tracked_context: nil)
      end

      it 'emits a decrement diff so namespace stats roll down' do
        expect(adjust_statistics[:diff]).to contain_exactly(
          hash_including('critical' => -1, 'total' => -1)
        )
      end
    end
  end
end
