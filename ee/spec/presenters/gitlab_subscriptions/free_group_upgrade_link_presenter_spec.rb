# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::FreeGroupUpgradeLinkPresenter, feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }
  let(:group) { nil }

  describe '#attributes' do
    subject(:attributes) { described_class.new(user, group: group).attributes }

    context 'when gitlab_com_subscriptions feature is not available' do
      let(:license) { build_stubbed(:license) }

      before do
        allow(::License).to receive(:current).and_return(license)
        allow(user).to receive(:can_admin_all_resources?).and_return(true)
      end

      context 'when user is admin with no active license' do
        let(:license) { nil }

        it 'returns upgrade link to pricing page' do
          expected_path = ::Gitlab::Routing.url_helpers.promo_pricing_url(query: {
            deployment: 'self-managed-deployment'
          })
          expect(attributes).to eq({ free_group_upgrade_link: expected_path })
        end
      end

      context 'when user is admin with paid license' do
        let(:license) { build_stubbed(:license, :ultimate) }

        it { is_expected.to eq({}) }
      end

      context 'when user is admin with trial license' do
        let(:license) { build_stubbed(:license, :trial) }

        it { is_expected.to eq({}) }
      end

      context 'when user is admin with expired trial license' do
        let(:license) { build_stubbed(:license, :trial, expired: true) }

        it 'returns upgrade link to pricing page' do
          expected_path = ::Gitlab::Routing.url_helpers.promo_pricing_url(query: {
            deployment: 'self-managed-deployment'
          })
          expect(attributes).to eq({ free_group_upgrade_link: expected_path })
        end
      end

      context 'when user is admin with expired paid license' do
        let(:license) { build_stubbed(:license, :ultimate, expired: true) }

        it 'returns upgrade link to pricing page' do
          expected_path = ::Gitlab::Routing.url_helpers.promo_pricing_url(query: {
            deployment: 'self-managed-deployment'
          })
          expect(attributes).to eq({ free_group_upgrade_link: expected_path })
        end
      end

      context 'when user is not admin' do
        it { is_expected.to eq({}) }
      end
    end

    context 'when gitlab_com_subscriptions feature is available', :saas_gitlab_com_subscriptions do
      context 'without group provided' do
        context 'when user owns no free groups' do
          before do
            allow(GitlabSubscriptions).to receive(:user_has_non_free_groups?).and_return(false)
            allow(user).to receive_message_chain(:owned_groups, :in_specific_plans, :not_aimed_for_deletion, :limit)
              .and_return(instance_double(ActiveRecord::Relation, empty?: true))
          end

          it { is_expected.to eq({}) }
        end

        context 'when user owns exactly one free group' do
          let(:free_group) { build_stubbed(:group) }

          before do
            allow(user).to receive(:can?).with(:edit_billing, free_group).and_return(true)
            allow(GitlabSubscriptions).to receive(:user_has_non_free_groups?).and_return(false)
            allow(user).to receive_message_chain(:owned_groups, :in_specific_plans, :not_aimed_for_deletion, :limit)
              .and_return([free_group])
          end

          it 'returns url pointing to the group billings path' do
            expected_path = ::Gitlab::Routing.url_helpers.group_billings_path(free_group)
            expect(attributes).to eq({ free_group_upgrade_link: expected_path })
          end
        end

        context 'when user owns multiple free groups' do
          let(:free_group_one) { build_stubbed(:group) }
          let(:free_group_two) { build_stubbed(:group) }

          before do
            allow(GitlabSubscriptions).to receive(:user_has_non_free_groups?).and_return(false)
            allow(user).to receive_message_chain(:owned_groups, :in_specific_plans, :not_aimed_for_deletion, :limit)
              .and_return([free_group_one, free_group_two])
          end

          it 'returns url pointing to profile billings path' do
            expected_path = ::Gitlab::Routing.url_helpers.profile_billings_path
            expect(attributes).to eq({ free_group_upgrade_link: expected_path })
          end
        end

        context 'when user owns free and paid groups' do
          let(:free_group) { build_stubbed(:group) }
          let(:free_groups) { instance_double(ActiveRecord::Relation, first: free_group, empty?: false, one?: false) }

          before do
            allow(GitlabSubscriptions).to receive(:user_has_non_free_groups?).and_return(true)
            allow(user).to receive_message_chain(:owned_groups, :in_specific_plans, :not_aimed_for_deletion, :limit)
              .and_return(free_groups)
          end

          it 'returns empty hash when user has non-free groups' do
            expect(attributes).to eq({})
          end
        end

        context 'when cache is populated', :use_clean_rails_memory_store_caching do
          let(:cached_link) { { free_group_upgrade_link: 'https://example.com/cached' } }

          before do
            GitlabSubscriptions::FreeGroupUpgradeLinkCache.get(user.id) { cached_link }
          end

          it 'returns cached value without computing' do
            expect(attributes).to eq(cached_link)
          end
        end
      end

      context 'with group provided' do
        context 'when group is not persisted' do
          let(:group) { build(:group) }

          it 'returns empty hash' do
            expect(attributes).to eq({})
          end
        end

        context 'when user has owner access and group is free' do
          let(:group) do
            build_stubbed(:group) do |record|
              build_stubbed(:gitlab_subscription, :free, namespace: record)
            end
          end

          before do
            allow(user).to receive(:can?).with(:edit_billing, group).and_return(true)
          end

          it 'returns url for the specific group' do
            expected_path = ::Gitlab::Routing.url_helpers.group_billings_path(group)
            expect(attributes).to eq({ free_group_upgrade_link: expected_path })
          end

          context 'when group is scheduled for deletion' do
            before do
              allow(group).to receive(:self_deletion_scheduled?).and_return(true)
            end

            it 'returns empty hash' do
              expect(attributes).to eq({})
            end
          end
        end

        context 'when user does not have owner access' do
          let(:group) do
            build_stubbed(:group) do |record|
              build_stubbed(:gitlab_subscription, :free, namespace: record)
            end
          end

          before do
            allow(user).to receive(:can?).with(:edit_billing, group).and_return(false)
          end

          it { is_expected.to eq({}) }
        end

        context 'when group is not free and user is admin' do
          let(:group) do
            build_stubbed(:group) do |record|
              build_stubbed(:gitlab_subscription, :ultimate, namespace: record)
            end
          end

          before do
            allow(user).to receive(:can?).with(:edit_billing, group).and_return(true)
          end

          it { is_expected.to eq({}) }
        end
      end
    end
  end
end
