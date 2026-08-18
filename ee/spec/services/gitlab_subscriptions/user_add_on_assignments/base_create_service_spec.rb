# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UserAddOnAssignments::BaseCreateService, feature_category: :seat_cost_management do
  let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: add_on) }
  let(:user) { create(:user) }

  describe '#execute' do
    context 'when the user is already assigned' do
      it 'returns success without creating a new assignment' do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:user_already_assigned?).and_return(true)
        end

        result = described_class.new(add_on_purchase: add_on_purchase, user: user).execute

        expect(result).to be_success
        expect(add_on_purchase.assigned_users.count).to be_zero
      end
    end

    context 'when there are no available seats' do
      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:seats_available?).and_return(false)
        end
      end

      it 'logs an error and returns a failure response' do
        expect(Gitlab::AppLogger).to receive(:info).with(hash_including(
          message: 'User AddOn assignment creation failed', error: 'NO_SEATS_AVAILABLE', username: user.username))

        result = described_class.new(add_on_purchase: add_on_purchase, user: user).execute

        expect(result).to be_error
        expect(result.message).to eq('NO_SEATS_AVAILABLE')
      end

      it 'does not create related notification todo' do
        expect { described_class.new(add_on_purchase: add_on_purchase, user: user).execute }.not_to change {
          user.todos.count
        }
      end
    end

    context 'when there are available seats' do
      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:eligible_for_gitlab_duo_pro_seat?).and_return(true)
        end
      end

      it 'creates a new assignment and returns success' do
        result = described_class.new(add_on_purchase: add_on_purchase, user: user).execute

        expect(result).to be_success
        expect(add_on_purchase.assigned_users.count).to eq(1)
      end

      it 'creates related notification todo' do
        expect { described_class.new(add_on_purchase: add_on_purchase, user: user).execute }.to change {
          user.todos.count
        }.by(1)

        expect(user.todos.last.action).to eq(::Todo::DUO_PRO_ACCESS_GRANTED)
      end
    end

    context 'when there are available duo enterprise seats' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: add_on) }

      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:eligible_for_gitlab_duo_pro_seat?).and_return(true)
        end
      end

      it 'creates related notification todo' do
        expect { described_class.new(add_on_purchase: add_on_purchase, user: user).execute }.to change {
          user.todos.count
        }.by(1)

        expect(user.todos.last.action).to eq(::Todo::DUO_ENTERPRISE_ACCESS_GRANTED)
      end
    end

    context 'when Add-on purchase does not belong to seat assignable Add-on' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_amazon_q) }
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: add_on) }

      it 'logs an error and returns a failure response' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'User AddOn assignment creation failed',
            error: 'SEAT_ASSIGNMENT_NOT_SUPPORTED', username: user.username
          )
        )

        result = described_class.new(add_on_purchase: add_on_purchase, user: user).execute

        expect(result).to be_error
        expect(result.message).to eq('SEAT_ASSIGNMENT_NOT_SUPPORTED')
      end
    end

    context 'when user membership is invalid' do
      it 'logs an error and returns a failure response' do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:eligible_for_gitlab_duo_pro_seat?).and_return(false)
        end

        expect(Gitlab::AppLogger).to receive(:info).with(hash_including(
          message: 'User AddOn assignment creation failed', error: 'INVALID_USER_MEMBERSHIP', username: user.username))

        result = described_class.new(add_on_purchase: add_on_purchase, user: user).execute

        expect(result).to be_error
        expect(result.message).to eq('INVALID_USER_MEMBERSHIP')
      end
    end
  end

  describe '#eligible_for_gitlab_duo_pro_seat?' do
    it 'raises NotImplementedError' do
      service = described_class.new(add_on_purchase: add_on_purchase, user: user)

      expect { service.send(:eligible_for_gitlab_duo_pro_seat?) }.to raise_error(NotImplementedError)
    end
  end
end
