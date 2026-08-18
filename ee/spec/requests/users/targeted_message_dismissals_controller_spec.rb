# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::TargetedMessageDismissalsController, :saas, type: :request, feature_category: :notifications do
  include SessionHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:targeted_message_namespace) { create(:targeted_message_namespace) }
  let(:targeted_message) { targeted_message_namespace.targeted_message }

  describe 'create' do
    let(:params) { { targeted_message_id: targeted_message.id, namespace_id: targeted_message_namespace.namespace.id } }

    subject(:dismiss) do
      post targeted_message_dismissals_path, params: params
    end

    context 'when signed in' do
      before do
        sign_in(user)
      end

      context 'with valid targeted message id' do
        context 'when dismissal entry does not exist' do
          it 'creates a dismissal entry' do
            expect { dismiss }.to change { Notifications::TargetedMessageDismissal.count }.by(1)
            expect(response).to have_gitlab_http_status(:created)
          end
        end

        context 'when dismissal already exists' do
          it 'responds unproccesable' do
            create(:targeted_message_dismissal, user: user, targeted_message: targeted_message,
              namespace: targeted_message_namespace.namespace)
            expect { dismiss }.not_to change { Notifications::TargetedMessageDismissal.count }
            expect(response).to have_gitlab_http_status(:unprocessable_entity)
          end
        end
      end

      context 'with invalid targeted message id and namespace id' do
        let(:params) { { targeted_message_id: -1, namespace_id: -1 } }

        it 'returns bad request' do
          dismiss
          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when signed out' do
      context 'with valid targeted message id' do
        it 'creates a dismissal entry' do
          dismiss
          expect(response).to have_gitlab_http_status(:redirect)
        end
      end
    end
  end
end
