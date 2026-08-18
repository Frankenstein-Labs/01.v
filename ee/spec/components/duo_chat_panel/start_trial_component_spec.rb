# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DuoChatPanel::StartTrialComponent, :aggregate_failures, feature_category: :duo_chat do
  let(:user_namespace) { build_stubbed(:namespace) }
  let(:user) { build_stubbed(:user, namespace: user_namespace) }
  let(:record) { nil }
  let(:container) { instance_double(DuoChatPanel::Container, record: record) }

  subject(:component) { render_inline(described_class.new(container: container, user: user)) && page }

  before do
    allow(::Gitlab::Routing.url_helpers).to receive(:new_self_managed_trials_path)
      .and_return('/self-managed-trial')
    allow(Ability).to receive(:allowed?).and_call_original
  end

  describe 'rendering' do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:data).and_return({
          new_trial_path: '/trial',
          can_start_trial: 'true'
        })
      end
    end

    it 'renders the #duo-chat-panel element' do
      is_expected.to have_selector('#duo-chat-panel.duo-chat-panel')
    end

    it 'renders the new_trial_path data attribute on the element' do
      is_expected.to have_css('#duo-chat-panel[data-new-trial-path="/trial"]')
    end

    it 'renders the can_start_trial data attribute on the element' do
      is_expected.to have_css('#duo-chat-panel[data-can-start-trial="true"]')
    end
  end

  describe '#data' do
    it_behaves_like 'sets auto_expand field with respect to the legacy callout'

    context 'on .com', :saas_gitlab_com_subscriptions do
      let_it_be(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed to test group persistence

      before do
        allow(group).to receive(:has_free_or_no_subscription?).and_return(has_free_or_no_subscription?)
        allow(Ability).to receive(:allowed?).with(user, :start_trial, group).and_return(can_start_trial?)
      end

      context 'when user cannot start a trial due to lack of permissions in the namespace' do
        let(:can_start_trial?) { false }
        let(:has_free_or_no_subscription?) { true }
        let(:record) { group }

        it 'returns can_start_trial as false without a trial path' do
          is_expected.to have_css('#duo-chat-panel[data-can-start-trial="false"]')
          is_expected.not_to have_css('#duo-chat-panel[data-new-trial-path]')
        end
      end

      context 'when user cannot start a trial due to existing subscription' do
        let(:can_start_trial?) { true }
        let(:has_free_or_no_subscription?) { false }
        let(:record) { group }

        it 'returns can_start_trial as false' do
          is_expected.to have_css('#duo-chat-panel[data-can-start-trial="false"]')
          is_expected.not_to have_css('#duo-chat-panel[data-new-trial-path]')
        end
      end

      context 'when user can start a trial' do
        let(:can_start_trial?) { true }
        let(:has_free_or_no_subscription?) { true }

        context 'when there is no record' do
          let(:record) { nil }

          it 'returns can_start_trial as true with default trial duration' do
            is_expected.to have_css('#duo-chat-panel[data-can-start-trial="true"]')
            is_expected.to have_css('#duo-chat-panel[data-trial-duration="30"]')
            is_expected.to have_css('#duo-chat-panel[data-new-trial-path]')
          end
        end

        context 'when within a project owned by a user' do
          let(:record) { build(:project, namespace: user_namespace) }

          it 'returns can_start_trial as true' do
            is_expected.to have_css('#duo-chat-panel[data-can-start-trial="true"]')
            is_expected.to have_css('#duo-chat-panel[data-trial-duration="30"]')
          end
        end

        context 'when within a project owned by a group' do
          let(:record) { build(:project, namespace: group) }

          it 'returns can_start_trial as true' do
            is_expected.to have_css('#duo-chat-panel[data-can-start-trial="true"]')
            is_expected.to have_css('#duo-chat-panel[data-trial-duration="30"]')
          end
        end

        context 'when within a group' do
          let(:record) { group }

          it 'returns can_start_trial as true' do
            is_expected.to have_css('#duo-chat-panel[data-can-start-trial="true"]')
            is_expected.to have_css('#duo-chat-panel[data-trial-duration="30"]')
          end
        end

        context 'when the root ancestor is not persisted' do
          let(:record) { group }

          before do
            allow(group).to receive(:persisted?).and_return(false)
          end

          it 'returns can_start_trial as false' do
            is_expected.to have_css('#duo-chat-panel[data-can-start-trial="false"]')
          end
        end

        context 'when the root ancestor is nil' do
          let(:record) { group }

          before do
            allow(group).to receive(:root_ancestor).and_return(nil)
          end

          it 'returns can_start_trial as false' do
            is_expected.to have_css('#duo-chat-panel[data-can-start-trial="false"]')
          end
        end

        context 'when the trial duration is not the default' do
          let(:record) { nil }

          before do
            stub_saas_features(subscriptions_trials: true)
            allow_next_instance_of(GitlabSubscriptions::TrialDurationService) do |service|
              allow(service).to receive(:execute).and_return(20)
            end
          end

          it 'returns the custom trial duration' do
            is_expected.to have_css('#duo-chat-panel[data-can-start-trial="true"]')
            is_expected.to have_css('#duo-chat-panel[data-trial-duration="20"]')
          end
        end
      end
    end

    context 'on Self-Managed' do
      let_it_be(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persistence
      let(:record) { group }

      context 'when user cannot start a trial' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :update_gitlab_subscription).and_return(false)
        end

        it 'returns can_start_trial as false without a trial path' do
          is_expected.to have_css('#duo-chat-panel[data-can-start-trial="false"]')
          is_expected.not_to have_css('#duo-chat-panel[data-new-trial-path]')
        end
      end

      context 'when user can start a trial' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :update_gitlab_subscription).and_return(true)
        end

        it 'returns can_start_trial as true with the self-managed trial path' do
          is_expected.to have_css('#duo-chat-panel[data-can-start-trial="true"]')
          is_expected.to have_css('#duo-chat-panel[data-trial-duration="30"]')
          is_expected.to have_css('#duo-chat-panel[data-new-trial-path="/self-managed-trial"]')
        end
      end
    end
  end
end
