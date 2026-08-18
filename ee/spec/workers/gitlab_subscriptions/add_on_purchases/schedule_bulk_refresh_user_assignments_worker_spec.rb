# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::ScheduleBulkRefreshUserAssignmentsWorker, feature_category: :seat_cost_management do
  describe '#perform' do
    let(:worker_class) { GitlabSubscriptions::AddOnPurchases::BulkRefreshUserAssignmentsWorker }

    describe 'idempotence' do
      include_examples 'an idempotent worker' do
        it 'schedules ScheduleBulkRefreshUserAssignmentsWorker' do
          expect(worker_class).to receive(:perform_with_capacity).twice

          subject
        end
      end
    end

    context 'when on SaaS (GitLab.com)', :saas do
      it 'schedules the worker to perform with capacity' do
        expect(worker_class).to receive(:perform_with_capacity).once

        subject.perform
      end
    end
  end
end
