# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Flag, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:finding).class_name('Vulnerabilities::Finding').with_foreign_key('vulnerability_occurrence_id').required }
    it { is_expected.to belong_to(:workflow).class_name('::Ai::DuoWorkflows::Workflow').optional }
  end

  describe 'validations' do
    subject { build(:vulnerabilities_flag) }

    it { is_expected.to validate_length_of(:origin).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(100000) }
    it { is_expected.to validate_presence_of(:flag_type) }
    it { is_expected.to validate_uniqueness_of(:flag_type).scoped_to(:vulnerability_occurrence_id, :origin).ignoring_case_sensitivity }
    it { is_expected.to validate_inclusion_of(:confidence_score).in_range(0.0..1.0) }
    it { is_expected.to define_enum_for(:flag_type).with_values(false_positive: 0) }
    it { is_expected.to define_enum_for(:status).with_values(described_class::FALSE_POSITIVE_DETECTION_STATUSES) }
  end

  describe '#initialize' do
    it 'creates a valid flag with flag_type attribute' do
      flag = described_class.new(flag_type: described_class.flag_types[:false_positive], origin: 'post analyzer X', description: 'static string to sink', finding: build(:vulnerabilities_finding))
      expect(flag).to be_valid
    end
  end

  context 'with loose foreign key on vulnerability_flags.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerabilities_flag, project_id: parent.id) }
    end
  end

  describe '.by_finding_id' do
    let!(:finding) { create(:vulnerabilities_finding) }
    let!(:vulnerability_flag) { create(:vulnerabilities_flag, finding: finding) }
    let!(:another_vulnerability_flag) { create(:vulnerabilities_flag) }

    subject { described_class.by_finding_id(finding.id) }

    it { is_expected.to contain_exactly(vulnerability_flag) }
  end

  describe '.latest' do
    let_it_be(:finding) { create(:vulnerabilities_finding) }
    let_it_be(:older_flag) { create(:vulnerabilities_flag, finding: finding, origin: 'origin_a', updated_at: 2.days.ago) }
    let_it_be(:newer_flag) { create(:vulnerabilities_flag, finding: finding, origin: 'origin_b', updated_at: 1.day.ago) }

    subject(:latest_flags) { described_class.where(finding: finding).latest }

    it 'returns flags ordered by updated_at descending' do
      expect(latest_flags).to eq([newer_flag, older_flag])
    end
  end

  describe '.with_status' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:detected_flag) do
      create(:vulnerabilities_flag, :false_positive, status: :detected_as_fp)
    end

    let_it_be(:dismissed_flag) do
      create(:vulnerabilities_flag, :false_positive, status: :dismissed)
    end

    let_it_be(:failed_flag) do
      create(:vulnerabilities_flag, :false_positive, status: :failed)
    end

    where(:status, :expected) do
      :detected_as_fp | -> { [detected_flag] }
      :dismissed      | -> { [dismissed_flag] }
      :failed         | -> { [failed_flag] }
    end

    with_them do
      subject(:scope) { described_class.with_status(status) }

      it 'returns only flags with the given status' do
        expect(scope).to match_array(instance_exec(&expected))
      end
    end
  end

  describe '#dismissable?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:finding) { create(:vulnerabilities_finding, project: project) }

    it 'returns true for detected_as_fp status' do
      flag = create(:vulnerabilities_flag, finding: finding, status: :detected_as_fp, confidence_score: 0.8, origin: 'o1')
      expect(flag.dismissable?).to be true
    end

    it 'returns true for detected_as_not_fp status' do
      flag = create(:vulnerabilities_flag, finding: finding, status: :detected_as_not_fp, confidence_score: 0.0, origin: 'o2')
      expect(flag.dismissable?).to be true
    end

    it 'returns false for not_started status' do
      flag = create(:vulnerabilities_flag, finding: finding, status: :not_started, confidence_score: 0.8, origin: 'o3')
      expect(flag.dismissable?).to be false
    end

    it 'returns false for dismissed status' do
      flag = create(:vulnerabilities_flag, finding: finding, status: :dismissed, confidence_score: 0.0, origin: 'o4')
      expect(flag.dismissable?).to be false
    end

    it 'returns false for failed status' do
      flag = create(:vulnerabilities_flag, finding: finding, status: :failed, confidence_score: 0.0, origin: 'o5')
      expect(flag.dismissable?).to be false
    end
  end

  describe '#triggers_resolution_workflow?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:finding) { create(:vulnerabilities_finding, project: project) }

    it 'returns true for failed status' do
      flag = create(:vulnerabilities_flag, finding: finding, status: :failed, confidence_score: 0.0, origin: 'o8')
      expect(flag.triggers_resolution_workflow?).to be true
    end

    it 'returns true for detected_as_not_fp status' do
      flag = create(:vulnerabilities_flag, finding: finding, status: :detected_as_not_fp, confidence_score: 0.0, origin: 'o9')
      expect(flag.triggers_resolution_workflow?).to be true
    end

    it 'returns false for detected_as_fp status' do
      flag = create(:vulnerabilities_flag, finding: finding, status: :detected_as_fp, confidence_score: 0.8, origin: 'o10')
      expect(flag.triggers_resolution_workflow?).to be false
    end

    it 'returns false for dismissed status' do
      flag = create(:vulnerabilities_flag, finding: finding, status: :dismissed, confidence_score: 0.0, origin: 'o11')
      expect(flag.triggers_resolution_workflow?).to be false
    end
  end

  describe '.last_false_positive_per_finding' do
    let_it_be(:finding1) { create(:vulnerabilities_finding) }
    let_it_be(:finding2) { create(:vulnerabilities_finding) }

    let_it_be(:f1_old) { create(:vulnerabilities_flag, :false_positive, finding: finding1, origin: 'o1') }
    let_it_be(:f1_new) { create(:vulnerabilities_flag, :false_positive, finding: finding1, origin: 'o2') }
    let_it_be(:f2_old) { create(:vulnerabilities_flag, :false_positive, finding: finding2, origin: 'o3') }
    let_it_be(:f2_new) { create(:vulnerabilities_flag, :false_positive, finding: finding2, origin: 'o4') }

    subject(:results) { described_class.last_false_positive_per_finding }

    it 'returns the latest flag per finding' do
      expect(results).to contain_exactly(f1_new, f2_new)
    end
  end

  describe '.pluck_with_limit' do
    let_it_be(:finding1) { create(:vulnerabilities_finding) }
    let_it_be(:finding2) { create(:vulnerabilities_finding) }

    let_it_be(:flag1) { create(:vulnerabilities_flag, finding: finding1) }
    let_it_be(:flag2) { create(:vulnerabilities_flag, finding: finding2) }

    it 'returns the requested columns limited by size' do
      expect(
        described_class.where(id: [flag1.id, flag2.id]).pluck_with_limit(2, :id, :flag_type)
      ).to match_array([
        [flag1.id, flag1.flag_type],
        [flag2.id, flag2.flag_type]
      ])
    end
  end

  describe 'after_commit callback for trigger_resolution_workflow' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability) { create(:vulnerability, project: project, author: user) }
    let_it_be(:finding) { create(:vulnerabilities_finding, project: project, vulnerability: vulnerability) }

    context 'when a vulnerability flag gets created' do
      context 'when duo_sast_vr_workflow_enabled is disabled' do
        before do
          project.project_setting.update!(duo_sast_vr_workflow_enabled: false)
        end

        it 'does not trigger resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .not_to receive(:perform_async)

          create(:vulnerabilities_flag, finding: finding, status: :failed, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
        end
      end

      context 'when origin is ai_sast_fp_detection' do
        before do
          project.project_setting.update!(duo_sast_vr_workflow_enabled: true)
        end

        context 'when status triggers resolution workflow' do
          context 'when finding is eligible for resolution workflow' do
            before do
              allow(finding).to receive(:eligible_for_resolution_workflow?).and_return(true)
              allow(Ability).to receive(:allowed?).and_call_original
              allow(Ability).to receive(:allowed?)
                .with(anything, :duo_workflow, project).and_return(true)
            end

            it 'triggers resolution workflow' do
              expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                .to receive(:perform_async)
                      .with(anything)

              create(:vulnerabilities_flag, finding: finding, status: :failed, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
            end

            context 'when author does not have duo_workflow permission' do
              before do
                allow(Ability).to receive(:allowed?).with(user, :duo_workflow, project).and_return(false)
              end

              it 'does not trigger resolution workflow' do
                expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                  .not_to receive(:perform_async)

                create(:vulnerabilities_flag, finding: finding, status: :failed, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
              end
            end

            context 'when finding has no vulnerability' do
              before do
                allow(finding).to receive(:vulnerability).and_return(nil)
              end

              it 'does not trigger resolution workflow' do
                expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                  .not_to receive(:perform_async)

                create(:vulnerabilities_flag, finding: finding, status: :failed, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
              end
            end

            context 'when author has duo_workflow permission' do
              before do
                allow(Ability).to receive(:allowed?).with(user, :duo_workflow, project).and_return(true)
              end

              it 'triggers resolution workflow' do
                expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                  .to receive(:perform_async)
                        .with(anything)

                create(:vulnerabilities_flag, finding: finding, status: :failed, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
              end
            end

            context 'with a latest bulk SAST FP execution' do
              let(:execution) do
                instance_double(
                  ::Vulnerabilities::BulkDuoWorkflow::ExecutionState,
                  contains_item?: contains_item
                )
              end

              before do
                allow(::Vulnerabilities::BulkDuoWorkflow::ExecutionState)
                  .to receive(:latest)
                        .with(
                          project_id: project.id,
                          workflow: ::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION
                        )
                        .and_return(execution)
              end

              context 'when the execution contains the finding' do
                let(:contains_item) { true }

                it 'does not trigger resolution workflow' do
                  expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                    .not_to receive(:perform_async)

                  create(
                    :vulnerabilities_flag,
                    finding: finding,
                    status: :failed,
                    origin: described_class::AI_SAST_FP_DETECTION_ORIGIN
                  )
                end
              end

              context 'when the execution does not contain the finding' do
                let(:contains_item) { false }

                it 'triggers resolution workflow' do
                  expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                    .to receive(:perform_async)
                          .with(anything)

                  create(
                    :vulnerabilities_flag,
                    finding: finding,
                    status: :failed,
                    origin: described_class::AI_SAST_FP_DETECTION_ORIGIN
                  )
                end
              end
            end
          end

          context 'when finding is not eligible for resolution workflow' do
            before do
              allow(finding).to receive(:eligible_for_resolution_workflow?).and_return(false)
            end

            it 'does not trigger resolution workflow' do
              expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
                .not_to receive(:perform_async)

              create(:vulnerabilities_flag, finding: finding, status: :failed, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
            end
          end
        end

        context 'when status is detected_as_fp' do
          it 'does not trigger resolution workflow' do
            expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
              .not_to receive(:perform_async)

            create(:vulnerabilities_flag, finding: finding, status: :detected_as_fp, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
          end
        end

        context 'when status is dismissed' do
          it 'does not trigger resolution workflow' do
            expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
              .not_to receive(:perform_async)

            create(:vulnerabilities_flag, finding: finding, status: :dismissed, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN)
          end
        end
      end

      context 'when origin is not ai_sast_fp_detection' do
        it 'does not trigger resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .not_to receive(:perform_async)

          create(:vulnerabilities_flag, finding: finding, status: :failed, origin: 'some_other_origin')
        end
      end
    end

    context 'when updating an existing vulnerability flag' do
      let_it_be(:existing_flag, freeze: false) { create(:vulnerabilities_flag, finding: finding, status: :not_started, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN) }

      before do
        project.project_setting.update!(duo_sast_vr_workflow_enabled: true)
      end

      context 'when only non-relevant fields are updated' do
        it 'does not trigger resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .not_to receive(:perform_async)

          existing_flag.update!(description: 'Updated description')
        end
      end

      context 'when status is updated to a trigger status' do
        before do
          allow(finding).to receive(:eligible_for_resolution_workflow?).and_return(true)
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?)
            .with(anything, :duo_workflow, project).and_return(true)
        end

        it 'triggers resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .to receive(:perform_async)
                  .with(existing_flag.id)

          existing_flag.update!(status: :failed)
        end
      end

      context 'when origin changes to non-ai origin' do
        it 'does not trigger resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .not_to receive(:perform_async)

          existing_flag.update!(origin: 'some_other_origin')
        end
      end

      context 'when status changes to a non-trigger status' do
        it 'does not trigger resolution workflow' do
          expect(::Vulnerabilities::TriggerResolutionWorkflowWorker)
            .not_to receive(:perform_async)

          existing_flag.update!(status: :detected_as_fp)
        end
      end
    end
  end

  describe '#should_trigger_resolution_workflow?' do
    let(:project) { create(:project) }
    let(:user) { create(:user) }
    let(:vulnerability) { create(:vulnerability, project: project, author: user) }
    let(:finding) { create(:vulnerabilities_finding, project: project, vulnerability: vulnerability) }
    let(:flag) { create(:vulnerabilities_flag, finding: finding, status: :failed, origin: described_class::AI_SAST_FP_DETECTION_ORIGIN) }

    before do
      project.project_setting.update!(duo_sast_vr_workflow_enabled: true)
      allow(finding).to receive(:eligible_for_resolution_workflow?).and_return(true)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
        .with(anything, :duo_workflow, project).and_return(true)
    end

    context 'when status is updated' do
      it 'considers status change as trigger for resolution workflow' do
        flag # ensure created
        flag.status = :failed
        allow(flag).to receive_messages(saved_change_to_id?: false, saved_change_to_status?: true)

        expect(flag.send(:should_trigger_resolution_workflow?)).to be true
      end
    end

    context 'when non-status fields are updated' do
      it 'does not consider non-status changes as trigger' do
        flag # ensure created
        allow(flag).to receive_messages(saved_change_to_id?: false, saved_change_to_status?: false)

        expect(flag.send(:should_trigger_resolution_workflow?)).to be false
      end
    end
  end
end
