# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::AddOns,
  feature_category: :'add-on_provisioning' do
  let(:duo_exclusive_class) do
    GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::DuoExclusive
  end

  let(:self_hosted_dap_class) do
    GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::SelfHostedDap
  end

  let(:duo_core_class) do
    GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::DuoCore
  end

  let(:gitlab_credits_class) do
    GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::GitlabCredits
  end

  let(:secrets_manager_class) do
    GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::SecretsManager
  end

  describe '::PROVISION_SERVICES' do
    it 'includes the defined add-on provision services' do
      expect(described_class::PROVISION_SERVICES).to match_array(
        [duo_exclusive_class, self_hosted_dap_class, duo_core_class, gitlab_credits_class, secrets_manager_class]
      )
    end
  end

  describe '#execute' do
    subject(:add_ons_service) { described_class.new }

    let(:add_ons_service_classes) do
      [
        duo_exclusive_class,
        self_hosted_dap_class,
        duo_core_class,
        gitlab_credits_class,
        secrets_manager_class
      ]
    end

    context 'when all Duo provision service responses are the same status' do
      let!(:add_ons_services) do
        add_ons_service_classes.map do |service_class|
          instance_double(service_class).tap do |service|
            allow(service_class).to receive(:new).and_return(service)
            allow(service).to receive(:execute).and_return(service_response)
          end
        end
      end

      context 'when all services succeed' do
        let_it_be(:add_on_purchase) do
          build_stubbed(:gitlab_subscription_add_on_purchase)
        end

        let(:service_response) do
          successful_service_response(add_on_purchase)
        end

        it 'returns success response', :aggregate_failures do
          result = add_ons_service.execute

          expect(add_ons_services).to all(have_received(:execute))
          expect(result.message).to eq('Successfully processed add-ons')
          expect(result.payload).to eq({ add_on_purchases: [add_on_purchase] * add_ons_service_classes.count })
        end
      end

      context 'when all services fail' do
        let(:error_message) { 'an error message' }

        let(:service_response) do
          ServiceResponse.error(message: error_message)
        end

        it 'returns error response', :aggregate_failures do
          result = add_ons_service.execute

          expect(add_ons_services).to all(have_received(:execute))
          expect(result.payload).to eq({ add_on_purchases: [] })
          expect(result.message).to eq(
            "Error processing one or more add-ons: #{([error_message] * add_ons_service_classes.count).join(', ')}"
          )
        end
      end
    end

    context 'when Duo provision services return mixed status responses' do
      let_it_be(:duo_pro_add_on) do
        build_stubbed(:gitlab_subscription_add_on_purchase, :duo_pro)
      end

      let_it_be(:duo_core_add_on) do
        build_stubbed(:gitlab_subscription_add_on_purchase, :duo_core)
      end

      let_it_be(:secrets_manager_add_on) do
        build_stubbed(:gitlab_subscription_add_on_purchase, :secrets_manager)
      end

      let(:duo_exclusive_instance) { instance_double(duo_exclusive_class) }
      let(:self_hosted_dap_instance) { instance_double(self_hosted_dap_class) }
      let(:duo_core_instance) { instance_double(duo_core_class) }
      let(:secrets_manager_instance) { instance_double(secrets_manager_class) }

      before do
        allow(duo_exclusive_class).to receive(:new).and_return(duo_exclusive_instance)
        allow(self_hosted_dap_class).to receive(:new).and_return(self_hosted_dap_instance)
        allow(duo_core_class).to receive(:new).and_return(duo_core_instance)
        allow(secrets_manager_class).to receive(:new).and_return(secrets_manager_instance)
      end

      context 'when some service responses do not contain an add-on purchase' do
        let_it_be(:self_hosted_dap_add_on) { nil }

        before do
          allow(duo_exclusive_instance).to receive(:execute)
            .and_return(successful_service_response(duo_pro_add_on))

          allow(self_hosted_dap_instance).to receive(:execute)
            .and_return(successful_service_response(self_hosted_dap_add_on))

          allow(duo_core_instance).to receive(:execute)
            .and_return(successful_service_response(duo_core_add_on))

          allow(secrets_manager_instance).to receive(:execute)
            .and_return(successful_service_response(secrets_manager_add_on))
        end

        it 'returns success response with only the available add-on purchases', :aggregate_failures do
          result = add_ons_service.execute

          expect(result.message).to eq('Successfully processed add-ons')
          expect(result.payload).to eq(
            { add_on_purchases: [duo_pro_add_on, duo_core_add_on, secrets_manager_add_on] }
          )
        end
      end

      context 'when some service responses are successful and others return errors' do
        before do
          allow(duo_exclusive_instance).to receive(:execute)
            .and_return(successful_service_response(duo_pro_add_on))

          allow(self_hosted_dap_instance).to receive(:execute)
            .and_return(ServiceResponse.error(message: 'an error message'))

          allow(duo_core_instance).to receive(:execute)
            .and_return(successful_service_response(duo_core_add_on))

          allow(secrets_manager_instance).to receive(:execute)
            .and_return(successful_service_response(secrets_manager_add_on))
        end

        it 'returns an error response', :aggregate_failures do
          result = add_ons_service.execute

          expect(result.message).to eq(
            'Error processing one or more add-ons: an error message'
          )

          expect(result.payload).to eq(
            { add_on_purchases: [duo_pro_add_on, duo_core_add_on, secrets_manager_add_on] }
          )
        end
      end

      context 'when a service response has no payload' do
        before do
          allow(duo_exclusive_instance).to receive(:execute)
            .and_return(successful_service_response(duo_pro_add_on))

          allow(self_hosted_dap_instance).to receive(:execute)
            .and_return(ServiceResponse.success(payload: nil))

          allow(duo_core_instance).to receive(:execute)
            .and_return(successful_service_response(duo_core_add_on))

          allow(secrets_manager_instance).to receive(:execute)
            .and_return(successful_service_response(secrets_manager_add_on))
        end

        it 'returns success response skipping the nil payload', :aggregate_failures do
          result = add_ons_service.execute

          expect(result.message).to eq('Successfully processed add-ons')
          expect(result.payload).to eq(
            { add_on_purchases: [duo_pro_add_on, duo_core_add_on, secrets_manager_add_on] }
          )
        end
      end
    end
  end

  private

  def successful_service_response(add_on_purchase)
    ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
  end
end
