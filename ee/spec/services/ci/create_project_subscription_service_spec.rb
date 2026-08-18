# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreateProjectSubscriptionService, feature_category: :continuous_integration do
  describe '#execute' do
    let_it_be_with_reload(:project) { create(:project, :public) }
    let_it_be(:upstream_project) { create(:project, :public) }
    let_it_be(:current_user) { create(:user) }
    let(:success_response) { ServiceResponse.success }

    subject(:execute) do
      described_class.new(project: project,
        upstream_project: upstream_project,
        user: current_user).execute
    end

    before do
      stub_licensed_features(ci_project_subscriptions: true)
    end

    context 'when the user has the required permissions' do
      before_all do
        upstream_project.add_developer(current_user)
        project.add_maintainer(current_user)
      end

      it 'returns a success response with the payload' do
        subscription = execute.payload[:subscription]
        expect(subscription.downstream_project).to eq(project)
        expect(subscription.upstream_project).to eq(upstream_project)
      end

      it 'increases the DB record by 1' do
        expect { execute }.to change { ::Ci::Subscriptions::Project.count }.by(1)
      end

      context 'when the feature is locked' do
        before do
          stub_licensed_features(ci_project_subscriptions: false)
        end

        it 'returns a service error with the relevant message' do
          result = execute
          expect(result.payload).to eq({})
          expect(result.errors.first).to eq('Feature unavailable for this user.')
        end

        it 'does not create a new record' do
          expect { execute }.not_to change { ::Ci::Subscriptions::Project.count }
        end
      end

      context 'when the upstream project is taken' do
        before do
          create(:ci_subscriptions_project, downstream_project: project, upstream_project: upstream_project)
        end

        it 'returns a service error with the relevant message' do
          result = execute
          expect(result.payload).to eq({})
          expect(result.errors.first).to eq('Upstream project has already been taken')
        end

        it 'does not create a new record' do
          expect { execute }.not_to change { ::Ci::Subscriptions::Project.count }
        end
      end
    end

    context 'when the user does not have the developer role to the upstream project' do
      before_all do
        project.add_maintainer(current_user)
      end

      it 'returns a service error with the relevant message' do
        result = execute
        expect(result.payload).to eq({})
        expect(result.errors.first).to eq('Feature unavailable for this user.')
      end

      it 'does not create a new record' do
        expect { execute }.not_to change { ::Ci::Subscriptions::Project.count }
      end
    end

    context 'when the user does not have the admin_project role to the downstream project' do
      before_all do
        upstream_project.add_developer(current_user)
      end

      it 'returns a service error with the relevant message' do
        result = execute
        expect(result.payload).to eq({})
        expect(result.errors.first).to eq('Feature unavailable for this user.')
      end

      it 'does not create a new record' do
        expect { execute }.not_to change { ::Ci::Subscriptions::Project.count }
      end
    end
  end
end
