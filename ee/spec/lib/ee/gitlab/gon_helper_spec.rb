# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::GonHelper do
  let(:helper) do
    Class.new do
      include Gitlab::GonHelper

      def current_user
        nil
      end
    end.new
  end

  describe '#add_gon_variables' do
    shared_examples 'pushes frontend feature flag' do |flag_name|
      it "pushes #{flag_name} feature flag" do
        allow(helper).to receive(:push_frontend_feature_flag)

        helper.add_gon_variables

        expect(helper).to have_received(:push_frontend_feature_flag)
                            .with(flag_name, helper.current_user)
      end
    end

    let(:gon) { double('gon').as_null_object }

    before do
      allow(helper).to receive(:gon).and_return(gon)
      allow(helper).to receive(:push_to_gon_attributes).and_return(nil)
      allow(helper).to receive(:current_user).and_return(create(:user))
    end

    it 'includes ee exclusive settings' do
      expect(gon).to receive(:roadmap_epics_limit=).with(1000)

      helper.add_gon_variables
    end

    it 'adds AI gon attributes' do
      ai_chat = {
        total_model_token: ::Llm::ExplainCodeService::TOTAL_MODEL_TOKEN_LIMIT,
        max_response_token: ::Llm::ExplainCodeService::MAX_RESPONSE_TOKENS,
        input_content_limit: ::Llm::ExplainCodeService::INPUT_CONTENT_LIMIT
      }
      helper.add_gon_variables

      expect(helper).to have_received(:push_to_gon_attributes).with('ai', 'chat', ai_chat)
    end

    context 'when not on GitLab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      it_behaves_like 'pushes frontend feature flag', :advanced_context_resolver
      it_behaves_like 'pushes frontend feature flag', :duo_chat_clarification_question_tool
      it_behaves_like 'pushes frontend feature flag', :no_duo_classic_for_duo_core_users

      it 'includes url to CustomersDot' do
        expect(gon).to receive(:subscriptions_url=).with(::Gitlab::Routing.url_helpers.subscription_portal_url)

        helper.add_gon_variables
      end
    end

    context 'when GitLab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
      end

      it_behaves_like 'pushes frontend feature flag', :advanced_context_resolver
      it_behaves_like 'pushes frontend feature flag', :duo_chat_clarification_question_tool
      it_behaves_like 'pushes frontend feature flag', :no_duo_classic_for_duo_core_users

      it 'includes CustomersDot variables' do
        expect(gon).to receive(:subscriptions_url=).with(::Gitlab::Routing.url_helpers.subscription_portal_url)
        expect(gon).to receive(:subscriptions_legacy_sign_in_url=).with(::Gitlab::Routing.url_helpers.subscription_portal_legacy_sign_in_url)
        expect(gon).to receive(:billing_accounts_url=).with(::Gitlab::Routing.url_helpers.subscription_portal_billing_accounts_url)

        helper.add_gon_variables
      end

      describe 'gon.is_gitlab_team_member' do
        it 'is true when current_user is in the gitlab-com group' do
          allow(::Gitlab::Com).to receive(:gitlab_com_group_member?).with(helper.current_user).and_return(true)
          expect(gon).to receive(:is_gitlab_team_member=).with(true)

          helper.add_gon_variables
        end

        it 'is false when current_user is not in the gitlab-com group' do
          allow(::Gitlab::Com).to receive(:gitlab_com_group_member?).with(helper.current_user).and_return(false)
          expect(gon).to receive(:is_gitlab_team_member=).with(false)

          helper.add_gon_variables
        end

        it 'is false when current_user is not signed in' do
          allow(helper).to receive(:current_user).and_return(nil)
          expect(gon).to receive(:is_gitlab_team_member=).with(false)

          helper.add_gon_variables
        end
      end
    end

    # Exercised through #push_frontend_feature_flags rather than the full
    # #add_gon_variables so the assertions do not depend on the Vite manifest.
    describe 'Orbit frontend feature flags', feature_category: :knowledge_graph do
      let(:orbit_flags) { %i[orbit_user_preference knowledge_graph orbit_foundational_agent] }

      before do
        allow(helper).to receive(:push_frontend_feature_flag)
      end

      context 'when the Knowledge Graph service is configured' do
        before do
          stub_config(knowledge_graph: { 'enabled' => true })
        end

        it 'pushes the Orbit feature flags to the frontend' do
          helper.push_frontend_feature_flags

          expect(helper).to have_received(:push_frontend_feature_flag)
                              .with(:orbit_user_preference, helper.current_user, type: :beta)
          expect(helper).to have_received(:push_frontend_feature_flag).with(:knowledge_graph, helper.current_user)
          expect(helper).to have_received(:push_frontend_feature_flag)
                              .with(:orbit_foundational_agent, helper.current_user)
        end
      end

      context 'when the Knowledge Graph service is not configured' do
        before do
          stub_config(knowledge_graph: { 'enabled' => false })
        end

        it 'does not push any Orbit feature flags to the frontend' do
          helper.push_frontend_feature_flags

          orbit_flags.each do |flag|
            expect(helper).not_to have_received(:push_frontend_feature_flag).with(flag, any_args)
          end
        end
      end
    end
  end

  describe '#push_licensed_feature' do
    let_it_be(:feature) { GitlabSubscriptions::Features::ALL_FEATURES.first }

    shared_examples 'sets the licensed features flag' do
      it 'pushes the licensed feature flag to the frontend' do
        gon = class_double('Gon')
        stub_licensed_features(feature => true)

        allow(helper)
          .to receive(:gon)
          .and_return(gon)

        expect(gon)
          .to receive(:push)
          .with({ licensed_features: { feature.to_s.camelize(:lower) => true } }, true)

        subject
      end
    end

    context 'no obj given' do
      subject { helper.push_licensed_feature(feature) }

      before do
        expect(License).to receive(:feature_available?).with(feature)
      end

      it_behaves_like 'sets the licensed features flag'

      context 'with feature from registration features' do
        let(:feature) { :password_complexity }

        before do
          stub_licensed_features(feature => false)
          stub_application_setting(usage_ping_features_enabled: true)
        end

        it_behaves_like 'sets the licensed features flag'
      end
    end

    context 'obj given' do
      let(:project) { create(:project) }

      subject { helper.push_licensed_feature(feature, project) }

      before do
        expect(project).to receive(:feature_available?).with(feature).and_call_original
      end

      it_behaves_like 'sets the licensed features flag'
    end
  end

  describe '#push_saas_feature' do
    let_it_be(:feature) { ::Gitlab::Saas::FEATURES.first }

    it 'pushes the SaaS feature to the frontend' do
      gon = class_double('Gon')
      stub_saas_features(feature => true)

      allow(helper)
        .to receive(:gon)
        .and_return(gon)

      expect(gon)
        .to receive(:push)
        .with({ saas_features: { feature.to_s.camelize(:lower) => true } }, true)

      helper.push_saas_feature(feature)
    end
  end

  describe '#push_dedicated_feature' do
    let_it_be(:feature) { ::Gitlab::Dedicated::FEATURES.first }

    it 'pushes the Dedicated feature to the frontend' do
      gon = class_double('Gon')
      allow(::Gitlab::Dedicated).to receive(:feature_available?).with(feature).and_return(true)

      allow(helper)
        .to receive(:gon)
        .and_return(gon)

      expect(gon)
        .to receive(:push)
        .with({ dedicated_features: { feature.to_s.camelize(:lower) => true } }, true)

      helper.push_dedicated_feature(feature)
    end
  end
end
