# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::BulkUnassignService, feature_category: :seat_cost_management do
  let_it_be(:users) { create_list(:user, 5) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, quantity: 10, add_on: add_on)
  end

  shared_examples 'assignments error' do |error_type|
    let(:expected_logs) do
      {
        add_on_purchase_id: add_on_purchase.id,
        message: 'Duo Bulk User Unassignment',
        response_type: 'error',
        payload: { errors: error_type }
      }
    end

    it 'returns an error' do
      expect(Gitlab::AppLogger).to receive(:error).with(expected_logs)

      expect { response }.not_to change { add_on_purchase.assigned_users.count }

      expect(response.error?).to be_truthy
      expect(response.errors).to eq([error_type])
    end

    it 'executes a limited number of queries', :use_clean_rails_redis_caching do
      control = ActiveRecord::QueryRecorder.new { response }

      expect(control.count).to be <= 1
    end
  end

  shared_examples 'successful user unassignment' do
    let(:expected_logs) do
      {
        add_on_purchase_id: add_on_purchase.id,
        message: 'Duo Bulk User Unassignment',
        response_type: 'success',
        payload: { users: expected_users.map(&:id) }
      }
    end

    before do
      users.each do |user|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
      end
    end

    it 'unassigns users successfully' do
      expect(Gitlab::AppLogger).to receive(:info).with(expected_logs)

      expect { response }.to change { add_on_purchase.assigned_users.count }.by(-users.count)

      expect(response.success?).to be_truthy
      expect(response[:users]).to match_array(expected_users)
    end

    it 'executes a limited number of queries', :use_clean_rails_redis_caching do
      control = ActiveRecord::QueryRecorder.new { response }
      expect(control.count).to be <= 2
    end
  end

  describe '#execute' do
    subject(:response) do
      described_class.new(add_on_purchase: add_on_purchase, user_ids: user_ids).execute
    end

    context 'when user IDs are invalid' do
      let(:user_ids) { [-non_existing_record_id, non_existing_record_id] }

      include_examples 'assignments error', 'NO_ASSIGNMENTS_FOUND'
    end

    context 'when users are not already assigned' do
      let(:user_ids) { users.map(&:id) }

      include_examples 'assignments error', 'NO_ASSIGNMENTS_FOUND'
    end

    context 'when users are already assigned' do
      let(:user_ids) { users.map(&:id) }
      let(:expected_users) { users }

      include_examples 'successful user unassignment'
    end
  end
end
