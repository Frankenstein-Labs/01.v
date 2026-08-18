# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::StageCheck, feature_category: :ai_abstraction_layer do
  let(:feature_name) { :make_widgets }

  describe ".available?" do
    using RSpec::Parameterized::TableSyntax

    shared_examples 'expected stage check results' do
      it 'returns expected result' do
        expect(described_class.available?(container, feature_name)).to eq(result)
      end

      context 'for a project in a personal namespace' do
        let_it_be(:user) { create(:user) }
        let_it_be(:project) { create(:project, namespace: user.namespace) }

        it 'returns false' do
          expect(described_class.available?(project, feature_name)).to be(false)
        end
      end

      context 'with an invalid feature name' do
        it 'returns false' do
          expect(described_class.available?(container, :invalid_feature_name)).to be(false)
        end
      end

      context 'when not on a plan with ai_features licensed' do
        before do
          stub_licensed_features(ai_features: false)
        end

        it 'returns false' do
          expect(described_class.available?(container, feature_name)).to be(false)
        end
      end

      context 'with specific license features' do
        where(:specific_feature, :license_feature) do
          :chat                     | :ai_chat
          :ai_catalog               | :ai_catalog
          :ai_catalog_mcp_servers   | :ai_catalog
          :duo_workflow             | :ai_workflows
          :glab_ask_git_command     | :glab_ask_git_command
          :generate_commit_message  | :generate_commit_message
          :summarize_new_merge_request | :summarize_new_merge_request
          :summarize_review         | :summarize_review
          :generate_description     | :generate_description
          :summarize_comments       | :summarize_comments
          :review_merge_request     | :review_merge_request
        end

        with_them do
          let(:feature_name) { specific_feature }

          context 'when feature is not licensed' do
            before do
              stub_licensed_features(license_feature => false)
            end

            it 'returns false' do
              expect(described_class.available?(container, feature_name)).to be(false)
            end
          end
        end
      end
    end

    context 'when gitlab.com', :saas do
      let_it_be_with_reload(:root_group) { create(:group_with_plan, :private, plan: :premium_plan) }
      let_it_be(:group) { create(:group, :private, parent: root_group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }

      where(:container, :feature_type, :namespace_experiment_features_enabled, :result) do
        ref(:group)   | :experimental | true  | true
        ref(:group)   | :experimental | false | false
        ref(:group)   | :beta         | true  | true
        ref(:group)   | :beta         | false | false
        ref(:group)   | :ga           | true  | true
        ref(:group)   | :ga           | false | true
        ref(:project) | :experimental | true  | true
        ref(:project) | :experimental | false | false
        ref(:project) | :beta         | true  | true
        ref(:project) | :beta         | false | false
        ref(:project) | :ga           | true  | true
        ref(:project) | :ga           | false | true
      end

      with_them do
        before do
          stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", feature_name => { maturity: feature_type })
          stub_licensed_features(ai_features: true)
          stub_saas_features(gitlab_duo_saas_only: true)
          root_group.namespace_settings.update!(experiment_features_enabled: namespace_experiment_features_enabled)
          Gitlab::CurrentSettings.current_application_settings.update!(
            instance_level_ai_beta_features_enabled: true
          )
        end

        it_behaves_like 'expected stage check results'
      end
    end

    context 'when not gitlab.com' do
      let_it_be(:root_group) { create(:group, :private) }
      let_it_be(:group) { create(:group, :private, parent: root_group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }

      where(:container, :feature_type, :instance_experiment_features_enabled, :result) do
        ref(:group)   | :experimental | true  | true
        ref(:group)   | :experimental | false | false
        ref(:group)   | :beta         | true  | true
        ref(:group)   | :beta         | false | false
        ref(:group)   | :ga           | true  | true
        ref(:group)   | :ga           | false | true
        ref(:project) | :experimental | true  | true
        ref(:project) | :experimental | false | false
        ref(:project) | :beta         | true  | true
        ref(:project) | :beta         | false | false
        ref(:project) | :ga           | true  | true
        ref(:project) | :ga           | false | true
      end

      with_them do
        before do
          stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", feature_name => { maturity: feature_type })
          stub_licensed_features(ai_features: true)
          Gitlab::CurrentSettings.current_application_settings.update!(
            instance_level_ai_beta_features_enabled: instance_experiment_features_enabled
          )
        end

        it_behaves_like 'expected stage check results'
      end
    end

    context 'with free-tier namespace and active gitlab_credits add-on', :saas do
      let_it_be(:free_group) { create(:group) }
      let_it_be(:project) { create(:project, group: free_group) }

      before do
        stub_saas_features(gitlab_duo_saas_only: true)
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: free_group)
        stub_licensed_features(ai_catalog: false)
        stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", ai_catalog: { maturity: :ga })
      end

      it 'allows credits-eligible features without a paid license' do
        expect(described_class.available?(project, :ai_catalog)).to be(true)
      end

      it 'still blocks non-credits-eligible features without a paid license' do
        stub_licensed_features(generate_description: false)
        stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", generate_description: { maturity: :ga })

        expect(described_class.available?(project, :generate_description)).to be(false)
      end
    end

    context 'with free-tier self-managed instance and active gitlab_credits add-on' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }

      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: nil,
          organization: group.organization)
        stub_licensed_features(ai_catalog: false)
        stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", ai_catalog: { maturity: :ga })
      end

      it 'allows credits-eligible features without a paid license' do
        expect(described_class.available?(project, :ai_catalog)).to be(true)
      end

      it 'still blocks non-credits-eligible features without a paid license' do
        stub_licensed_features(generate_description: false)
        stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", generate_description: { maturity: :ga })

        expect(described_class.available?(project, :generate_description)).to be(false)
      end
    end

    describe '.credits_access?' do
      let_it_be(:group) { create(:group) }

      subject(:result) { described_class.send(:credits_access?, group, :ai_catalog) }

      before do
        stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", ai_catalog: { maturity: :ga })
      end

      context 'when SaaS with a namespace-level credits purchase', :saas do
        before do
          stub_saas_features(gitlab_duo_saas_only: true)
          create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: group)
        end

        it { is_expected.to be true }
      end

      context 'when self-managed with an instance-level credits purchase' do
        before do
          create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :self_managed,
            organization: group.organization)
        end

        it { is_expected.to be true }
      end

      context 'when feature is not credits-eligible' do
        subject(:result) { described_class.send(:credits_access?, group, :generate_description) }

        it { is_expected.to be false }
      end
    end

    context 'with agentic_chat feature' do
      let_it_be(:root_group) { create(:group, :private) }
      let_it_be(:project) { create(:project, group: root_group) }

      it 'considers agentic_chat as GA under SaaS', :saas do
        stub_licensed_features(agentic_chat: true)

        expect(described_class.available?(project, :agentic_chat)).to be(true)
      end

      it 'considers agentic_chat as GA under Self-Managed' do
        stub_licensed_features(agentic_chat: true)

        expect(described_class.available?(project, :agentic_chat)).to be(true)
      end
    end
  end
end
