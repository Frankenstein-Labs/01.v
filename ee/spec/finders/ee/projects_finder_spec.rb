# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsFinder, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  describe '#execute', :saas do
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:ultimate_project, freeze: false) { create_project(:ultimate_plan) }
    let_it_be(:ultimate_project2, freeze: false) { create_project(:ultimate_plan) }
    let_it_be(:premium_project, freeze: false) { create_project(:premium_plan) }
    let_it_be(:no_plan_project, freeze: false) { create_project(nil) }

    let(:current_user) { user }
    let(:project_ids_relation) { nil }
    let(:finder) { described_class.new(current_user:, params:, project_ids_relation:) }

    subject { finder.execute }

    describe 'filter by plans' do
      let(:params) { { plans: plans } }

      context 'with ultimate plan' do
        let(:plans) { ['ultimate'] }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2) }
      end

      context 'with multiple plans' do
        let(:plans) { %w[ultimate premium] }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project) }
      end

      context 'with other plans' do
        let(:plans) { ['bronze'] }

        it { is_expected.to be_empty }
      end

      context 'without plans' do
        let(:plans) { nil }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
      end

      context 'with empty plans' do
        let(:plans) { [] }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
      end
    end

    it_behaves_like 'projects finder with SAML session filtering' do
      let(:finder) { described_class.new(current_user: current_user, params: params) }
    end

    context 'filter by hidden' do
      let_it_be(:hidden_project, freeze: false) { create(:project, :public, :hidden) }

      context 'when include hidden is true' do
        let(:params) { { include_hidden: true } }

        it do
          is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project,
            hidden_project)
        end
      end

      context 'when include hidden is false' do
        let(:params) { { include_hidden: false } }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
      end
    end

    context 'filter by feature available' do
      let_it_be(:private_premium_project, freeze: false) { create_project(:premium_plan, :private) }

      before_all do
        private_premium_project.add_owner(user)
      end

      context 'when feature_available filter is used' do
        # `product_analytics` is a feature available in Ultimate tier only
        let(:params) { { feature_available: 'product_analytics' } }

        it do
          is_expected.to contain_exactly(
            ultimate_project,
            ultimate_project2,
            premium_project,
            no_plan_project
          )
        end
      end

      context 'when feature_available filter is not used' do
        let(:params) { {} }

        it do
          is_expected.to contain_exactly(
            ultimate_project,
            ultimate_project2,
            premium_project,
            no_plan_project,
            private_premium_project
          )
        end
      end
    end

    context 'when filtering by duo_licensed_feature' do
      let_it_be_with_reload(:ns_ultimate) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be_with_reload(:ns_premium) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be_with_reload(:ns_free) { create(:group_with_plan, plan: :free_plan) }

      let_it_be_with_reload(:p_ultimate_duo_on) { create(:project, namespace: ns_ultimate) }
      let_it_be_with_reload(:p_ultimate_duo_off) { create(:project, namespace: ns_ultimate) }
      let_it_be_with_reload(:p_premium_duo_on) { create(:project, namespace: ns_premium) }
      let_it_be_with_reload(:p_free_duo_on) { create(:project, namespace: ns_free) }
      let_it_be_with_reload(:p_free_duo_off) { create(:project, namespace: ns_free) }

      let(:params) { { duo_licensed_feature: :agentic_chat } }

      before_all do
        [p_ultimate_duo_on, p_premium_duo_on, p_free_duo_on].each do |p|
          p.project_setting.update!(duo_features_enabled: true)
        end

        [p_ultimate_duo_off, p_free_duo_off].each do |p|
          p.project_setting.update!(duo_features_enabled: false)
        end

        [ns_ultimate, ns_free].each { |ns| ns.add_maintainer(user) }

        ns_premium.add_developer(user)
      end

      context 'when duo_licensed_feature param is blank' do
        let(:params) { { duo_licensed_feature: nil } }

        it 'returns all visible projects without duo filtering' do
          is_expected.to include(p_ultimate_duo_on, p_ultimate_duo_off, p_premium_duo_on, p_free_duo_on, p_free_duo_off)
        end
      end

      context 'when current_user is nil' do
        let(:current_user) { nil }

        it 'returns no projects' do
          is_expected.to be_empty
        end
      end

      context 'when current_user is an admin', :enable_admin_mode do
        let(:current_user) { create(:admin) }

        it 'returns all eligible projects for duo_licensed_feature' do
          is_expected.to include(p_ultimate_duo_on, p_premium_duo_on)
        end
      end

      context 'when current_user is an auditor' do
        let(:current_user) { create(:user, :auditor) }

        it 'returns all eligible projects for duo_licensed_feature' do
          is_expected.to include(p_ultimate_duo_on, p_premium_duo_on)
        end
      end

      context 'when feature is plan-based' do
        let(:params) { { duo_licensed_feature: :ai_features } }

        it 'returns eligible projects under namespaces with qualifying plans' do
          is_expected.to contain_exactly(p_ultimate_duo_on)
        end
      end

      context 'when feature is credits-eligible' do
        let_it_be(:credits_purchase, freeze: false) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: ns_free)
        end

        it 'includes projects under namespaces with purchased credits' do
          is_expected.to contain_exactly(p_ultimate_duo_on, p_free_duo_on)
        end
      end

      context 'when project is under a personal namespace' do
        let_it_be(:ns_personal, freeze: false) { create(:namespace) }
        let_it_be(:p_personal_duo_on, freeze: false) { create(:project, namespace: ns_personal) }

        let(:current_user) { ns_personal.owner }

        before_all do
          p_personal_duo_on.project_setting.update!(duo_features_enabled: true)
          create(:gitlab_subscription, namespace: ns_personal)
        end

        it 'excludes personal namespace projects even with an ultimate subscription' do
          is_expected.not_to include(p_personal_duo_on)
        end
      end

      context 'on Self-Managed' do
        before do
          stub_saas_features(gitlab_duo_saas_only: false)
        end

        context 'when feature is not available via instance license' do
          before do
            stub_licensed_features(agentic_chat: false)
          end

          it 'returns no projects' do
            is_expected.to be_empty
          end
        end

        context 'when feature is available via instance license' do
          before do
            stub_licensed_features(agentic_chat: true)
          end

          it 'returns all eligible projects for duo_licensed_feature' do
            is_expected.to contain_exactly(p_ultimate_duo_on, p_free_duo_on)
          end
        end

        context 'when project is under a personal namespace' do
          let_it_be(:ns_personal, freeze: false) { create(:namespace) }
          let_it_be(:p_personal_duo_on, freeze: false) { create(:project, namespace: ns_personal) }

          let(:current_user) { ns_personal.owner }

          before_all do
            p_personal_duo_on.project_setting.update!(duo_features_enabled: true)
          end

          before do
            stub_licensed_features(agentic_chat: true)
          end

          it 'excludes personal namespace projects' do
            is_expected.not_to include(p_personal_duo_on)
          end
        end
      end
    end

    private

    def create_project(plan, visibility = :public)
      create(:project, visibility, namespace: create(:group_with_plan, plan: plan))
    end
  end
end
