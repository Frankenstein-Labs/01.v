# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::EventStore, feature_category: :shared do
  describe '.instance' do
    it 'returns a store with CE and EE subscriptions' do
      instance = described_class.instance

      expect(instance.subscriptions.keys).to match_array([
        Ai::ActiveContext::Code::CreateEnabledNamespaceEvent,
        Ai::ActiveContext::Code::MarkRepositoryAsReadyEvent,
        Ai::ActiveContext::Code::MarkRepositoryAsPendingDeletionEvent,
        Ai::ActiveContext::Code::ProcessPendingEnabledNamespaceEvent,
        Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent,
        ::Ci::JobArtifactsDeletedEvent,
        ::Ci::JobSecurityScanCompletedEvent,
        ::Ci::PipelineCreatedEvent,
        ::Ci::PipelineFinishedEvent,
        ::Ci::Workloads::WorkloadFinishedEvent,
        ::Ai::DuoWorkflows::WorkflowStartedEvent,
        ::Ai::DuoWorkflows::WorkflowFinishedEvent,
        ::Repositories::KeepAroundRefsCreatedEvent,
        ::MergeRequests::ApprovedEvent,
        ::MergeRequests::ApprovedCloudEvent,
        ::MergeRequests::ReadyEvent,
        ::MergeRequests::MergedEvent,
        ::MergeRequests::AutoMerge::TitleDescriptionUpdateEvent,
        ::MergeRequests::ApprovalsResetEvent,
        ::MergeRequests::DraftStateChangeEvent,
        ::MergeRequests::UnblockedStateEvent,
        ::MergeRequests::OverrideRequestedChangesStateEvent,
        ::MergeRequests::DiscussionsResolvedEvent,
        ::MergeRequests::MergeableEvent,
        ::MergeRequests::PipelineCreationCompletedEvent,
        ::MergeRequests::CodeConflictEvent,
        ::MergeRequests::ViolationsUpdatedEvent,
        ::MergeRequests::ClosedEvent,
        ::MergeRequests::DraftNotePublishedEvent,
        ::GitlabSubscriptions::RenewedEvent,
        ::Repositories::DefaultBranchChangedEvent,
        ::Repositories::RepositoryCreatedEvent,
        ::NamespaceSettings::AiRelatedSettingsChangedEvent,
        ::Mcp::ServerSettingsChangedEvent,
        ::Members::DestroyedEvent,
        ::Members::MembersAddedEvent,
        ::Namespaces::Groups::GroupArchivedEvent,
        ::Namespaces::Groups::GroupPathChangedEvent,
        ::Organizations::ConfirmedEvent,
        ::ProjectAuthorizations::AuthorizationsChangedEvent,
        ::ProjectAuthorizations::AuthorizationsRemovedEvent,
        ::ProjectAuthorizations::AuthorizationsAddedEvent,
        ::Projects::ComplianceFrameworkChangedEvent,
        ::Projects::SecurityAttributeChangedEvent,
        ::ContainerRegistry::ImagePushedEvent,
        ::Cd::ArtifactPublishedEvent,
        Projects::ProjectPathChangedEvent,
        Projects::ProjectTransferedEvent,
        Projects::ProjectVisibilityChangedEvent,
        Groups::GroupTransferedEvent,
        Groups::GroupDeletedEvent,
        Projects::ProjectArchivedEvent,
        Projects::ProjectFeaturesChangedEvent,
        ::Pages::Domains::PagesDomainDeletedEvent,
        Vulnerabilities::LinkToExternalIssueTrackerCreated,
        Vulnerabilities::LinkToExternalIssueTrackerRemoved,
        WorkItems::WorkItemClosedEvent,
        WorkItems::WorkItemCreatedEvent,
        WorkItems::CreatedEvent,
        WorkItems::WorkItemDeletedEvent,
        WorkItems::WorkItemReopenedEvent,
        WorkItems::WorkItemUpdatedEvent,
        WorkItems::StatusChangedEvent,
        PackageMetadata::IngestedAdvisoryEvent,
        MergeRequests::ExternalStatusCheckPassedEvent,
        Packages::PackageCreatedEvent,
        Projects::ProjectCreatedEvent,
        Projects::ProjectDeletedEvent,
        ::Milestones::MilestoneUpdatedEvent,
        ::WorkItems::BulkUpdatedEvent,
        ::Users::ActivityEvent,
        Sbom::VulnerabilitiesCreatedEvent,
        Sbom::SbomIngestedEvent,
        Search::Zoekt::ForceUpdateOverprovisionedIndexEvent,
        Search::Zoekt::IndexMarkedAsReadyEvent,
        Search::Zoekt::IndexMarkedAsToDeleteEvent,
        Search::Zoekt::IndexMarkPendingEvictionEvent,
        Search::Zoekt::IndexToEvictEvent,
        Search::Zoekt::InitialIndexingEvent,
        Search::Zoekt::LostNodeEvent,
        Search::Zoekt::NodeWithNegativeUnclaimedStorageEvent,
        Search::Zoekt::OrphanedIndexEvent,
        Search::Zoekt::OrphanedRepoEvent,
        Search::Zoekt::RepoMarkedAsToDeleteEvent,
        Search::Zoekt::RepoToIndexEvent,
        Search::Zoekt::RepoToReindexEvent,
        Search::Zoekt::TaskFailedEvent,
        Search::Zoekt::UpdateIndexUsedStorageBytesEvent,
        Search::Zoekt::SaasRolloutEvent,
        Search::Zoekt::TooManyReplicasEvent,
        Security::PolicyCreatedEvent,
        Security::PolicyUpdatedEvent,
        Security::PolicyDeletedEvent,
        Security::PolicyResyncEvent,
        Security::PolicyDismissalPreservedEvent,
        Security::ReportsIngestedEvent,
        ::Members::MembershipModifiedByAdminEvent,
        ::Members::UpdatedEvent,
        ::Members::AcceptedInviteEvent,
        Repositories::ProtectedBranchCreatedEvent,
        Repositories::ProtectedBranchDestroyedEvent,
        Vulnerabilities::BulkDismissedEvent,
        Vulnerabilities::BulkRedetectedEvent,
        ::Analytics::ClickHouseForAnalyticsEnabledEvent,
        ::Gitlab::FeatureFlags::FeatureFlagModifiedEvent
      ])
    end
  end

  describe '.publish_group' do
    let(:events) { [] }

    it 'calls publish_group of instance' do
      expect(described_class.instance).to receive(:publish_group).with(events)

      described_class.publish_group(events)
    end
  end

  describe 'virtual registries subscriptions' do
    expected_subscriptions = {
      ::Projects::ProjectDeletedEvent => ::VirtualRegistries::DestroyLocalUpstreamsWorker,
      ::Groups::GroupDeletedEvent => ::VirtualRegistries::DestroyLocalUpstreamsWorker
    }

    subscriptions = described_class.instance.subscriptions

    expected_subscriptions.each do |event_class, worker_class|
      it "subscribes #{worker_class} to #{event_class}" do
        expect(subscriptions[event_class]).to include(have_attributes(worker: worker_class))
      end
    end
  end

  describe 'Vulnerabilities::AutoDismissWorker subscription' do
    let(:subscriptions) { described_class.instance.subscriptions }

    it 'subscribes Vulnerabilities::AutoDismissWorker to Sbom::VulnerabilitiesCreatedEvent' do
      expect(subscriptions[Sbom::VulnerabilitiesCreatedEvent]).to include(
        have_attributes(worker: ::Vulnerabilities::AutoDismissWorker)
      )
    end
  end

  describe 'DependencyManagement::SecurityUpdate::SchedulerWorker subscription',
    feature_category: :dependency_management do
    let(:subscriptions) { described_class.instance.subscriptions }

    it 'subscribes to Sbom::SbomIngestedEvent' do
      expect(subscriptions[Sbom::SbomIngestedEvent]).to include(
        have_attributes(worker: DependencyManagement::SecurityUpdate::SchedulerWorker)
      )
    end
  end

  describe 'TestRunCompletionWorker subscription', feature_category: :security_policy_management do
    let(:subscriptions) { described_class.instance.subscriptions }
    let(:subscription) do
      subscriptions[Ci::PipelineFinishedEvent].find do |s|
        s.worker == Security::PipelineExecutionSchedulePolicies::TestRunCompletionWorker
      end
    end

    let_it_be(:ci_pipeline) { create(:ci_pipeline) }

    it 'subscribes to Ci::PipelineFinishedEvent' do
      expect(subscription).to be_present
    end

    context 'when test run exists for pipeline' do
      before do
        create(:security_pipeline_execution_policy_test_run, pipeline: ci_pipeline)
      end

      it 'returns true' do
        event = Ci::PipelineFinishedEvent.new(data: { pipeline_id: ci_pipeline.id, status: 'success' })

        expect(subscription.condition.call(event)).to be(true)
      end
    end

    context 'when no test run exists for pipeline' do
      it 'returns false' do
        event = Ci::PipelineFinishedEvent.new(data: { pipeline_id: ci_pipeline.id, status: 'success' })

        expect(subscription.condition.call(event)).to be(false)
      end
    end
  end

  describe 'ExecuteCodeConflictAiWorkflowTriggersWorker subscription', feature_category: :code_suggestions do
    let(:subscriptions) { described_class.instance.subscriptions }
    let(:subscription) do
      subscriptions[MergeRequests::CodeConflictEvent].find do |s|
        s.worker == Ai::Catalog::Flows::ExecuteCodeConflictAiWorkflowTriggersWorker
      end
    end

    it 'subscribes to MergeRequests::CodeConflictEvent' do
      expect(subscription).to be_present
    end
  end

  describe 'ExecuteMergeRequestReadyWorkflowTriggersWorker subscription', feature_category: :code_suggestions do
    let(:subscriptions) { described_class.instance.subscriptions }
    let(:subscription) do
      subscriptions[MergeRequests::ReadyEvent]&.find do |s|
        s.worker == Ai::Catalog::Flows::ExecuteMergeRequestReadyWorkflowTriggersWorker
      end
    end

    it 'subscribes to MergeRequests::ReadyEvent' do
      expect(subscription).to be_present
    end
  end

  describe 'ExecuteMergeRequestApprovedWorkflowTriggersWorker subscription', feature_category: :code_suggestions do
    let(:subscriptions) { described_class.instance.subscriptions }
    let(:subscription) do
      subscriptions[MergeRequests::ApprovedCloudEvent]&.find do |s|
        s.worker == Ai::Catalog::Flows::ExecuteMergeRequestApprovedWorkflowTriggersWorker
      end
    end

    it 'subscribes to MergeRequests::ApprovedCloudEvent' do
      expect(subscription).to be_present
    end
  end

  describe 'ExecuteMergeRequestMergedWorkflowTriggersWorker subscription', feature_category: :code_suggestions do
    let(:subscriptions) { described_class.instance.subscriptions }
    let(:subscription) do
      subscriptions[MergeRequests::MergedEvent]&.find do |s|
        s.worker == Ai::Catalog::Flows::ExecuteMergeRequestMergedWorkflowTriggersWorker
      end
    end

    it 'subscribes to MergeRequests::MergedEvent' do
      expect(subscription).to be_present
    end
  end

  describe 'ExecuteWorkItemCreatedWorkflowTriggersWorker subscription', feature_category: :code_suggestions do
    let(:subscriptions) { described_class.instance.subscriptions }
    let(:subscription) do
      subscriptions[WorkItems::CreatedEvent]&.find do |s|
        s.worker == Ai::Catalog::Flows::ExecuteWorkItemCreatedWorkflowTriggersWorker
      end
    end

    it 'subscribes to WorkItems::CreatedEvent' do
      expect(subscription).to be_present
    end

    it 'has a condition that checks for flow triggers' do
      expect(subscription.condition).to be_present
    end

    describe 'subscription condition' do
      let_it_be(:project) { create(:project) }
      let_it_be(:user) { create(:user) }
      let_it_be(:work_item) { create(:work_item, project: project, author: user) }

      let(:cloud_event) do
        WorkItems::CreatedEvent.build(work_item: work_item, current_user: user)
      end

      context 'when the project has a matching flow trigger' do
        let_it_be(:service_account) { create(:service_account) }
        let_it_be(:flow_trigger) do
          create(:ai_flow_trigger,
            project: project,
            user: service_account,
            event_types: [Ai::FlowTrigger::EVENT_TYPES[:work_item]]
          )
        end

        it 'returns true' do
          expect(subscription.condition.call(cloud_event)).to be true
        end
      end

      context 'when the project has no matching flow triggers' do
        it 'returns false' do
          expect(subscription.condition.call(cloud_event)).to be false
        end
      end
    end
  end

  describe 'ExecuteWorkItemStatusChangedWorkflowTriggersWorker subscription', feature_category: :code_suggestions do
    let(:subscriptions) { described_class.instance.subscriptions }
    let(:subscription) do
      subscriptions[WorkItems::StatusChangedEvent].find do |s|
        s.worker == Ai::Catalog::Flows::ExecuteWorkItemStatusChangedWorkflowTriggersWorker
      end
    end

    it 'subscribes to WorkItems::StatusChangedEvent' do
      expect(subscription).to be_present
    end

    it 'only enqueues when the project has a work_item flow trigger' do
      expect(subscription.condition).to be_present
    end

    context 'when the project has a matching trigger' do
      let_it_be(:project) { create(:project) }
      let_it_be(:service_account) { create(:service_account) }
      let_it_be(:work_item) { create(:work_item, project: project) }
      let_it_be(:status) { ::WorkItems::Statuses::SystemDefined::Status.find(2) }
      let_it_be(:flow_trigger) do
        create(:ai_flow_trigger,
          project: project,
          user: service_account,
          event_types: [Ai::FlowTrigger::EVENT_TYPES[:work_item]]
        )
      end

      let(:event) do
        ::WorkItems::StatusChangedEvent.build(
          work_item: work_item,
          current_user: create(:user),
          status: status
        )
      end

      it 'returns true' do
        expect(subscription.condition.call(event)).to be true
      end
    end

    context 'when the project has no matching trigger' do
      let_it_be(:project) { create(:project) }
      let_it_be(:work_item) { create(:work_item, project: project) }
      let_it_be(:status) { ::WorkItems::Statuses::SystemDefined::Status.find(2) }

      let(:event) do
        ::WorkItems::StatusChangedEvent.build(
          work_item: work_item,
          current_user: create(:user),
          status: status
        )
      end

      it 'returns false' do
        expect(subscription.condition.call(event)).to be false
      end
    end
  end
end
