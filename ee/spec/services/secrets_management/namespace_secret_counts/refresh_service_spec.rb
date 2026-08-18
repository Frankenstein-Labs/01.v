# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::NamespaceSecretCounts::RefreshService, feature_category: :secrets_management do
  let_it_be_with_reload(:root_group) { create(:group) }
  let_it_be_with_reload(:nested_group) { create(:group, parent: root_group) }

  describe '.execute_for_namespace_id' do
    context 'when the namespace does not exist' do
      it 'returns success with skipped: :missing_namespace' do
        result = described_class.execute_for_namespace_id(non_existing_record_id)

        expect(result).to be_success
        expect(result.payload[:skipped]).to eq(:missing_namespace)
      end
    end

    context 'when the namespace exists' do
      let_it_be(:owner) { create(:user) }

      before_all do
        nested_group.add_owner(owner)
      end

      it 'falls back to the namespace first owner when no current_user_id is given' do
        expect_next_instance_of(described_class, kind_of(Namespace), current_user: owner) do |instance|
          expect(instance).to receive(:execute)
        end

        described_class.execute_for_namespace_id(nested_group.id)
      end

      it 'looks up the current_user when current_user_id is provided' do
        actor = create(:user)

        expect_next_instance_of(described_class, kind_of(Namespace), current_user: actor) do |instance|
          expect(instance).to receive(:execute)
        end

        described_class.execute_for_namespace_id(nested_group.id, current_user_id: actor.id)
      end

      it 'falls back to the first owner when the current_user_id no longer resolves' do
        # Models a worker whose triggering user was deleted between enqueue and execute.
        expect_next_instance_of(described_class, kind_of(Namespace), current_user: owner) do |instance|
          expect(instance).to receive(:execute)
        end

        described_class.execute_for_namespace_id(nested_group.id, current_user_id: non_existing_record_id)
      end

      context 'with a project namespace' do
        let_it_be(:project) { create(:project) }
        let_it_be(:project_owner) { project.first_owner }

        it 'attributes the refresh to the project first owner' do
          expect_next_instance_of(described_class, kind_of(Namespace), current_user: project_owner) do |instance|
            expect(instance).to receive(:execute)
          end

          described_class.execute_for_namespace_id(project.project_namespace_id)
        end
      end
    end
  end

  describe '#execute' do
    subject(:execute) { described_class.new(namespace, current_user: current_user).execute }

    let(:current_user) { nil }

    context 'with a Group namespace' do
      let(:namespace) { nested_group }

      context 'when the group has no secrets manager' do
        let_it_be(:existing_row) do
          create(:namespace_secret_count, namespace: nested_group, root_namespace: root_group, count: 5)
        end

        it 'removes any existing count row' do
          expect { execute }.to change { SecretsManagement::NamespaceSecretCount.count }.by(-1)
        end

        it 'returns success with removed: true' do
          result = execute

          expect(result).to be_success
          expect(result.payload[:removed]).to be true
        end
      end

      context 'when the group secrets manager is not active' do
        let_it_be_with_reload(:secrets_manager) do
          create(:group_secrets_manager, :provisioning, group: nested_group)
        end

        it 'removes any existing count row and does not call OpenBao' do
          expect(SecretsManagement::GroupSecretsCountService).not_to receive(:new)

          execute
        end
      end

      context 'when the group has an active secrets manager' do
        let_it_be_with_reload(:secrets_manager) do
          create(:group_secrets_manager, :active, group: nested_group)
        end

        let(:count_service) { instance_double(SecretsManagement::GroupSecretsCountService) }

        before do
          allow(SecretsManagement::GroupSecretsCountService)
            .to receive(:new).with(nested_group, current_user).and_return(count_service)
        end

        it 'upserts a row with the OpenBao count and the root namespace' do
          allow(count_service).to receive(:execute).and_return(7)

          expect { execute }.to change { SecretsManagement::NamespaceSecretCount.count }.by(1)

          row = SecretsManagement::NamespaceSecretCount.find(nested_group.id)
          expect(row.root_namespace_id).to eq(root_group.id)
          expect(row.count).to eq(7)
        end

        it 'updates an existing row idempotently' do
          create(:namespace_secret_count, namespace: nested_group, root_namespace: root_group, count: 1)
          allow(count_service).to receive(:execute).and_return(9)

          expect { execute }.not_to change { SecretsManagement::NamespaceSecretCount.count }
          expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(9)
        end

        it 'returns success with the count' do
          allow(count_service).to receive(:execute).and_return(2)

          result = execute

          expect(result).to be_success
          expect(result.payload[:count]).to eq(2)
        end

        context 'when a current_user is provided' do
          let_it_be(:actor) { create(:user) }
          let(:current_user) { actor }

          it 'forwards the user to the count service so OpenBao receives user-context claims' do
            allow(count_service).to receive(:execute).and_return(11)

            execute

            expect(SecretsManagement::GroupSecretsCountService)
              .to have_received(:new).with(nested_group, actor)
            expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(11)
          end
        end

        context 'when OpenBao raises an ApiError' do
          before do
            allow(count_service).to receive(:execute)
              .and_raise(SecretsManagement::SecretsManagerClient::ApiError, 'boom')
          end

          it 'lets the exception propagate so Sidekiq can retry' do
            expect { execute }
              .to raise_error(SecretsManagement::SecretsManagerClient::ApiError, 'boom')
          end

          it 'does not write a row' do
            expect do
              execute
            rescue SecretsManagement::SecretsManagerClient::ApiError
              # expected
            end.not_to change { SecretsManagement::NamespaceSecretCount.count }
          end
        end

        context 'when OpenBao raises a ConnectionError' do
          before do
            allow(count_service).to receive(:execute)
              .and_raise(SecretsManagement::SecretsManagerClient::ConnectionError, 'down')
          end

          it 'lets the exception propagate so Sidekiq can retry' do
            expect { execute }
              .to raise_error(SecretsManagement::SecretsManagerClient::ConnectionError, 'down')
          end
        end
      end
    end

    context 'with a ProjectNamespace namespace' do
      let_it_be_with_reload(:project) { create(:project) }
      let(:namespace) { project.project_namespace }

      context 'when the project has an active secrets manager' do
        let_it_be_with_reload(:secrets_manager) do
          create(:project_secrets_manager, :active, project: project)
        end

        let(:count_service) { instance_double(SecretsManagement::ProjectSecretsCountService) }

        before do
          allow(SecretsManagement::ProjectSecretsCountService)
            .to receive(:new).with(project, current_user).and_return(count_service)
          allow(count_service).to receive(:execute).and_return(3)
        end

        it 'upserts a row with the project namespace as the row key' do
          execute

          row = SecretsManagement::NamespaceSecretCount.find(project.project_namespace_id)
          expect(row.count).to eq(3)
          expect(row.root_namespace_id).to eq(project.project_namespace.root_ancestor.id)
        end
      end
    end

    # These specs cover the race-condition scenarios that motivated the
    # `deduplicate :until_executed` strategy on the worker:
    # - rapid fan-in of refresh triggers for the same namespace
    # - cron-driven refresh overlapping a user-driven refresh
    # - manager state transitions between successive refreshes
    # - namespace deletion between enqueue and execute
    #
    # The dedup middleware itself is exercised by Sidekiq tests upstream;
    # here we assert the convergence behaviour of the underlying service.
    describe 'race conditions and convergence' do
      let_it_be_with_reload(:secrets_manager) do
        create(:group_secrets_manager, :active, group: nested_group)
      end

      let(:count_service) { instance_double(SecretsManagement::GroupSecretsCountService) }

      before do
        allow(SecretsManagement::GroupSecretsCountService)
          .to receive(:new).with(nested_group, nil).and_return(count_service)
      end

      # Each Sidekiq job creates a fresh RefreshService in production; we do
      # the same in tests so successive calls actually re-run rather than
      # returning a memoized RSpec subject.
      def run_refresh
        described_class.new(nested_group).execute
      end

      context 'when triggers fan in rapidly with changing OpenBao counts' do
        it 'converges to the count returned by the last successful refresh' do
          allow(count_service).to receive(:execute).and_return(1, 5, 4, 7)

          4.times { run_refresh }

          expect(SecretsManagement::NamespaceSecretCount.count).to eq(1)
          expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(7)
        end
      end

      # Models the worker's `deduplicate :until_executed` contract:
      # a trigger that arrives while a refresh is mid-flight is dropped by
      # the dedup middleware. The currently-running job persists whatever
      # count it read at the time of the OpenBao call, which may be stale
      # relative to the trigger's effect. Any subsequent refresh (from the
      # next trigger or the daily cron) reads the latest OpenBao state and
      # overwrites the row, so the row is eventually correct.
      context 'when a secret create/delete arrives while a refresh is running' do
        it 'persists the count read at the time of the OpenBao call' do
          # Simulate: the refresh's read happens before the trigger lands
          # in OpenBao, so the running job still sees the pre-trigger count.
          allow(count_service).to receive(:execute).and_return(2)

          run_refresh

          expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(2)
        end

        it 'corrects a temporarily stale row once a follow-up refresh runs' do
          # First refresh reads pre-trigger state (=2) and writes it; a new
          # secret then lands in OpenBao (state becomes 3); the follow-up
          # refresh (from the next trigger or cron) reads 3 and overwrites.
          allow(count_service).to receive(:execute).and_return(2, 3)

          run_refresh
          expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(2)

          run_refresh
          expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(3)
        end
      end

      # Models a trigger that fires *just before* the refresh starts (i.e.,
      # while the job is still scheduled). The dedup key prevents a second
      # enqueue, but the (single) running job reads the post-trigger state,
      # so the row is correct without needing a follow-up.
      context 'when a secret create/delete arrives just before the refresh starts' do
        it 'writes the post-trigger count on the very first refresh' do
          allow(count_service).to receive(:execute).and_return(4)

          run_refresh

          expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(4)
        end
      end

      context 'when the manager is deactivated between successive refreshes' do
        it 'first writes the count, then removes it on the next refresh' do
          allow(count_service).to receive(:execute).and_return(3)
          run_refresh

          expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(3)

          secrets_manager.initiate_deprovision
          nested_group.reload

          expect { run_refresh }.to change { SecretsManagement::NamespaceSecretCount.count }.by(-1)
        end
      end

      context 'when the namespace is deleted between enqueue and execute' do
        it 'returns success without touching OpenBao or the table' do
          deleted_id = nested_group.id
          nested_group.destroy!

          expect(SecretsManagement::GroupSecretsCountService).not_to receive(:new)

          result = described_class.execute_for_namespace_id(deleted_id)

          expect(result).to be_success
          expect(result.payload[:skipped]).to eq(:missing_namespace)
        end
      end

      context 'when an OpenBao failure interleaves with a successful refresh' do
        it 'leaves the row at the last successful count and propagates the failure for retry' do
          allow(count_service).to receive(:execute).and_return(2)
          run_refresh
          expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(2)

          allow(count_service).to receive(:execute)
            .and_raise(SecretsManagement::SecretsManagerClient::ConnectionError, 'down')

          expect { run_refresh }
            .to raise_error(SecretsManagement::SecretsManagerClient::ConnectionError)

          expect(SecretsManagement::NamespaceSecretCount.find(nested_group.id).count).to eq(2)
        end
      end
    end
  end
end
