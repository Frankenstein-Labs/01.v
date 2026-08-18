# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::DeleteProjectSubscriptionService, feature_category: :continuous_integration do
  describe '#execute' do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:upstream_project) { create(:project, :public) }
    let_it_be(:current_user) { create(:user) }
    let!(:subscription) do
      create(:ci_subscriptions_project, downstream_project: project, upstream_project: upstream_project)
    end

    subject(:result) do
      described_class.new(subscription: subscription, user: current_user).execute
    end

    before do
      stub_licensed_features(ci_project_subscriptions: true)
    end

    context 'when the user has permissions' do
      before_all do
        project.add_maintainer(current_user)
      end

      it 'returns a success response with the payload' do
        project = subject.payload
        expect(project).to eq(subscription.downstream_project)
      end

      it 'decreases the DB record by 1' do
        expect { subject }.to change { ::Ci::Subscriptions::Project.count }.by(-1)
      end

      context 'when the feature is locked' do
        before do
          stub_licensed_features(ci_project_subscriptions: false)
        end

        it 'returns a service error with the relevant message' do
          expect(result.payload).to eq({})
          expect(result.errors.first).to eq('Failed to delete subscription.')
          expect(result.reason).to eq('Feature unavailable for this project.')
        end

        it 'does not delete the record' do
          expect { subject }.to not_change { ::Ci::Subscriptions::Project.count }
        end
      end

      context 'when the subscription is null' do
        let(:subscription) { nil }

        it 'returns a service error with the relevant message' do
          result = subject
          expect(result.payload).to eq({})
          expect(result.errors.first).to eq('Failed to delete subscription.')
          expect(result.reason).to eq('Subscription does not exist.')
        end

        it 'does not delete the record' do
          expect { subject }.to not_change { ::Ci::Subscriptions::Project.count }
        end
      end

      context 'when an error occurs while persisting' do
        before do
          subscription.errors.add(:downstream_project, :some_error, message: 'An error occurred.')
          allow(subscription).to receive(:destroy) { subscription }
        end

        it 'returns the error message' do
          result = subject
          expect(result.message).to eq(['Downstream project An error occurred.'])
        end
      end
    end

    context 'when the user does not have permissions' do
      it 'returns a service error with the relevant message' do
        expect(result.payload).to eq({})
        expect(result.errors.first).to eq('Failed to delete subscription.')
        expect(result.reason).to eq('Feature unavailable for this project.')
      end

      it 'does not delete the record' do
        expect { subject }.to not_change { ::Ci::Subscriptions::Project.count }
      end
    end
  end
end
