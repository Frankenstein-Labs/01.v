# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::EnableCodeReviewFlowService, feature_category: :duo_code_review do
  let_it_be(:owner) { create(:user) }
  let_it_be_with_reload(:namespace) { create(:group, creator: owner) }

  subject(:result) { described_class.new(namespace: namespace).execute }

  before_all do
    namespace.add_owner(owner)
  end

  before do
    allow(namespace).to receive_messages(
      root?: true,
      duo_features_enabled: true,
      duo_agent_platform_enabled: true,
      duo_foundational_flows_enabled: true
    )
  end

  shared_examples 'does not enable the flow' do
    it 'returns an error' do
      expect(result).to be_error
      expect(result.message).to eq('Cannot enable the Code Review flow for this namespace')
    end

    it 'does not enable the Code Review flow' do
      expect(::Ai::Catalog::Flows::SeedFoundationalFlowsService).not_to receive(:new)
      expect(::Namespaces::CascadeDuoSettingsWorker).not_to receive(:perform_async)

      result
    end
  end

  describe '#execute' do
    context 'when the namespace is not a root namespace' do
      before do
        allow(namespace).to receive(:root?).and_return(false)
      end

      it_behaves_like 'does not enable the flow'
    end

    context 'when duo_features_enabled is false' do
      before do
        allow(namespace).to receive(:duo_features_enabled).and_return(false)
      end

      it_behaves_like 'does not enable the flow'
    end

    context 'when duo_agent_platform_enabled is false' do
      before do
        allow(namespace).to receive(:duo_agent_platform_enabled).and_return(false)
      end

      it_behaves_like 'does not enable the flow'
    end

    context 'when duo_foundational_flows_enabled is false' do
      before do
        allow(namespace).to receive(:duo_foundational_flows_enabled).and_return(false)
      end

      it_behaves_like 'does not enable the flow'
    end

    context 'when enable_duo_code_review_by_default is not pending' do
      before do
        namespace.namespace_settings.enable_duo_code_review_by_default_never!
      end

      it 'returns success without enabling the flow' do
        expect(Ai::Catalog::Flows::SeedFoundationalFlowsService).not_to receive(:new)

        expect(result).to be_success
      end
    end

    context 'when enable_duo_code_review_by_default is pending' do
      before do
        namespace.namespace_settings.enable_duo_code_review_by_default_pending!
      end

      context 'when all steps succeed' do
        it 'seeds foundational flows for the namespace organization' do
          expect_next_instance_of(
            Ai::Catalog::Flows::SeedFoundationalFlowsService,
            organization: namespace.organization
          ) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          result
        end

        it 'enables the Duo Code Review foundational flow' do
          expect { result }
            .to change { ::Ai::Catalog::EnabledFoundationalFlow.count }.by(1)

          enabled_flow = ::Ai::Catalog::EnabledFoundationalFlow.last
          expect(enabled_flow.namespace).to eq(namespace)
          expect(enabled_flow.catalog_item).to have_attributes(foundational_flow_reference: 'code_review/v1')
        end

        it 'enables automatic Duo Code Review' do
          expect { result }
            .to change { namespace.reload.namespace_settings.auto_duo_code_review_enabled }
            .to(true)
        end

        it 'clears the pending flag' do
          expect { result }
            .to change { namespace.namespace_settings.reload.enable_duo_code_review_by_default }
            .from('pending')
            .to('enabled')
        end
      end

      context 'when an unexpected error is raised' do
        before do
          allow_next_instance_of(Ai::Catalog::Flows::SeedFoundationalFlowsService) do |service|
            allow(service).to receive(:execute).and_raise(RuntimeError, 'Unexpected error')
          end
        end

        it 'tracks the exception' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            an_instance_of(RuntimeError),
            namespace_id: namespace.id
          )

          result
        end

        it 'returns error with the exception message' do
          expect(result).to be_error
          expect(result.message).to eq('Unexpected error')
        end
      end
    end
  end
end
