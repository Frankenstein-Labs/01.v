# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UpgradePresenter, :saas, feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }
  let(:namespace) { nil }
  let(:project) { nil }

  describe '#attributes' do
    subject(:attributes) { described_class.new(user, namespace: namespace, project: project).attributes }

    context 'when gitlab_com_subscriptions feature is not available' do
      let(:license) { build_stubbed(:license, :ultimate_trial) }
      let(:authorized?) { true }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::License).to receive(:current).and_return(license)
        allow(Ability).to receive(:allowed?).with(user, :admin_all_resources).and_return(authorized?)
      end

      context 'when user is admin and has active ultimate trial license' do
        it 'returns upgrade link to admin subscription path' do
          expected_path = ::Gitlab::Routing.url_helpers.promo_pricing_url(query: { deployment: 'self-managed' })
          expect(attributes)
            .to eq({ upgrade_link: { url: expected_path, text: s_('CurrentUser|Upgrade subscription') } })
        end
      end

      context 'when user is not admin' do
        let(:authorized?) { false }

        it { is_expected.to eq({}) }
      end

      context 'when license is not active ultimate trial' do
        let(:license) { build_stubbed(:license, :ultimate_trial, expired: true) }

        it { is_expected.to eq({}) }
      end

      context 'when on a dedicated instance', :dedicated do
        it { is_expected.to eq({}) }
      end

      context 'when license is nil' do
        let(:license) { nil }

        it { is_expected.to eq({}) }
      end
    end

    context 'when gitlab_com_subscriptions feature is available' do
      let(:no_trial_eligible_namespaces) { false }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(::GitlabSubscriptions::Trials)
          .to receive(:no_eligible_namespaces_for_user?).and_return(no_trial_eligible_namespaces)
      end

      context 'without namespace provided' do
        context 'when user has no owned free or trial groups' do
          before do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return(Group.none)
          end

          it 'returns empty hash' do
            expect(attributes).to eq({})
          end

          context 'when user eligible for the start trial link' do
            let(:no_trial_eligible_namespaces) { true }

            it 'returns url pointing to the start ultimate trial path' do
              expected_path = ::Gitlab::Routing.url_helpers.new_trial_path(
                glm_source: 'gitlab.com', glm_content: 'top-right-dropdown'
              )
              expect(attributes)
                .to eq({ upgrade_link: { url: expected_path, text: s_('CurrentUser|Start an Ultimate trial') } })
            end
          end
        end

        context 'when user has exactly one free or trial group' do
          let(:group) { build_stubbed(:group) }

          before do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return([group])
          end

          it 'returns url pointing to the group billings path' do
            expected_path = ::Gitlab::Routing.url_helpers.group_billings_path(group)
            expect(attributes)
              .to eq({ upgrade_link: { url: expected_path, text: s_('CurrentUser|Upgrade subscription') } })
          end
        end

        context 'when user has multiple free or trial groups' do
          let(:group1) { build_stubbed(:group) }
          let(:group2) { build_stubbed(:group) }

          before do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return([group1, group2])
          end

          it 'returns url pointing to profile billings path' do
            expected_path = ::Gitlab::Routing.url_helpers.profile_billings_path
            expect(attributes)
              .to eq({ upgrade_link: { url: expected_path, text: s_('CurrentUser|Upgrade subscription') } })
          end
        end
      end

      context 'with namespace provided' do
        let(:namespace) { build_stubbed(:group) }

        context 'when user can edit billing and namespace is free or trial' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :edit_billing, namespace).and_return(true)
            allow(namespace).to receive_messages(paid?: false, trial?: false)
          end

          it 'returns url for the specific namespace' do
            expected_path = ::Gitlab::Routing.url_helpers.group_billings_path(namespace)
            expect(attributes)
              .to eq({ upgrade_link: { url: expected_path, text: s_('CurrentUser|Upgrade subscription') } })
          end

          context 'when namespace is not valid to generate the billing url' do
            # Not using factory bot to demonstrate why we need this as url gen will work for factory bot
            let(:namespace) { Group.new }

            it 'returns empty hash' do
              expect(attributes).to eq({})
            end
          end

          context 'when namespace is scheduled for deletion' do
            before do
              allow(namespace).to receive(:self_deletion_scheduled?).and_return(true)
            end

            it 'returns empty hash' do
              expect(attributes).to eq({})
            end
          end
        end

        context 'when user cannot edit billing' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :edit_billing, namespace).and_return(false)
            allow(namespace).to receive_messages(paid?: false, trial?: false)
          end

          it 'returns empty hash' do
            expect(attributes).to eq({})
          end
        end

        context 'when namespace is paid and not trial' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :edit_billing, namespace).and_return(true)
            allow(namespace).to receive_messages(paid?: true, trial?: false)
          end

          it 'returns empty hash' do
            expect(attributes).to eq({})
          end
        end
      end

      context 'with personal project' do
        context 'when project is saved' do
          let(:namespace) { build_stubbed(:user_namespace) }
          let(:project) { build_stubbed(:project, namespace: namespace) }

          before do
            allow(Ability).to receive(:allowed?).with(user, :change_namespace, project).and_return(allowed)
          end

          context 'when owner' do
            let(:allowed) { true }

            it 'returns url to transfer personal project' do
              expect(attributes).to eq({
                upgrade_link: {
                  url: ::Gitlab::Routing.url_helpers.project_transfer_personal_path(project),
                  text: s_('CurrentUser|Upgrade subscription'),
                  is_personal_project: true,
                  project_name: project.name,
                  project_full_path: project.full_path
                }
              })
            end
          end

          context 'when not owner' do
            let(:allowed) { false }

            it 'returns empty hash' do
              expect(attributes).to eq({})
            end
          end
        end

        context 'when project is not saved' do
          let(:project) { build(:project) }

          it 'returns empty hash' do
            expect(attributes).to eq({})
          end
        end
      end

      context 'with owned_groups_url caching behavior', :use_clean_rails_memory_store_caching do
        let(:cache_key) { ['users', user.id, 'owned_groups_url'] }

        context 'when cache is empty' do
          it 'fetches data and caches it' do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return([build(:group)])
            expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 10.minutes).and_call_original

            attributes
          end

          it 'stores nil in cache when no groups' do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return([])

            attributes

            cached_data = Rails.cache.read(cache_key)
            expect(cached_data).to be_nil
          end
        end

        context 'when cache exists' do
          let(:cached_url) { 'cached_url' }

          before do
            Rails.cache.write(cache_key, cached_url)
          end

          it 'uses cached data without database query' do
            expect(user).not_to receive(:owned_free_or_trial_groups_with_limit)

            result = attributes
            expect(result.dig(:upgrade_link, :url)).to eq(cached_url)
          end
        end
      end

      context 'with can_start_trial caching behavior', :use_clean_rails_memory_store_caching do
        let(:cache_key) { ['users', user.id, 'can_start_trial'] }

        context 'when cache is empty' do
          before do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return([])
          end

          it 'fetches data and caches it' do
            allow(Rails.cache).to receive(:fetch).and_call_original
            expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 10.minutes).and_call_original

            attributes
          end

          it 'stores the value' do
            attributes

            cached_data = Rails.cache.read(cache_key)
            expect(cached_data).to be(false)
          end
        end

        context 'when cache exists' do
          let(:cached_value) { true }

          before do
            Rails.cache.write(cache_key, cached_value)
          end

          it 'uses cached data without database query' do
            expect(GitlabSubscriptions::Trials).not_to receive(:no_eligible_namespaces_for_user?)

            expect(attributes.dig(:upgrade_link, :text)).to eq(s_('CurrentUser|Start an Ultimate trial'))
          end
        end
      end
    end
  end
end
