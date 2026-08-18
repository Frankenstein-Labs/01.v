# frozen_string_literal: true

# These shared examples verify that vulnerability statistics and historical
# statistics only reflect vulnerability counts from the default branch.
# Activity on non-default tracked branches should NOT change the snapshots.
#
# The filtering strategy matches tracked contexts by the project's actual
# default branch name rather than relying on the is_default column, which
# may contain duplicates until the cleanup BBM is finalized.
RSpec.shared_examples 'statistics filtered by tracked context' do
  let_it_be(:project, freeze: false) { create(:project, :repository) }
  let_it_be(:default_branch_name, freeze: false) { project.default_branch }

  let_it_be(:default_context, freeze: false) do
    create(:security_project_tracked_context, :default,
      project: project, context_name: default_branch_name)
  end

  let_it_be(:non_default_context, freeze: false) do
    create(:security_project_tracked_context, :tracked,
      project: project, context_name: 'release-1.0')
  end

  around do |example|
    travel_to(Date.current) { example.run }
  end

  describe 'AdjustmentWorker full chain' do
    subject(:run_adjustment) do
      Vulnerabilities::Statistics::AdjustmentWorker.new.perform([project.id])
    end

    context 'when only the default branch has vulnerabilities' do
      let_it_be(:default_vuln_critical, freeze: false) do
        create(:vulnerability_read,
          project: project,
          severity: :critical,
          state: :detected,
          tracked_context: default_context)
      end

      let_it_be(:default_vuln_high, freeze: false) do
        create(:vulnerability_read,
          project: project,
          severity: :high,
          state: :detected,
          tracked_context: default_context)
      end

      it 'creates a historical snapshot reflecting default branch counts' do
        expect { run_adjustment }
          .to change { Vulnerabilities::HistoricalStatistic.where(project: project).count }.by(1)

        hist = Vulnerabilities::HistoricalStatistic.find_by(project: project)
        expect(hist).to have_attributes(
          total: 2,
          critical: 1,
          high: 1,
          medium: 0,
          low: 0,
          unknown: 0,
          info: 0,
          letter_grade: 'f',
          date: Date.current
        )
      end
    end

    context 'when both default and non-default branches have vulnerabilities' do
      let_it_be(:default_vuln, freeze: false) do
        create(:vulnerability_read,
          project: project,
          severity: :critical,
          state: :detected,
          tracked_context: default_context)
      end

      let_it_be(:non_default_vuln_high, freeze: false) do
        create(:vulnerability_read,
          project: project,
          severity: :high,
          state: :detected,
          tracked_context: non_default_context)
      end

      let_it_be(:non_default_vuln_medium, freeze: false) do
        create(:vulnerability_read,
          project: project,
          severity: :medium,
          state: :detected,
          tracked_context: non_default_context)
      end

      it 'only counts default branch vulnerabilities in the historical snapshot' do
        run_adjustment

        hist = Vulnerabilities::HistoricalStatistic.find_by(project: project)

        expect(hist).to have_attributes(
          total: 1,
          critical: 1,
          high: 0,
          medium: 0
        )
      end
    end

    context 'when vulnerabilities exist ONLY on a non-default branch' do
      let_it_be(:non_default_vuln, freeze: false) do
        create(:vulnerability_read,
          project: project,
          severity: :high,
          state: :detected,
          tracked_context: non_default_context)
      end

      it 'creates a historical snapshot with zero counts' do
        run_adjustment

        hist = Vulnerabilities::HistoricalStatistic.find_by(project: project)

        expect(hist).to have_attributes(
          total: 0,
          high: 0,
          letter_grade: 'a'
        )
      end
    end

    context 'when there are duplicate default tracked contexts' do
      let_it_be(:dup_project, freeze: false) { create(:project, :repository) }

      let_it_be(:correct_context, freeze: false) do
        create(:security_project_tracked_context, :default,
          project: dup_project, context_name: dup_project.default_branch)
      end

      let_it_be(:stale_context, freeze: false) do
        create(:security_project_tracked_context, :default,
          project: dup_project, context_name: 'old-main')
      end

      let_it_be(:correct_vuln, freeze: false) do
        create(:vulnerability_read,
          project: dup_project,
          severity: :critical,
          state: :detected,
          tracked_context: correct_context)
      end

      let_it_be(:stale_vuln, freeze: false) do
        create(:vulnerability_read,
          project: dup_project,
          severity: :high,
          state: :detected,
          tracked_context: stale_context)
      end

      subject(:run_adjustment) do
        Vulnerabilities::Statistics::AdjustmentWorker.new.perform([dup_project.id])
      end

      it 'only counts vulnerabilities on the actual default branch, not stale duplicates' do
        run_adjustment

        hist = Vulnerabilities::HistoricalStatistic.find_by(project: dup_project)

        expect(hist).to have_attributes(
          total: 1,
          critical: 1,
          high: 0
        )
      end
    end
  end

  describe 'legacy vulnerability_reads without tracked context' do
    let_it_be(:legacy_vuln, freeze: false) do
      create(:vulnerability_read,
        project: project,
        severity: :high,
        state: :detected,
        tracked_context: nil)
    end

    it 'includes legacy reads (NULL tracked context) in the count' do
      Vulnerabilities::Statistics::AdjustmentService.execute([project.id])

      stat = Vulnerabilities::Statistic.find_by(project: project)

      expect(stat).to have_attributes(
        total: 1,
        high: 1
      )
    end
  end
end
