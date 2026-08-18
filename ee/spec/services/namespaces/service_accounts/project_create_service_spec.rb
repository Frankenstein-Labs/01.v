# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::ProjectCreateService, feature_category: :user_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:project_id) { project.id }

  subject(:service) do
    described_class.new(current_user, { organization_id: organization.id, project_id: project_id })
  end

  context 'when self-managed' do
    let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

    before do
      allow(License).to receive(:current).and_return(license)
    end

    context 'when current user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      it_behaves_like 'service account creation success' do
        let(:username_prefix) { "service_account_project_#{project.id}" }
      end
    end

    # Use project maintainer (least-privileged role with :create_service_account) as the primary
    # positive test to exercise the real authorization path - admin bypasses policy checks entirely.
    context 'when current user is a project maintainer' do
      let_it_be(:current_user) { create(:user, maintainer_of: project) }

      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      end

      it_behaves_like 'service account creation success' do
        let(:username_prefix) { "service_account_project_#{project.id}" }
      end
    end

    context 'when current user is a group owner' do
      let_it_be(:current_user) { create(:user, owner_of: group) }

      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      end

      it_behaves_like 'service account creation success' do
        let(:username_prefix) { "service_account_project_#{project.id}" }
      end
    end
  end

  context 'when SaaS', :saas do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    context 'when current user is a group owner' do
      let_it_be(:group_with_ultimate) { create(:group) }
      let_it_be(:project_in_ultimate) { create(:project, group: group_with_ultimate) }
      let_it_be(:current_user) { create(:user, owner_of: group_with_ultimate) }
      let(:project_id) { project_in_ultimate.id }

      before do
        create(:gitlab_subscription, :ultimate, namespace: group_with_ultimate, seats: 10)
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      end

      it_behaves_like 'service account creation success' do
        let(:username_prefix) { "service_account_project_#{project_in_ultimate.id}" }
      end

      it 'sets provisioned by project' do
        expect(result.payload[:user].provisioned_by_project_id).to eq(project_in_ultimate.id)
      end

      context 'when the project is invalid' do
        let(:project_id) { non_existing_record_id }

        it 'produces an error', :aggregate_failures do
          expect(result.status).to eq(:error)
          expect(result.message).to include('does not have permission')
        end
      end

      context 'when project_id does not exist' do
        let(:project_id) { non_existing_record_id }

        it 'returns nil for root_namespace' do
          expect(service.send(:resource)).to be_nil
          expect(service.send(:root_namespace)).to be_nil
        end
      end
    end

    context 'when subscription is on trial' do
      let_it_be(:group_with_trial) { create(:group) }
      let_it_be(:project_in_trial) { create(:project, group: group_with_trial) }
      let_it_be(:current_user) { create(:user, owner_of: group_with_trial) }
      let(:project_id) { project_in_trial.id }

      before do
        create(:gitlab_subscription, :active_trial, namespace: group_with_trial, hosted_plan: create(:ultimate_plan))
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      end

      it_behaves_like 'service account creation success' do
        let(:username_prefix) { "service_account_project_#{project_in_trial.id}" }
      end
    end
  end

  def result
    service.execute
  end
end
