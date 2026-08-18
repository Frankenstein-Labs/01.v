# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Groups::AdjournedDeletionService, feature_category: :groups_and_projects do
  let_it_be(:delay) { 1.hour }
  let_it_be(:params) { { delay: delay } }
  let_it_be_with_reload(:group) { create(:group) }
  let(:resource) { group }
  let(:destroy_worker) { GroupDestroyWorker }
  let(:destroy_worker_params) { [delay, resource.id, user.id] }
  let(:perform_method) { :perform_in }

  subject(:service) { described_class.new(group: group, current_user: user, params: params) }

  include_examples 'adjourned deletion service'

  context 'when group is linked to a subscription', :saas_gitlab_com_subscriptions, :with_sidekiq_context do
    let_it_be(:user) { create(:user) }

    let_it_be_with_reload(:group) do
      create(:group_with_plan, plan: :ultimate_plan, state: :deletion_scheduled,
        deletion_scheduled_at: 15.days.ago, state_metadata: { deletion_scheduled_by_user_id: user.id })
    end

    before_all do
      group.add_owner(user)
    end

    it 'does not enqueue the group destroy worker' do
      expect(destroy_worker).not_to receive(perform_method)

      service.execute
    end

    it 'restores the group', :enable_admin_mode, :sidekiq_inline, :aggregate_failures do
      service.execute

      group.reload
      expect(Group.exists?(group.id)).to be(true)
      expect(group.self_deletion_scheduled?).to be(false)
      expect(group.namespace_details.deletion_scheduled_by_user_id).to be_nil
    end

    context 'when subscription is a trial' do
      let_it_be_with_reload(:group) do
        create(:group_with_plan, plan: :ultimate_trial_plan, trial: true, trial_starts_on: Date.current,
          trial_ends_on: 30.days.from_now, state: :deletion_scheduled, deletion_scheduled_at: 15.days.ago,
          state_metadata: { deletion_scheduled_by_user_id: user.id })
      end

      before_all do
        group.add_owner(user)
      end

      it 'enqueues the group destroy worker' do
        expect(destroy_worker).to receive(perform_method).with(delay, group.id, user.id)

        service.execute
      end
    end
  end
end
