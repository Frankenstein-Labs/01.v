# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningNotificationService,
  :clean_gitlab_redis_shared_state, :freeze_time, feature_category: :seat_cost_management do
  include GitlabSubscriptions::MemberManagement::SeatAwareProvisioning

  let_it_be(:owner) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:group) { create(:group, owners: owner) }
  let_it_be(:minimal_access_user) { create(:user) }

  let(:yesterday) { Date.yesterday.iso8601 }
  let(:previous_notification_date) { (Date.yesterday - 1.day).iso8601 }
  let(:instance_cache_key) { format_instance_cache_key(yesterday) }

  describe '.execute' do
    subject(:execute) { described_class.execute }

    context 'when already executed today' do
      let(:earlier_run) { described_class.execute }

      before do
        Gitlab::Redis::SharedState.with do |redis|
          redis.sadd(instance_cache_key, minimal_access_user.id.to_s)
        end
      end

      it 'does not enqueue notifications again' do
        earlier_run

        expect { execute }.not_to have_enqueued_mail(
          GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningMailer, :notify_instance_admin
        )
      end
    end

    context 'when on self-managed' do
      before do
        Gitlab::Redis::SharedState.with do |redis|
          redis.sadd(instance_cache_key, minimal_access_user.id.to_s)
        end
      end

      it 'sends a notification email to admins' do
        expect { execute }.to have_enqueued_mail(
          GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningMailer, :notify_instance_admin
        ).with(recipient: admin, user_count: 1, sync_date: yesterday)
      end

      context 'when there are no affected users in the cache' do
        before do
          Gitlab::Redis::SharedState.with do |redis|
            redis.del(instance_cache_key)
          end
        end

        it 'does not send a notification' do
          expect { execute }.not_to have_enqueued_mail(
            GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningMailer, :notify_instance_admin
          )
        end
      end

      context 'when the same users were affected since the previous day' do
        let(:instance_cache_key_previous_date) { format_instance_cache_key(previous_notification_date) }

        before do
          Gitlab::Redis::SharedState.with do |redis|
            redis.sadd(instance_cache_key_previous_date, minimal_access_user.id.to_s)
          end
        end

        it 'does not send a notification' do
          expect { execute }.not_to have_enqueued_mail(
            GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningMailer, :notify_instance_admin
          )
        end
      end
    end

    context 'when on saas', :saas do
      let(:root_groups_cache_key) { format_root_groups_cache_key(yesterday) }
      let(:users_cache_key) { format_users_cache_key(group.id, yesterday) }

      before do
        Gitlab::Redis::SharedState.with do |redis|
          redis.sadd(root_groups_cache_key, group.id.to_s)
          redis.sadd(users_cache_key, minimal_access_user.id.to_s)
        end
      end

      context 'with multiple qualifying groups' do
        let(:other_group_owner) { create(:user) }
        let(:other_group) { create(:group, owners: other_group_owner) }
        let(:other_minimal_access_user) { create(:user) }

        before do
          allow(IdempotencyCache).to receive(:ensure_idempotency).and_yield
        end

        it 'does not introduce N+1 queries' do
          control = ActiveRecord::QueryRecorder.new { described_class.execute }

          Gitlab::Redis::SharedState.with do |redis|
            redis.sadd(root_groups_cache_key, other_group.id.to_s)
            redis.sadd(format_users_cache_key(other_group.id, yesterday), other_minimal_access_user.id.to_s)
          end

          expect { execute }.not_to exceed_query_limit(control)
        end
      end

      it 'sends a notification email to group owners' do
        expect { execute }.to have_enqueued_mail(
          GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningMailer, :notify_group_owner
        ).with(namespace: group, recipient: owner, user_count: 1, sync_date: yesterday)
      end

      context 'when there are no affected groups in the cache' do
        before do
          Gitlab::Redis::SharedState.with do |redis|
            redis.del(root_groups_cache_key)
          end
        end

        it 'does not send a notification' do
          expect { execute }.not_to have_enqueued_mail(
            GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningMailer, :notify_group_owner
          )
        end
      end

      context 'when there are no affected users in the cache' do
        before do
          Gitlab::Redis::SharedState.with do |redis|
            redis.del(users_cache_key)
          end
        end

        it 'does not send a notification' do
          expect { execute }.not_to have_enqueued_mail(
            GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningMailer, :notify_group_owner
          )
        end
      end

      context 'when the same users were affected since the previous day' do
        let(:root_groups_cache_key_previous_date) { format_root_groups_cache_key(previous_notification_date) }
        let(:users_cache_key_previous_date) { format_users_cache_key(group.id, previous_notification_date) }

        before do
          Gitlab::Redis::SharedState.with do |redis|
            redis.sadd(root_groups_cache_key_previous_date, group.id.to_s)
            redis.sadd(users_cache_key_previous_date, minimal_access_user.id.to_s)
          end
        end

        it 'does not send a notification' do
          expect { execute }.not_to have_enqueued_mail(
            GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningMailer, :notify_group_owner
          )
        end
      end
    end
  end
end
