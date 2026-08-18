# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::Dashboards::DashboardsResolver, feature_category: :product_analytics do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:result) { resolve(described_class, obj: project, ctx: { current_user: user }, args: { slug: slug }) }

    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:project) do
      create(:project, :with_product_analytics_dashboard, group: create(:group))
    end

    let(:slug) { nil }

    before do
      allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
      stub_licensed_features(product_analytics: true, project_level_analytics_dashboard: false,
        project_merge_request_analytics: false)
    end

    context 'when user has guest access' do
      before_all do
        project.add_guest(user)
      end

      it { is_expected.to be_nil }

      context 'when slug is provided' do
        let(:slug) { 'dashboard_example_1' }

        it { is_expected.to be_nil }
      end
    end

    context 'when user has developer access' do
      before_all do
        project.add_developer(user)
      end

      it 'returns all dashboards including hardcoded ones', :aggregate_failures do
        expect(result).to eq(project.product_analytics_dashboards(user))
        expect(result.size).to eq(1)
        expect(result.first.title).to eq("Dashboard Example 1")
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(product_analytics_features: false)
        end

        it 'contains only user defined dashboards' do
          expect(result.size).to eq(1)
        end
      end

      context 'when clickhouse is configured' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
        end

        context 'when namespace is not licensed to ai_analytics' do
          before do
            stub_licensed_features(ai_analytics: false)
          end

          it 'does not contain AI impact dashboard' do
            expect(result.map(&:slug)).not_to include(Analytics::Dashboards::Dashboard::AI_IMPACT_DASHBOARD_NAME)
          end
        end

        context 'when namespace is licensed to ai_analytics' do
          before do
            stub_licensed_features(ai_analytics: true)
          end

          it 'contains AI impact dashboard' do
            expect(result.map(&:slug)).to include(Analytics::Dashboards::Dashboard::AI_IMPACT_DASHBOARD_NAME)
          end
        end
      end

      context 'when slug matches existing dashboard' do
        context 'when it\'s a custom dashboard' do
          let(:slug) { 'dashboard_example_1' }

          it 'contains only one dashboard and it is the one with the matching slug' do
            expect(result.size).to eq(1)
            expect(result.first.slug).to eq(slug)
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(product_analytics_features: false)
            end

            it 'still returns the dashboard' do
              expect(result.size).to eq(1)
              expect(result.first.slug).to eq(slug)
            end
          end

          context 'when product analytics toggle is disabled' do
            before do
              project.group.root_ancestor.namespace_settings.update!(product_analytics_enabled: false)
            end

            it 'still returns the dashboard' do
              expect(result.size).to eq(1)
              expect(result.first.slug).to eq(slug)
            end
          end
        end
      end

      context 'when path does not match existing dashboard' do
        let(:slug) { 'not_a_real_dashboard' }

        it 'returns no dashboard' do
          expect(result).to be_empty
        end
      end
    end
  end
end
