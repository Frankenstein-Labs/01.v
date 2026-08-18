# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::AddApproversToRulesWorker, feature_category: :security_policy_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:project_id) { project.id }
  let(:project_ids) { [project_id] }
  let(:user_ids) { [user.id] }
  let(:data) { { project_ids: project_ids, user_ids: user_ids } }
  let(:authorizations_event) { ProjectAuthorizations::AuthorizationsAddedEvent.new(data: data) }
  let(:licensed_feature) { true }

  before do
    stub_licensed_features(security_orchestration_policies: licensed_feature)
  end

  it_behaves_like 'subscribes to event' do
    let(:event) { authorizations_event }

    before do
      create(:scan_result_policy_read, project: project)
    end

    it 'calls Security::ScanResultPolicies::AddApproversToRulesService' do
      expect_next_instance_of(
        Security::ScanResultPolicies::AddApproversToRulesService,
        project: project
      ) do |service|
        expect(service).to receive(:execute).with([user.id])
      end

      consume_event(subscriber: described_class, event: authorizations_event)
    end

    context 'with multiple projects' do
      let_it_be(:another_project) { create(:project) }
      let(:project_ids) { [project.id, another_project.id] }

      context 'when all projects has scan_result_policy_reads' do
        before do
          create(:scan_result_policy_read, project: another_project)
        end

        it 'calls Security::ScanResultPolicies::AddApproversToRulesService for all projects' do
          expect_next_instance_of(
            Security::ScanResultPolicies::AddApproversToRulesService,
            project: project
          ) do |service|
            expect(service).to receive(:execute).with([user.id])
          end

          expect_next_instance_of(
            Security::ScanResultPolicies::AddApproversToRulesService,
            project: another_project
          ) do |service|
            expect(service).to receive(:execute).with([user.id])
          end

          consume_event(subscriber: described_class, event: authorizations_event)
        end
      end

      context 'when only one project has scan_result_policy_reads' do
        it 'calls Security::ScanResultPolicies::AddApproversToRulesService for project with scan_result_policy_reads' do
          expect_next_instance_of(
            Security::ScanResultPolicies::AddApproversToRulesService,
            project: project
          ) do |service|
            expect(service).to receive(:execute).with([user.id])
          end

          consume_event(subscriber: described_class, event: authorizations_event)
        end
      end
    end
  end

  context 'when the project does not exist' do
    let(:project_id) { non_existing_record_id }

    it 'does not call Security::ScanResultPolicies::AddApproversToRulesService' do
      expect(Security::ScanResultPolicies::AddApproversToRulesService).not_to receive(:new)

      expect { consume_event(subscriber: described_class, event: authorizations_event) }.not_to raise_exception
    end
  end

  context 'when the user_ids are empty' do
    let(:user_ids) { [] }

    it 'does not call Security::ScanResultPolicies::AddApproversToRulesService' do
      expect(Security::ScanResultPolicies::AddApproversToRulesService).not_to receive(:new)

      expect { consume_event(subscriber: described_class, event: authorizations_event) }.not_to raise_exception
    end
  end

  context 'when the feature is not licensed' do
    let(:licensed_feature) { false }

    it 'does not call Security::ScanResultPolicies::AddApproversToRulesService' do
      expect(Security::ScanResultPolicies::AddApproversToRulesService).not_to receive(:new)

      expect { consume_event(subscriber: described_class, event: authorizations_event) }.not_to raise_exception
    end
  end

  describe '.projects' do
    context 'when event data contains project_id' do
      let(:data) { { project_id: project.id, user_ids: user_ids } }

      it 'returns projects with the given project_id' do
        expect(described_class.projects(authorizations_event)).to contain_exactly(project)
      end
    end

    context 'when event data contains project_ids' do
      let_it_be(:another_project) { create(:project) }
      let(:project_ids) { [project.id, another_project.id] }

      it 'returns projects with the given project_ids' do
        expect(described_class.projects(authorizations_event)).to contain_exactly(project, another_project)
      end
    end
  end

  describe '.dispatch?' do
    subject { described_class.dispatch?(authorizations_event) }

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it { is_expected.to be_falsey }
    end

    context 'when project exists' do
      context 'when feature is not licensed' do
        let(:licensed_feature) { false }

        it { is_expected.to be_falsey }
      end

      context 'when feature is licensed' do
        let(:licensed_feature) { true }

        context 'when project does not have scan_result_policy_reads' do
          it { is_expected.to be_falsey }
        end

        context 'when project has scan_result_policy_reads' do
          before do
            create(:scan_result_policy_read, project: project)
          end

          it { is_expected.to be true }
        end

        context 'with multiple projects' do
          it 'executes 2 queries' do
            project1 = create(:project)
            create(:scan_result_policy_read, project: project1)

            data = { project_ids: [project1.id], user_ids: user_ids }
            event = ProjectAuthorizations::AuthorizationsAddedEvent.new(data: data)
            control = ActiveRecord::QueryRecorder.new { described_class.dispatch?(event) }
            # There are 4 queries but since we stub licensed_features, we assert 3 queries
            expect(control.count).to eq(3)

            projects = create_list(:project, 5)
            data = { project_ids: projects.map(&:id), user_ids: user_ids }
            event = ProjectAuthorizations::AuthorizationsAddedEvent.new(data: data)
            expect do
              described_class.dispatch?(event)
            end.to issue_same_number_of_queries_as(control).allow_skip_cache_inconsistency
          end
        end
      end
    end

    context 'with project_id' do
      let(:data) { { project_id: project.id, user_ids: user_ids } }

      context 'when project has scan_result_policy_reads' do
        before do
          create(:scan_result_policy_read, project: project)
        end

        it { is_expected.to be true }
      end

      context 'when project does not have scan_result_policy_reads' do
        it { is_expected.to be_falsey }
      end
    end

    context 'with multiple projects' do
      let_it_be(:another_project) { create(:project) }
      let(:project_ids) { [project.id, another_project.id] }

      context 'when another_project does not have scan_result_policy_reads' do
        before do
          create(:scan_result_policy_read, project: project)
        end

        it { is_expected.to be true }
      end

      context 'when no project has scan_result_policy_reads' do
        it { is_expected.to be_falsey }
      end
    end

    context 'without project_id and project_ids in event data' do
      let(:data) { { user_ids: user_ids } }

      it { is_expected.to be_falsey }
    end
  end
end
