# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::WorkItems::SavedViews::Subscribe, feature_category: :planning_views do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, planner_of: [project]) }
  let_it_be(:saved_view) { create(:saved_view, namespace: project.project_namespace) }

  let(:current_ctx) { { current_user: current_user } }

  def resolve_mutation(**args)
    resolve(described_class, args: args, ctx: current_ctx)
  end

  describe '#resolve' do
    context 'when the subscription limit is reached' do
      before do
        stub_licensed_features(increased_saved_views_limit: true)

        namespace = project.project_namespace
        limit = WorkItems::SavedViews::UserSavedView.user_saved_view_limit(namespace)
        create_list(:saved_view, limit, namespace: namespace).each do |sv|
          create(:user_saved_view, user: current_user, saved_view: sv, namespace: namespace)
        end
      end

      it 'returns an error' do
        result = resolve_mutation(id: saved_view.to_global_id)

        expect(result[:saved_view]).to be_nil
        expect(result[:errors]).to eq(['Subscribed saved view limit exceeded.'])
      end

      it 'does not create a new subscription' do
        expect { resolve_mutation(id: saved_view.to_global_id) }
          .not_to change { WorkItems::SavedViews::UserSavedView.count }
      end
    end
  end
end
