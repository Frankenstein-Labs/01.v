# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_examples'

RSpec.describe Ai::ActiveContext::Tasks::SyncFeatureSettings, feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let(:model_ref) { 'text_embedding_005_vertex' }
  let(:model_type) { 'gitlab_managed' }
  let(:default_params) do
    {
      'collection' => 'code',
      'metadata' => {
        'model_type' => model_type,
        'model_ref' => model_ref,
        'field' => 'embeddings_v1',
        'dimensions' => 1024
      },
      'user_id' => user.id
    }
  end

  it_behaves_like 'an active context task' do
    let(:required_params) { default_params }
  end

  describe '#execute!' do
    let(:task_record) { build(:ai_active_context_task, params: params) }
    let(:task) { described_class.new(task_record) }
    let(:params) { default_params }
    let(:service_double) { instance_double(Ai::ModelSelection::UpdateSelfManagedModelSelectionService) }
    let(:service_result) { ServiceResponse.success }
    let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, info: nil) }

    before do
      allow(Ai::ModelSelection::UpdateSelfManagedModelSelectionService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:execute).and_return(service_result)
      allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
    end

    context 'when given user exists' do
      context 'with gitlab_managed model' do
        let(:model_type) { 'gitlab_managed' }

        it 'syncs to feature settings with vendored provider and model ref' do
          task.execute!

          expect(Ai::ModelSelection::UpdateSelfManagedModelSelectionService).to have_received(:new).with(
            user,
            {
              feature: 'embeddings_code',
              provider: 'vendored',
              offered_model_ref: model_ref
            }
          )
        end

        context 'when service returns an error' do
          let(:service_result) { ServiceResponse.error(message: 'Something went wrong') }

          it 'raises TaskError' do
            expect { task.execute! }.to raise_error(
              ::ActiveContext::Task::V1_0::TaskError, 'Something went wrong'
            )
          end
        end
      end

      context 'with self_hosted model' do
        let_it_be(:self_hosted_model) { create(:ai_self_hosted_model, :embedding) }
        let(:model_type) { 'self_hosted' }
        let(:model_ref) { self_hosted_model.id.to_s }

        it 'syncs to feature settings with self_hosted provider and model id' do
          task.execute!

          expect(Ai::ModelSelection::UpdateSelfManagedModelSelectionService).to have_received(:new).with(
            user,
            {
              feature: 'embeddings_code',
              provider: 'self_hosted',
              ai_self_hosted_model_id: self_hosted_model.id
            }
          )
        end

        context 'when service returns an error' do
          let(:service_result) { ServiceResponse.error(message: 'Something went wrong') }

          it 'raises TaskError' do
            expect { task.execute! }.to raise_error(
              ::ActiveContext::Task::V1_0::TaskError, 'Something went wrong'
            )
          end
        end
      end
    end

    context 'when given user is not found' do
      let(:params) { default_params.merge('user_id' => non_existing_record_id) }

      it 'does not raise an error but does not sync', :aggregate_failures do
        expect(logger).to receive(:info).with({
          'class' => 'Ai::ActiveContext::Tasks::SyncFeatureSettings',
          'message' => 'Skipping feature settings sync',
          'reason' => 'user not found',
          'collection' => 'code',
          'user_id' => non_existing_record_id
        })

        expect { task.execute! }.not_to raise_error
        expect(Ai::ModelSelection::UpdateSelfManagedModelSelectionService).not_to have_received(:new)
      end
    end
  end
end
