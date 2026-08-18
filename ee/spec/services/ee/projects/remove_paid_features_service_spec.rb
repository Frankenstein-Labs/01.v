# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Projects::RemovePaidFeaturesService, feature_category: :plan_provisioning do
  include EE::GeoHelpers

  subject(:execute_transfer) { service.execute(target_namespace) }

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:params) { { expires_at: nil } }
  let_it_be(:free_group) { create(:group) }
  let_it_be_with_refind(:project) do
    create(:project, :public, :legacy_storage, namespace: user.namespace)
  end

  let(:premium_group) { create(:group_with_plan, plan: :premium_plan) }
  let(:service) { described_class.new(project) }

  describe '#execute' do
    before do
      stub_const("#{described_class.name}::BATCH_SIZE", 2)
      stub_feature_flags(allow_resource_access_token_creation_without_expiry_date: true)
      stub_application_setting(require_personal_access_token_expiry: false)
    end

    context 'with project access tokens' do
      before do
        3.times do
          ResourceAccessTokens::CreateService.new(user, project, params).execute
        end
      end

      def revoked_tokens
        PersonalAccessToken.without_impersonation.for_users(project.bots).revoked
      end

      context 'with a self managed instance' do
        let(:target_namespace) { group }

        before do
          stub_ee_application_setting(should_check_namespace_plan: false)
        end

        it 'does not revoke PATs' do
          expect { execute_transfer }.not_to change { revoked_tokens.count }
        end
      end

      context 'with GL.com', :saas do
        shared_examples 'revokes PATs' do
          it 'revokes PATs' do
            expect { execute_transfer }.to change { revoked_tokens.count }.from(0).to(3)
          end
        end

        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        context 'when target namespace has a premium plan' do
          let(:target_namespace) { premium_group }

          it 'does not revoke PATs' do
            expect { execute_transfer }.not_to change { revoked_tokens.count }
          end
        end

        context 'when target namespace has a free plan' do
          let(:target_namespace) { free_group }

          include_examples 'revokes PATs'
        end

        context 'when group becomes root namespace' do
          let(:target_namespace) { nil }

          include_examples 'revokes PATs'
        end
      end
    end

    context 'with pipeline subscriptions', :saas do
      shared_examples 'does not schedule cleanup for upstream project subscription' do
        it 'does not schedule cleanup for upstream project subscription' do
          expect(::Ci::UpstreamProjectsSubscriptionsCleanupWorker).not_to receive(:perform_async)

          execute_transfer
        end
      end

      before do
        create(:license, plan: License::PREMIUM_PLAN)
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'when target namespace has a premium plan' do
        let(:target_namespace) { premium_group }

        include_examples 'does not schedule cleanup for upstream project subscription'
      end

      context 'when target namespace has a free plan' do
        let(:target_namespace) { free_group }

        it 'schedules cleanup for upstream project subscription' do
          expect(::Ci::UpstreamProjectsSubscriptionsCleanupWorker).to receive(:perform_async)
            .with(project.id)
            .and_call_original

          execute_transfer
        end
      end

      context 'when group becomes root namespace' do
        let(:target_namespace) { nil }

        it 'schedules cleanup for upstream project subscription' do
          expect(::Ci::UpstreamProjectsSubscriptionsCleanupWorker).to receive(:perform_async)
            .with(project.id)
            .and_call_original

          execute_transfer
        end
      end
    end

    context 'with test cases', :saas do
      def issue_count
        project.issues.with_issue_type(:test_case).count
      end

      shared_examples 'deletes test cases' do
        it 'deletes the test cases' do
          expect { execute_transfer }.to change { issue_count }.from(3).to(0)
        end
      end

      before do
        create_list(:quality_test_case, 3, project: project, author: user)
        create(:license, plan: License::ULTIMATE_PLAN)
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'when target namespace has a ultimate plan' do
        let(:target_namespace) { create(:group_with_plan, plan: :ultimate_plan) }

        it 'does not delete the test cases', :aggregate_failures do
          expect(issue_count).to eq(3)

          expect { execute_transfer }.not_to change { issue_count }
        end
      end

      context 'when target namespace has a premium plan' do
        let(:target_namespace) { premium_group }

        include_examples 'deletes test cases'
      end

      context 'when target namespace has a free plan' do
        let(:target_namespace) { free_group }

        include_examples 'deletes test cases'
      end

      context 'when group becomes root namespace' do
        let(:target_namespace) { nil }

        include_examples 'deletes test cases'
      end
    end
  end
end
