# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ScheduleDormantMemberRemovalWorker, feature_category: :seat_cost_management do
  subject(:worker) { described_class.new }

  describe '#perform' do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it_behaves_like 'an idempotent worker' do
      it 'schedules Namespaces::RemoveDormantMembersworker to be performed with capacity' do
        expect(Namespaces::RemoveDormantMembersWorker).to receive(:perform_with_capacity).twice

        perform_idempotent_work
      end
    end

    context 'when not on GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not schedule a worker to perform with capacity' do
        expect(Namespaces::RemoveDormantMembersWorker).not_to receive(:perform_with_capacity)

        worker.perform
      end
    end
  end
end
