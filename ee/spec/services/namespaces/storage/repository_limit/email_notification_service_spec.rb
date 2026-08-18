# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Storage::RepositoryLimit::EmailNotificationService,
  feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers
  using RSpec::Parameterized::TableSyntax

  describe 'execute' do
    let(:mailer) { ::Namespaces::Storage::RepositoryLimitMailer }
    let(:action_mailer) { instance_double(ActionMailer::MessageDelivery) }
    let(:owner) { build_stubbed(:user) }
    let(:group) do
      build_stubbed(
        :group,
        owner: owner,
        gitlab_subscription: build_stubbed(:gitlab_subscription, plan_code: Plan::ULTIMATE)
      )
    end

    let(:project_statistics) { build_stubbed(:project_statistics) }
    let(:project) { build_stubbed(:project, creator: owner, statistics: project_statistics, group: group) }

    shared_examples 'sends an out-of-storage notification' do
      before do
        allow(group).to receive_messages(
          owners_emails: [owner.email],
          actual_size_limit: actual_size_limit.megabytes,
          additional_purchased_storage_size: additional_purchased_storage_size,
          total_repository_size_excess: [repository_size - actual_size_limit, 0].max.megabytes
        )
        allow(project_statistics).to receive(:repository_size).and_return(repository_size.megabytes)
      end

      it 'sends an out-of-storage notification' do
        expect(mailer).to receive(:notify_out_of_storage)
        .with(
          project_name: project.name,
          recipients: [owner.email]
        )
        .and_return(action_mailer)
        expect(action_mailer).to receive(:deliver_later)

        described_class.execute(project)
      end
    end

    shared_examples 'does not send any notification' do
      before do
        allow(group).to receive_messages(
          owners_emails: [owner.email],
          actual_size_limit: actual_size_limit.megabytes,
          additional_purchased_storage_size: additional_purchased_storage_size,
          total_repository_size_excess: [repository_size - actual_size_limit, 0].max.megabytes
        )
        allow(project_statistics).to receive(:repository_size).and_return(repository_size.megabytes)
      end

      it 'does not send any notification' do
        expect(mailer).not_to receive(:notify_out_of_storage)
        expect(mailer).not_to receive(:notify_limit_warning)

        described_class.execute(project)
      end
    end

    context 'when in GitLab.com', :saas do
      before do
        allow_next_instance_of(PlanLimits) do |plan_limit|
          allow(plan_limit).to receive(:repository_size).and_return 1
        end
      end

      context 'when there is no available storage' do
        where(:actual_size_limit, :additional_purchased_storage_size, :repository_size) do
          100 | 0 | 101
          100 | 100 | 201
        end

        with_them do
          it_behaves_like 'sends an out-of-storage notification'
        end

        context 'and namespace is not subject to high limit' do
          let(:actual_size_limit) { 100 }
          let(:additional_purchased_storage_size) { 0 }
          let(:repository_size) { 200 }
          let(:group) do
            build_stubbed(
              :group,
              owner: owner,
              gitlab_subscription: build_stubbed(:gitlab_subscription, plan_code: Plan::FREE)
            )
          end

          it_behaves_like 'does not send any notification'
        end
      end

      context 'when available storage is ending' do
        where(:actual_size_limit, :additional_purchased_storage_size, :repository_size) do
          100 | 0 | 90
          100 | 0 | 99
          100 | 100 | 190
        end

        with_them do
          before do
            allow(group).to receive_messages(
              owners_emails: [owner.email],
              actual_size_limit: actual_size_limit.megabytes,
              additional_purchased_storage_size: additional_purchased_storage_size,
              total_repository_size_excess: [repository_size - actual_size_limit, 0].max.megabytes
            )
            allow(project_statistics).to receive(:repository_size).and_return(repository_size.megabytes)
          end

          it 'sends an approaching storage limit notification' do
            expect(mailer).to receive(:notify_limit_warning)
            .with(
              project_name: project.name,
              recipients: [owner.email]
            )
            .and_return(action_mailer)
            expect(action_mailer).to receive(:deliver_later)

            described_class.execute(project)
          end
        end
      end

      context 'when there is available storage' do
        where(:actual_size_limit, :additional_purchased_storage_size, :repository_size) do
          0   | 0 | 50
          100 | 0 | 50
          100 | 100 | 50
        end

        with_them do
          it_behaves_like 'does not send any notification'
        end
      end
    end

    context 'when in Self-Managed' do
      let(:actual_size_limit) { 100 }
      let(:additional_purchased_storage_size) { 0 }
      let(:repository_size) { 200 }

      it_behaves_like 'does not send any notification'
    end
  end
end
