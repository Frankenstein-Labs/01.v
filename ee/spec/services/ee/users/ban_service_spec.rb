# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::BanService, feature_category: :user_management do
  let_it_be(:current_user) { create(:admin) }

  subject(:service) { described_class.new(current_user) }

  describe '#execute', :enable_admin_mode do
    let_it_be_with_reload(:user) { create(:user) }

    subject(:operation) { service.execute(user) }

    context 'for audit events' do
      include_examples 'audit event logging' do
        let(:operation) { service.execute(user) }

        let(:fail_condition!) do
          allow(user).to receive(:ban).and_return(false)
        end

        let(:attributes) do
          {
            author_id: current_user.id,
            entity_id: user.id,
            entity_type: 'User',
            details: {
              author_class: 'User',
              author_name: current_user.name,
              event_name: "ban_user",
              custom_message: 'Banned user',
              target_details: user.username,
              target_id: user.id,
              target_type: 'User'
            }
          }
        end
      end
    end

    context 'for paid users', :saas do
      shared_examples 'not banning paid users' do
        specify :aggregate_failures do
          response = service.execute(user)

          expect(response[:status]).to eq(:error)
          expect(response[:message]).to match('You cannot ban paid users.')
          expect(user).not_to be_banned
        end
      end

      context 'when the user is part of a paid namespace' do
        before do
          create(:group_with_plan, plan: :ultimate_plan, owners: user)
        end

        it_behaves_like 'not banning paid users'
      end

      context 'when the user is an enterprise user' do
        let_it_be(:user) { create(:enterprise_user) }

        it_behaves_like 'not banning paid users'
      end

      context 'when the user is a member of a trial namespace' do
        before do
          create(
            :group_with_plan,
            plan: :ultimate_trial_plan,
            trial: true,
            trial_starts_on: Date.current,
            trial_ends_on: 30.days.from_now,
            owners: user
          )
        end

        it 'bans the user', :aggregate_failures do
          response = service.execute(user)

          expect(response[:status]).to eq(:success)
          expect(user).to be_banned
        end
      end
    end
  end
end
