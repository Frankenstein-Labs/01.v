# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DuoChatPanel::ChatComponent, :aggregate_failures, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for global_id
  let(:project) { nil }
  let(:group) { nil }
  let(:controller_name) { nil }

  subject(:component) do
    render_inline(
      described_class.new(user: user, project: project, group: group, controller_name: controller_name)
    ) && page
  end

  describe 'rendering' do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:data).and_return({ user_id: 'test-user-id' })
      end
    end

    it 'renders the #duo-chat-panel element' do
      is_expected.to have_selector('#duo-chat-panel')
    end

    it 'has the duo-chat-panel class' do
      is_expected.to have_selector('.duo-chat-panel')
    end

    it 'renders the user_id data attribute on the element' do
      is_expected.to have_css('#duo-chat-panel[data-user-id="test-user-id"]')
    end

    context 'when source is a Project' do
      let(:project) { build_stubbed(:project) }

      it 'renders the #duo-chat-panel element' do
        is_expected.to have_selector('#duo-chat-panel')
      end
    end

    context 'when source is a Group' do
      let(:group) { build_stubbed(:group) }

      it 'renders the #duo-chat-panel element' do
        is_expected.to have_selector('#duo-chat-panel')
      end
    end
  end

  describe '#data' do
    let(:project) { build(:project) }
    let(:group) { build(:group) }

    let(:duo_chat_instance) { instance_double(::Gitlab::Llm::DuoChat) }
    let(:duo_chat_agentic_available) { false }
    let(:duo_chat_classic_chat_available) { false }
    let(:duo_chat_credits_available) { true }

    let(:instance) do
      described_class.new(user: user, project: project, group: group, controller_name: controller_name)
    end

    let(:helpers_double) do
      double('helpers', # rubocop:disable RSpec/VerifiedDoubles -- ViewComponent helpers proxy
        profile_preferences_path: '/profile/preferences',
        ai_panel_expanded?: false,
        explore_ai_catalog_path: '/explore/ai',
        admin_gitlab_credits_dashboard_index_path: '/admin/credits',
        current_user: user,
        link_to: '<a></a>'.html_safe,
        content_tag: '<strong></strong>'.html_safe,
        edit_project_path: '/project/edit#js-gitlab-duo-settings'
      )
    end

    subject(:result) { instance.send(:data) }

    before do
      # Stub the helpers proxy
      allow(instance).to receive(:helpers).and_return(helpers_double)
      allow(helpers_double).to receive(:group_settings_gitlab_credits_dashboard_index_path)
        .and_return('/group/credits')

      allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
        .with(user, project, group, controller_name)
        .and_return({ project: project, namespace: group, default_namespace_applied: false })

      allow(::Gitlab::Llm::DuoChat).to receive(:new).and_return(duo_chat_instance)
      allow(duo_chat_instance).to receive_messages(
        user_model_selection_enabled?: false,
        agentic_mode_available?: duo_chat_agentic_available,
        classic_chat_available?: duo_chat_classic_chat_available,
        credits_available?: duo_chat_credits_available,
        chat_disabled_reason: nil,
        default_duo_namespace_check_passes?: true
      )

      allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:container).and_return(
        instance_double(Ai::UserAuthorizable::Response, allowed?: true)
      )
      allow(::Gitlab::DuoWorkflow::Client).to receive(:metadata).with(user,
        namespace: anything, project: anything).and_return({ key: 'value' })
      allow(::Ai::AmazonQ).to receive_messages(enabled?: false, connected?: false)
      allow(Gitlab::Saas).to receive(:feature_available?).and_call_original
      allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
      allow(Ability).to receive(:allowed?).and_call_original
    end

    it 'returns user global id' do
      expect(result[:user_id]).to eq(user.to_global_id)
    end

    context 'when project is persisted' do
      let(:project) { create(:project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persist check

      it 'returns project global id when project is persisted' do
        expect(result[:project_id]).to eq(project.to_global_id)
      end
    end

    it 'returns nil project id when project is not persisted' do
      expect(result[:project_id]).to be_nil
    end

    it 'returns nil project id when project is nil' do
      allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
        .and_return({ project: nil, namespace: group, default_namespace_applied: false })

      expect(result[:project_id]).to be_nil
    end

    context 'when group is persisted' do
      let(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persist check

      it 'returns group global id when group is persisted' do
        expect(result[:namespace_id]).to eq(group.to_global_id)
      end
    end

    it 'returns nil namespace id when group is not persisted' do
      expect(result[:namespace_id]).to be_nil
    end

    it 'returns nil namespace id when group is nil' do
      allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
        .and_return({ project: project, namespace: nil, default_namespace_applied: false })

      expect(result[:namespace_id]).to be_nil
    end

    context 'for root_namespace_id' do
      context 'when the container is persisted' do
        let_it_be(:root_group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for root_ancestor
        let_it_be(:project) { create(:project, group: root_group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for root_ancestor

        it 'returns the root ancestor global id of the container' do
          expect(result[:root_namespace_id]).to eq(root_group.to_global_id)
        end
      end

      context 'when the container is not persisted' do
        it 'returns nil' do
          expect(result[:root_namespace_id]).to be_nil
        end
      end

      context 'when there is no container' do
        before do
          allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
            .and_return({ namespace: nil, default_namespace_applied: true })
        end

        it 'returns nil' do
          expect(result[:root_namespace_id]).to be_nil
        end
      end
    end

    context 'for resource_id' do
      let(:issue) { build_stubbed(:issue) }

      it 'returns the ai_resource from the current context' do
        Gitlab::ApplicationContext.push(ai_resource: issue.to_global_id)

        expect(result[:resource_id]).to eq(issue.to_global_id)
      end

      it 'returns nil when no ai_resource is in the context' do
        expect(result[:resource_id]).to be_nil
      end
    end

    it 'returns metadata as JSON string' do
      expect(result[:metadata]).to eq('{"key":"value"}')
    end

    it 'calls DuoWorkflow Client metadata with user and namespace' do
      expect(Gitlab::DuoWorkflow::Client).to receive(:metadata)
        .with(user, namespace: project.root_ancestor, project: anything)

      result
    end

    it 'returns user model selection enabled as string' do
      allow(duo_chat_instance).to receive(:user_model_selection_enabled?).and_return(true)

      expect(result[:user_model_selection_enabled]).to eq('true')
    end

    context 'when agentic mode is available' do
      let(:duo_chat_agentic_available) { true }

      it 'returns agentic available as string' do
        expect(result[:agentic_available]).to eq('true')
      end
    end

    it 'returns credits available as string when true' do
      expect(result[:credits_available]).to eq('true')
    end

    context 'when credits are not available' do
      let(:duo_chat_credits_available) { false }

      it 'returns credits available as string when false' do
        expect(result[:credits_available]).to eq('false')
      end
    end

    it 'returns default chat title when AmazonQ is disabled' do
      expect(result[:chat_title]).to eq('GitLab Duo Chat')
    end

    it 'returns AmazonQ chat title when AmazonQ is enabled' do
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)

      expect(result[:chat_title]).to eq('GitLab Duo Chat with Amazon Q')
    end

    describe 'explore_ai_catalog_path' do
      context 'when user has read_ai_catalog permission' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog).and_return(true)
        end

        it 'returns the explore_ai_catalog_path' do
          expect(result[:explore_ai_catalog_path]).to eq('/explore/ai')
        end
      end

      context 'when user does not have read_ai_catalog permission (e.g. DAP is disabled)' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog).and_return(false)
        end

        it 'returns nil for explore_ai_catalog_path' do
          expect(result[:explore_ai_catalog_path]).to be_nil
        end
      end
    end

    it 'calls DuoChat methods with project taking priority' do
      expect(Gitlab::Llm::DuoChat).to receive(:new).with(
        user: user,
        container: project,
        project: project,
        group: group
      ).and_return(duo_chat_instance)
      expect(duo_chat_instance).to receive(:user_model_selection_enabled?)
      expect(duo_chat_instance).to receive(:agentic_mode_available?)
      expect(duo_chat_instance).to receive(:classic_chat_available?)
      expect(duo_chat_instance).to receive(:credits_available?)
      expect(duo_chat_instance).to receive(:chat_disabled_reason)
      expect(duo_chat_instance).to receive(:default_duo_namespace_check_passes?)

      result
    end

    it 'calls DuoChat methods with group when project is absent' do
      allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
        .and_return({ project: nil, namespace: group, default_namespace_applied: false })

      expect(Gitlab::Llm::DuoChat).to receive(:new).with(
        user: user,
        container: group,
        project: nil,
        group: group
      ).and_return(duo_chat_instance)
      expect(duo_chat_instance).to receive(:user_model_selection_enabled?)
      expect(duo_chat_instance).to receive(:agentic_mode_available?)
      expect(duo_chat_instance).to receive(:classic_chat_available?)
      expect(duo_chat_instance).to receive(:credits_available?)
      expect(duo_chat_instance).to receive(:chat_disabled_reason)
      expect(duo_chat_instance).to receive(:default_duo_namespace_check_passes?)

      result
    end

    it 'returns chat_disabled_reason as empty string when chat is enabled' do
      expect(result[:chat_disabled_reason]).to eq('')
    end

    context 'when chat is disabled for project' do
      before do
        allow(duo_chat_instance).to receive(:chat_disabled_reason).and_return(:project)
      end

      it 'returns chat_disabled_reason as "project"' do
        expect(result[:chat_disabled_reason]).to eq('project')
      end
    end

    context 'when chat is disabled for group' do
      before do
        allow(duo_chat_instance).to receive(:chat_disabled_reason).and_return(:group)
      end

      it 'returns chat_disabled_reason as "group"' do
        expect(result[:chat_disabled_reason]).to eq('group')
      end
    end

    describe 'trial and billing attributes' do
      let_it_be(:root_group) { build_stubbed(:group) }
      let(:purchase_credits_url) { 'https://customers.gitlab.com/subscriptions/purchases/gitlab' }

      before do
        allow(user).to receive(:governing_namespace).and_return(root_group)
        allow(root_group).to receive(:free_plan?).and_return(false)
        allow(::Gitlab::Routing.url_helpers).to receive(:subscription_portal_gitlab_com_purchase_credits_url)
          .with(root_group.id)
          .and_return(purchase_credits_url)
        allow(helpers_double).to receive(:upgrade_base_plan_subscriptions_path) do |namespace_id:|
          "/-/subscriptions/upgrade_base_plan?namespace_id=#{namespace_id}"
        end
      end

      it 'returns is_saas as "true"' do
        expect(result[:is_saas]).to eq('true')
      end

      context 'when namespace has active trial' do
        before do
          allow(root_group).to receive(:trial_active?).and_return(true)
        end

        it 'returns is_trial as "true"' do
          expect(result[:is_trial]).to eq('true')
        end
      end

      context 'when namespace does not have active trial' do
        before do
          allow(root_group).to receive(:trial_active?).and_return(false)
        end

        it 'returns is_trial as "false"' do
          expect(result[:is_trial]).to eq('false')
        end
      end

      context 'when user can edit billing' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :edit_billing, root_group).and_return(true)
        end

        context 'when not on trial' do
          before do
            allow(root_group).to receive(:trial_active?).and_return(false)
          end

          it 'returns can_buy_addon as "true"' do
            expect(result[:can_buy_addon]).to eq('true')
          end

          it 'returns credits dashboard path for buy_addon_path' do
            expect(result[:buy_addon_path]).to eq('/group/credits')
          end

          it 'returns CDot purchase credits URL for purchase_credits_path' do
            expect(result[:purchase_credits_path]).to eq(purchase_credits_url)
          end

          it 'returns internal subscriptions path scoped to the namespace' do
            expect(result[:tier_upgrade_path])
              .to eq("/-/subscriptions/upgrade_base_plan?namespace_id=#{root_group.id}")
          end
        end

        context 'when on trial' do
          before do
            allow(root_group).to receive(:trial_active?).and_return(true)
          end

          it 'returns can_buy_addon as "true"' do
            expect(result[:can_buy_addon]).to eq('true')
          end

          it 'returns subscription portal URL for buy_addon_path' do
            expect(result[:buy_addon_path]).to eq(::Gitlab::Routing.url_helpers.subscription_portal_url)
          end

          it 'returns CDot purchase credits URL for purchase_credits_path' do
            expect(result[:purchase_credits_path]).to eq(purchase_credits_url)
          end
        end
      end

      context 'when user cannot edit billing' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :edit_billing, root_group).and_return(false)
          allow(root_group).to receive(:trial_active?).and_return(false)
        end

        it 'returns can_buy_addon as "false"' do
          expect(result[:can_buy_addon]).to eq('false')
        end

        it 'returns nil buy_addon_path' do
          expect(result[:buy_addon_path]).to be_nil
        end

        it 'returns nil purchase_credits_path' do
          expect(result[:purchase_credits_path]).to be_nil
        end

        it 'still returns the tier upgrade path (not gated on billing permission)' do
          expect(result[:tier_upgrade_path])
            .to eq("/-/subscriptions/upgrade_base_plan?namespace_id=#{root_group.id}")
        end
      end

      context 'when namespace is nil' do
        before do
          allow(user).to receive(:governing_namespace).and_return(nil)
        end

        it 'returns is_trial as "false"' do
          expect(result[:is_trial]).to eq('false')
        end

        it 'returns can_buy_addon as "false"' do
          expect(result[:can_buy_addon]).to eq('false')
        end

        it 'returns nil buy_addon_path' do
          expect(result[:buy_addon_path]).to be_nil
        end

        it 'returns nil purchase_credits_path' do
          expect(result[:purchase_credits_path]).to be_nil
        end

        it 'returns nil tier upgrade path' do
          expect(result[:tier_upgrade_path]).to be_nil
        end
      end

      context 'on self-managed instance' do
        before do
          allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(false)
        end

        it 'returns is_saas as "false"' do
          expect(result[:is_saas]).to eq('false')
        end

        it 'returns nil tier upgrade path' do
          expect(result[:tier_upgrade_path]).to be_nil
        end

        context 'when user is admin' do
          let(:sm_purchase_credits_url) { 'https://customers.gitlab.com/subscriptions/purchases/gitlab?deployment_type=self_managed' }

          before do
            allow(Ability).to receive(:allowed?).with(user, :admin_all_resources).and_return(true)
            allow(::Gitlab::Routing.url_helpers).to receive(:subscription_portal_self_managed_purchase_credits_url)
              .and_return(sm_purchase_credits_url)
            allow(::Gitlab::Routing.url_helpers).to receive(:subscription_portal_self_managed_purchase_credits_url)
              .with(subscription_name: 'A-123456')
              .and_return("#{sm_purchase_credits_url}&subscription_name=A-123456")
          end

          context 'when no license' do
            before do
              allow(License).to receive(:current).and_return(nil)
            end

            it 'returns is_trial as "false"' do
              expect(result[:is_trial]).to eq('false')
            end

            it 'returns CDot SM purchase credits base URL without subscription_name' do
              expect(result[:purchase_credits_path]).to eq(sm_purchase_credits_url)
            end
          end

          context 'when not on trial' do
            # License delegates expired? via method_missing, so instance_double rejects it
            let(:license) { double('License', trial?: false, paid?: true, expired?: false, subscription_name: 'A-123456') } # rubocop:disable RSpec/VerifiedDoubles -- see comment above

            before do
              allow(License).to receive(:current).and_return(license)
            end

            it 'returns can_buy_addon as "true"' do
              expect(result[:can_buy_addon]).to eq('true')
            end

            it 'returns admin credits dashboard path for buy_addon_path' do
              expect(result[:buy_addon_path]).to eq('/admin/credits')
            end

            it 'returns CDot SM purchase credits URL with subscription_name for purchase_credits_path' do
              expect(result[:purchase_credits_path]).to eq("#{sm_purchase_credits_url}&subscription_name=A-123456")
            end
          end

          context 'when on trial' do
            before do
              allow(License).to receive(:current).and_return(
                instance_double(License, trial?: true, paid?: false, subscription_name: 'A-123456')
              )
            end

            it 'returns can_buy_addon as "true"' do
              expect(result[:can_buy_addon]).to eq('true')
            end

            it 'returns subscription portal URL for buy_addon_path' do
              expect(result[:buy_addon_path]).to eq(::Gitlab::Routing.url_helpers.subscription_portal_url)
            end

            it 'returns CDot SM purchase credits URL with subscription_name for purchase_credits_path' do
              expect(result[:purchase_credits_path]).to eq("#{sm_purchase_credits_url}&subscription_name=A-123456")
            end
          end
        end

        context 'when user is not admin' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :admin_all_resources).and_return(false)
          end

          it 'returns can_buy_addon as "false"' do
            expect(result[:can_buy_addon]).to eq('false')
          end

          it 'returns nil buy_addon_path' do
            expect(result[:buy_addon_path]).to be_nil
          end

          it 'returns nil purchase_credits_path' do
            expect(result[:purchase_credits_path]).to be_nil
          end
        end
      end
    end

    describe 'trial and subscription attributes' do
      context 'when SaaS subscriptions feature is available' do
        before do
          allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
        end

        it 'returns nil trial and subscription status when project and group are nil' do
          allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
            .and_return({ project: nil, namespace: nil, default_namespace_applied: false })

          expect(result[:trial_active]).to be_nil
          expect(result[:subscription_active]).to be_nil
        end

        context 'with group namespace' do
          let(:root_namespace) { build(:group) }

          before do
            allow(group).to receive(:root_ancestor).and_return(root_namespace)
            allow(root_namespace).to receive(:trial_active?).and_return(true)
            allow(GitlabSubscriptions).to receive(:active?).with(root_namespace).and_return(false)
          end

          it 'returns root namespace trial and subscription status' do
            allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
              .and_return({ project: nil, namespace: group, default_namespace_applied: false })

            expect(result[:trial_active]).to eq('true')
            expect(result[:subscription_active]).to eq('false')
          end
        end

        context 'with project namespace' do
          let(:root_namespace) { build(:group) }

          before do
            allow(project).to receive(:root_ancestor).and_return(root_namespace)
            allow(root_namespace).to receive(:trial_active?).and_return(false)
            allow(GitlabSubscriptions).to receive(:active?).with(root_namespace).and_return(true)
          end

          it 'returns project root namespace trial and subscription status' do
            allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
              .and_return({ project: project, namespace: nil, default_namespace_applied: false })

            expect(result[:trial_active]).to eq('false')
            expect(result[:subscription_active]).to eq('true')
          end
        end
      end

      context 'when SaaS subscriptions feature is not available' do
        before do
          allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(false)
        end

        context 'when License.current is present' do
          before do
            allow(License).to receive(:current).and_return(instance_double(License, trial?: true, paid?: true))
          end

          it 'returns license trial and subscription status' do
            expect(result[:trial_active]).to eq('true')
            expect(result[:subscription_active]).to eq('true')
          end
        end

        context 'when License.current is nil' do
          before do
            allow(License).to receive(:current).and_return(nil)
          end

          it 'returns nil for trial and subscription status' do
            expect(result[:trial_active]).to be_nil
            expect(result[:subscription_active]).to be_nil
          end
        end

        context 'when License.current is paid' do
          let(:license) { build(:license, :active_paid) }

          before do
            allow(License).to receive(:current).and_return(license)
          end

          it 'returns paid subscription status' do
            # A non-trial license leaves the :trial restriction unset, so License#trial? is nil
            # (not false) and the component renders trial_active as an empty string.
            expect(result[:trial_active]).to eq('')
            expect(result[:subscription_active]).to eq('true')
          end
        end
      end
    end

    describe 'subscription_expired attribute' do
      context 'on SaaS' do
        before do
          allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
        end

        context 'when namespace is nil' do
          it 'returns "false"' do
            allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
              .and_return({ project: nil, namespace: nil, default_namespace_applied: false })

            expect(result[:subscription_expired]).to eq('false')
          end
        end

        context 'when namespace subscription is paid and expired' do
          let(:root_namespace) { build(:group) }
          let(:gitlab_subscription) { instance_double(GitlabSubscription, paid_and_expired?: true) }

          before do
            allow(group).to receive(:root_ancestor).and_return(root_namespace)
            allow(root_namespace).to receive_messages(trial_active?: false, gitlab_subscription: gitlab_subscription)
            allow(GitlabSubscriptions).to receive(:active?).with(root_namespace).and_return(false)
          end

          it 'returns "true"' do
            expect(result[:subscription_expired]).to eq('true')
          end
        end

        context 'when namespace subscription is not paid-and-expired' do
          let(:root_namespace) { build(:group) }
          let(:gitlab_subscription) { instance_double(GitlabSubscription, paid_and_expired?: false) }

          before do
            allow(group).to receive(:root_ancestor).and_return(root_namespace)
            allow(root_namespace).to receive_messages(trial_active?: false, gitlab_subscription: gitlab_subscription)
            allow(GitlabSubscriptions).to receive(:active?).with(root_namespace).and_return(true)
          end

          it 'returns "false"' do
            expect(result[:subscription_expired]).to eq('false')
          end
        end
      end

      context 'on self-managed' do
        before do
          allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(false)
        end

        context 'when license is expired and non-trial' do
          let(:license) { build(:license, :expired_paid) }

          before do
            allow(License).to receive(:current).and_return(license)
          end

          it 'returns "true"' do
            expect(result[:subscription_expired]).to eq('true')
          end
        end

        context 'when license is a trial that is expired' do
          let(:license) { double('License', trial?: true, expired?: true, paid?: false) } # rubocop:disable RSpec/VerifiedDoubles -- License delegates expired?/trial? via method_missing

          before do
            allow(License).to receive(:current).and_return(license)
          end

          it 'returns "false"' do
            expect(result[:subscription_expired]).to eq('false')
          end
        end

        context 'when license is nil' do
          before do
            allow(License).to receive(:current).and_return(nil)
          end

          it 'returns "false"' do
            expect(result[:subscription_expired]).to eq('false')
          end
        end
      end
    end

    describe '#should_auto_expand_panel?' do
      context 'when user has not dismissed the callout' do
        it 'returns auto_expand as "true"' do
          expect(result[:auto_expand]).to eq('true')
        end
      end

      context 'when user has dismissed the callout' do
        before do
          allow(user).to receive(:dismissed_callout?).with(feature_name: 'duo_panel_auto_expanded').and_return(true)
        end

        it 'returns auto_expand as "false"' do
          expect(result[:auto_expand]).to eq('false')
        end
      end

      context 'when user is nil' do
        it 'returns false' do
          nil_instance = described_class.new(user: nil, project: project, group: group,
            controller_name: controller_name)
          allow(nil_instance).to receive(:helpers).and_return(helpers_double)
          expect(nil_instance.send(:should_auto_expand_panel?, nil, 'duo_panel_auto_expanded')).to be(false)
        end
      end
    end

    describe '#agentic_unavailable_message' do
      let(:allowed) { false }
      let(:enablement_type) { nil }
      let(:duo_response) do
        instance_double(Ai::UserAuthorizable::Response, enablement_type: enablement_type, allowed?: allowed)
      end

      before do
        allow(user).to receive(:allowed_to_use).and_return(duo_response)
      end

      context 'when agentic is available' do
        let(:duo_chat_agentic_available) { true }

        it 'returns nil' do
          expect(result[:agentic_unavailable_message]).to be_nil
        end
      end

      context 'when agentic is not available and container is present' do
        it 'returns nil' do
          expect(result[:agentic_unavailable_message]).to be_nil
        end
      end

      context 'when agentic is not available and container is nil' do
        before do
          allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
            .and_return({ project: nil, namespace: nil, default_namespace_applied: false })
        end

        context 'with duo_pro enablement' do
          let(:allowed) { true }
          let(:enablement_type) { 'duo_pro' }

          it 'includes namespace preference message' do
            expect(result[:agentic_unavailable_message]).to include(
              'Duo Agentic Chat is not available at the moment in this page.'
            )
          end
        end

        context 'with duo_core enablement' do
          let(:allowed) { true }
          let(:enablement_type) { 'duo_core' }

          it 'includes namespace preference message' do
            expect(result[:agentic_unavailable_message]).to include(
              'Duo Agentic Chat is not available at the moment in this page.'
            )
          end
        end

        context 'when user is not allowed chat at all' do
          let(:allowed) { false }

          it 'returns nil' do
            expect(result[:agentic_unavailable_message]).to be_nil
          end
        end
      end
    end

    describe '#force_agentic_mode_for_core_duo_users?' do
      let(:allowed) { true }
      let(:enablement_type) { 'duo_pro' }
      let(:duo_response) do
        instance_double(Ai::UserAuthorizable::Response, enablement_type: enablement_type, allowed?: allowed)
      end

      before do
        allow(user).to receive(:allowed_to_use)
                         .with(:agentic_chat, hash_including(unit_primitive_name: :duo_chat))
                         .and_return(duo_response)
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(no_duo_classic_for_duo_core_users: false)
        end

        it 'returns "false"' do
          expect(result[:force_agentic_mode_for_core_duo_users]).to eq('false')
        end
      end

      context 'when feature flag is enabled' do
        before do
          stub_feature_flags(no_duo_classic_for_duo_core_users: true)
        end

        context 'when user has duo_pro enablement' do
          let(:enablement_type) { 'duo_pro' }

          it 'returns "false"' do
            expect(result[:force_agentic_mode_for_core_duo_users]).to eq('false')
          end
        end

        context 'when user has duo_core enablement' do
          let(:enablement_type) { 'duo_core' }

          it 'returns "true"' do
            expect(result[:force_agentic_mode_for_core_duo_users]).to eq('true')
          end
        end

        context 'when user is not allowed to use duo_chat' do
          let(:allowed) { false }

          it 'returns "false"' do
            expect(result[:force_agentic_mode_for_core_duo_users]).to eq('false')
          end
        end
      end
    end

    describe '#free_addon_credits_user?' do
      let(:duo_response) do
        instance_double(Ai::UserAuthorizable::Response, allowed?: allowed, enablement_type: enablement_type)
      end

      let(:allowed) { true }
      let(:enablement_type) { 'duo_pro' }

      before do
        allow(user).to receive(:allowed_to_use).and_return(duo_response)
      end

      context 'when enablement_type is gitlab_credits' do
        let(:enablement_type) { 'gitlab_credits' }

        it 'returns is_free_addon_credits_user as "true"' do
          expect(result[:is_free_addon_credits_user]).to eq('true')
        end
      end

      context 'when enablement_type is duo_pro' do
        let(:enablement_type) { 'duo_pro' }

        it 'returns is_free_addon_credits_user as "false"' do
          expect(result[:is_free_addon_credits_user]).to eq('false')
        end
      end

      context 'when enablement_type is duo_core' do
        let(:enablement_type) { 'duo_core' }

        it 'returns is_free_addon_credits_user as "false"' do
          expect(result[:is_free_addon_credits_user]).to eq('false')
        end
      end

      context 'when user is not allowed to use duo_chat' do
        let(:duo_response) do
          instance_double(Ai::UserAuthorizable::Response, allowed?: false)
        end

        it 'returns is_free_addon_credits_user as "false"' do
          expect(result[:is_free_addon_credits_user]).to eq('false')
        end
      end
    end

    describe '#hand_raise_lead_data' do
      let_it_be(:root_group) { build_stubbed(:group) }

      let(:free_plan_with_credits) { true }
      let(:can_edit_billing) { true }

      before do
        allow(user).to receive(:governing_namespace).and_return(root_group)
        allow(root_group).to receive_messages(
          free_plan_with_gitlab_credits_add_on?: free_plan_with_credits,
          trial_active?: false
        )
        allow(Ability).to receive(:allowed?).with(user, :edit_billing, root_group).and_return(can_edit_billing)
        allow(helpers_double).to receive(:upgrade_base_plan_subscriptions_path).and_return('/upgrade')
        allow(::Gitlab::Routing.url_helpers).to receive(:subscription_portal_gitlab_com_purchase_credits_url)
          .and_return('https://customers.gitlab.com/credits')
        allow(helpers_double).to receive(:hand_raise_modal_dataset).with(root_group).and_return(
          user: '{"namespace_id":42}',
          submit_path: '/-/gitlab_subscriptions/hand_raise_leads'
        )
      end

      context 'when a free-plan namespace owner has a GitLab credits add-on' do
        it 'returns hand raise lead data for the "Talk to sales" CTA' do
          expect(result[:hand_raise_lead_user]).to eq('{"namespace_id":42}')
          expect(result[:hand_raise_lead_submit_path]).to eq('/-/gitlab_subscriptions/hand_raise_leads')
        end
      end

      context 'when the gate for the "Talk to sales" CTA is not fully satisfied' do
        using RSpec::Parameterized::TableSyntax

        where(:free_plan_with_credits, :can_edit_billing, :saas_available) do
          false | true  | true  # namespace is not a free namespace with a credits add-on
          true  | false | true  # the user cannot buy subscriptions
          true  | true  | false # not on SaaS
        end

        with_them do
          before do
            allow(Gitlab::Saas).to receive(:feature_available?)
              .with(:gitlab_com_subscriptions).and_return(saas_available)
          end

          it 'omits hand raise lead data so no user PII / CTA data is emitted' do
            expect(result).not_to have_key(:hand_raise_lead_user)
            expect(result).not_to have_key(:hand_raise_lead_submit_path)
          end
        end
      end
    end

    describe '#duo_agent_platform_enabled?' do
      context 'when duo agent platform is available for the container' do
        before do
          allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).with(project).and_return(true)
        end

        it 'returns duo_agent_platform_enabled as "true"' do
          expect(result[:duo_agent_platform_enabled]).to eq('true')
        end
      end

      context 'when duo agent platform is not available for the container' do
        before do
          allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).with(project).and_return(false)
        end

        it 'returns duo_agent_platform_enabled as "false"' do
          expect(result[:duo_agent_platform_enabled]).to eq('false')
        end
      end
    end

    describe '#duo_disabled_admin_settings_path' do
      let(:authorizer_response) do
        instance_double(Ai::UserAuthorizable::Response, allowed?: authorizer_allowed)
      end

      let(:authorizer_allowed) { true }

      before do
        allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:container)
          .and_return(authorizer_response)
      end

      context 'when container is nil' do
        before do
          allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
            .and_return({ project: nil, namespace: nil, default_namespace_applied: false })
        end

        it 'returns nil duo_settings_path' do
          expect(result[:duo_settings_path]).to be_nil
        end
      end

      context 'when default_namespace_applied is true' do
        before do
          allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
            .and_return({ project: project, namespace: group, default_namespace_applied: true })
        end

        it 'returns nil duo_settings_path' do
          expect(result[:duo_settings_path]).to be_nil
        end
      end

      context 'when container is present and chat is authorized' do
        let(:authorizer_allowed) { true }

        it 'returns nil duo_settings_path' do
          expect(result[:duo_settings_path]).to be_nil
        end
      end

      context 'when container is present and chat is not authorized' do
        let(:authorizer_allowed) { false }

        context 'when container is a project and user is admin' do
          let(:project) { build(:project) }

          before do
            allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
              .and_return({ project: project, namespace: nil, default_namespace_applied: false })
            allow(Ability).to receive(:allowed?).with(user, :admin_project, project).and_return(true)
          end

          it 'returns project edit path' do
            expect(result[:duo_settings_path]).to eq('/project/edit#js-gitlab-duo-settings')
          end
        end

        context 'when container is a group and user is admin' do
          let(:group) { build(:group) }

          before do
            allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
              .and_return({ project: nil, namespace: group, default_namespace_applied: false })
            allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(true)
            allow(group).to receive(:duo_settings_path).and_return('/group/duo-settings')
          end

          it 'returns group duo settings path' do
            expect(result[:duo_settings_path]).to eq('/group/duo-settings')
          end
        end

        context 'when user is not admin of the project container' do
          let(:project) { build(:project) }

          before do
            allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
              .and_return({ project: project, namespace: nil, default_namespace_applied: false })
            allow(Ability).to receive(:allowed?).with(user, :admin_project, project).and_return(false)
          end

          it 'returns nil duo_settings_path' do
            expect(result[:duo_settings_path]).to be_nil
          end
        end

        context 'when user is not admin of the group container' do
          let(:group) { build(:group) }

          before do
            allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
              .and_return({ project: nil, namespace: group, default_namespace_applied: false })
            allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(false)
          end

          it 'returns nil duo_settings_path' do
            expect(result[:duo_settings_path]).to be_nil
          end
        end
      end
    end
  end
end
