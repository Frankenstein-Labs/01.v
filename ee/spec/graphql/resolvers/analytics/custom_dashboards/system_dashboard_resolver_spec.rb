# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::CustomDashboards::SystemDashboardResolver, feature_category: :custom_dashboards_foundation do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }

  let(:slug) { 'merge_requests' }
  let(:args) { { slug: slug } }
  let(:current_user) { user }
  let(:dashboard) do
    Analytics::CustomDashboards::SystemDashboard.new(
      slug: slug,
      config: { 'title' => 'Merge requests', 'version' => '2', 'panels' => [] }
    )
  end

  subject(:resolved_dashboard) do
    sync(resolve(described_class, args: args, ctx: { current_user: current_user }))
  end

  before do
    allow(Analytics::CustomDashboards::SystemDashboardsLoader).to receive(:find_by_slug)
      .with(slug).and_return(dashboard)
  end

  describe '#resolve' do
    context 'when the user is authenticated' do
      it 'returns the matching system dashboard' do
        expect(resolved_dashboard).to eq(dashboard)
      end

      context 'when no dashboard matches the slug' do
        let(:dashboard) { nil }

        it 'returns nil' do
          expect(resolved_dashboard).to be_nil
        end
      end
    end

    context 'when the user is unauthenticated' do
      let(:current_user) { nil }

      it 'creates a resource-not-available graphql error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolved_dashboard
        end
      end

      context 'when no dashboard matches the slug' do
        let(:dashboard) { nil }

        it 'returns nil without checking authorization' do
          expect(resolved_dashboard).to be_nil
        end
      end
    end
  end
end
