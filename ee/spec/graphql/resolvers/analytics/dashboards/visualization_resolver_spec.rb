# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::Dashboards::VisualizationResolver, feature_category: :product_analytics do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:resolved_visualization) do
      resolve(
        described_class, obj: project.product_analytics_dashboards(user).first.panels.first, ctx: { current_user: user }
      )
    end

    before do
      stub_licensed_features(product_analytics: true)
    end

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :with_product_analytics_dashboard) }

    context 'when user does not have access' do
      before_all do
        project.add_guest(user)
      end

      it 'returns nil' do
        expect(resolved_visualization).to be_nil
      end
    end

    context 'when user has access' do
      before_all do
        project.add_developer(user)
      end

      it 'returns the visualization object' do
        expect(resolved_visualization).to be_a(Analytics::Dashboards::Visualization)
      end

      context 'when the visualization does not exist' do
        before do
          allow_next_instance_of(Analytics::Dashboards::Panel) do |panel|
            allow(panel).to receive(:visualization).and_return(nil)
          end
        end

        it 'returns nil' do
          expect(resolved_visualization).to be_nil
        end
      end
    end
  end
end
