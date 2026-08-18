# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::ReconcileSeatOverageService, feature_category: :seat_cost_management do
  let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, created_at: 1.week.ago) }

  subject(:service_response) { described_class.new(add_on_purchase: add_on_purchase).execute }

  describe '#execute' do
    context 'when there is no overage' do
      it 'does not remove any seat' do
        expect(service_response).to be_success
        expect(service_response.payload).to eq({ removed_seats_count: 0 })
      end
    end

    context 'when there is overage' do
      let(:user_1) { create(:user) }
      let(:user_2) { create(:user) }

      let(:expected_log_destruction) do
        {
          message: 'ReconcileSeatOverageService destroyed UserAddOnAssignments',
          user_ids: [user_2.id],
          add_on: 'code_suggestions',
          add_on_purchase: add_on_purchase.id,
          namespace: add_on_purchase.namespace.path
        }
      end

      let(:expected_log_summary) do
        {
          message: 'ReconcileSeatOverageService removed AddOnPurchase seat overage',
          add_on: 'code_suggestions',
          add_on_purchase: add_on_purchase.id,
          deleted_overage_count: 1
        }
      end

      before do
        add_on_purchase.assigned_users.create!(user: user_1)
        add_on_purchase.assigned_users.create!(user: user_2)
      end

      it 'removes overage seat by recently assigned user first' do
        expect(service_response).to be_success
        expect(service_response.payload).to eq({ removed_seats_count: 1 })
        expect(add_on_purchase.reload.assigned_users.map(&:user)).to match_array([user_1])
      end

      it 'expires cache keys for the deleted users', :use_clean_rails_redis_caching do
        user_1_cache_key = user_1.duo_pro_cache_key_formatted
        user_2_cache_key = user_2.duo_pro_cache_key_formatted

        Rails.cache.write(user_1_cache_key, true, expires_in: 1.hour)
        Rails.cache.write(user_2_cache_key, true, expires_in: 1.hour)

        expect { expect(service_response).to be_success }
          .to change { add_on_purchase.reload.assigned_users.count }.by(-1)
          .and change { Rails.cache.read(user_2_cache_key) }.from(true).to(nil)
          .and not_change { Rails.cache.read(user_1_cache_key) }
      end

      it 'logs destruction in batches and summary' do
        expect(Gitlab::AppLogger).to receive(:info).with(expected_log_destruction).ordered
        expect(Gitlab::AppLogger).to receive(:info).with(expected_log_summary).ordered

        service_response
      end

      context 'when clickhouse is enabled', :click_house, :freeze_time do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
        end

        context 'when there are no records related to user' do
          before do
            clickhouse_fixture(:ai_usage_events, [
              { user_id: create(:user).id, event: 1, timestamp: 2.days.ago }
            ])
          end

          it 'removes overage seat by recently assigned user first' do
            expect(service_response).to be_success
            expect(service_response.payload).to eq({ removed_seats_count: 1 })

            expect(add_on_purchase.reload.assigned_users.map(&:user)).to match_array([user_1])
          end
        end

        context 'when there are records related to user' do
          before do
            clickhouse_fixture(:ai_usage_events, [
              { user_id: user_2.id, event: 1, timestamp: 2.days.ago }
            ])
          end

          it 'removes overage seat by user who did not use code suggestion at all' do
            expect(service_response).to be_success
            expect(service_response.payload).to eq({ removed_seats_count: 1 })

            expect(add_on_purchase.reload.assigned_users.map(&:user)).to match_array([user_2])
          end

          context 'when all users have used code suggestions' do
            let(:user_3) { create(:user) }

            before do
              add_on_purchase.assigned_users.create!(user: user_3)

              clickhouse_fixture(:ai_usage_events, [
                { user_id: user_1.id, event: 1, timestamp: 4.days.ago },
                { user_id: user_2.id, event: 1, timestamp: 3.days.ago },
                { user_id: user_1.id, event: 1, timestamp: 2.days.ago },
                { user_id: user_3.id, event: 1, timestamp: 1.day.ago }
              ])
            end

            it 'removes overage seat by user with oldest code suggestions usage' do
              expect(service_response).to be_success
              expect(service_response.payload).to eq({ removed_seats_count: 2 })

              expect(add_on_purchase.reload.assigned_users.map(&:user)).to eq([user_3])
            end
          end
        end
      end
    end
  end
end
