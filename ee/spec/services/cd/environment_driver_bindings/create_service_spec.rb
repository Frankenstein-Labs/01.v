# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::EnvironmentDriverBindings::CreateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { driver_ref: 'argo-rollouts', driver_config: { 'cluster_agent_id' => '1' } } }

  subject(:result) do
    described_class.new(parent: environment, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'returns a success response with the persisted driver binding', :aggregate_failures do
      expect { result }.to change { ::Cd::EnvironmentDriverBinding.count }.by(1)

      binding = result.payload[:environment_driver_binding]
      expect(result).to be_success
      expect(binding).to be_persisted
      expect(binding).to have_attributes(
        environment: environment,
        organization: organization,
        version: 1,
        driver_ref: 'argo-rollouts',
        driver_config: { 'cluster_agent_id' => '1' }
      )
    end

    context 'when a binding already exists for the environment' do
      before do
        create(:cd_environment_driver_binding, environment: environment)
      end

      it 'assigns the next version' do
        expect(result).to be_success
        expect(result.payload[:environment_driver_binding].version).to eq(2)
      end
    end

    context 'when driver_ref is blank' do
      let(:params) { super().merge(driver_ref: '') }

      it 'does not create a driver binding and returns the error' do
        expect { result }.not_to change { ::Cd::EnvironmentDriverBinding.count }
        expect(result).to be_error
        expect(result.message).to include("Driver ref can't be blank")
      end
    end

    context 'when a concurrent create wins the version race' do
      before do
        allow_next_instance_of(::Cd::EnvironmentDriverBinding) do |instance|
          allow(instance).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
        end
      end

      it 'returns a structured error instead of raising' do
        expect { result }.not_to raise_error
        expect(result).to be_error
        expect(result.message).to include('Version has already been taken')
      end

      context 'when a version error is already present' do
        before do
          allow_next_instance_of(::Cd::EnvironmentDriverBinding) do |instance|
            allow(instance).to receive(:save) do
              instance.errors.add(:version, 'is invalid')
              raise ActiveRecord::RecordNotUnique
            end
          end
        end

        it 'does not add a duplicate version error' do
          expect(result).to be_error
          expect(result.payload[:environment_driver_binding].errors[:version]).to contain_exactly('is invalid')
        end
      end
    end
  end
end
