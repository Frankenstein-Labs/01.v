# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ApplicationFlowDefinitions::CreateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:current_user) { create(:user) }

  let(:definition) { "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 0\n" }
  let(:params) { { definition: definition } }

  subject(:result) do
    described_class.new(parent: application, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'returns a success response with the persisted flow definition', :aggregate_failures do
      expect { result }.to change { ::Cd::ApplicationFlowDefinition.count }.by(1)

      flow_definition = result.payload[:application_flow_definition]
      expect(result).to be_success
      expect(flow_definition).to be_persisted
      expect(flow_definition).to have_attributes(
        application: application,
        organization: organization,
        version: 1
      )
      expect(flow_definition.definition).to eq(definition)
    end

    context 'when a flow definition already exists for the application' do
      before do
        create(:cd_application_flow_definition, application: application)
      end

      it 'assigns the next version' do
        expect(result).to be_success
        expect(result.payload[:application_flow_definition].version).to eq(2)
      end
    end

    context 'when definition is blank' do
      let(:definition) { '' }

      it 'does not create a flow definition and returns the error' do
        expect { result }.not_to change { ::Cd::ApplicationFlowDefinition.count }
        expect(result).to be_error
        expect(result.message).to include("Definition can't be blank")
      end
    end

    context 'when a concurrent create wins the version race' do
      before do
        allow_next_instance_of(::Cd::ApplicationFlowDefinition) do |instance|
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
          allow_next_instance_of(::Cd::ApplicationFlowDefinition) do |instance|
            allow(instance).to receive(:save) do
              instance.errors.add(:version, 'is invalid')
              raise ActiveRecord::RecordNotUnique
            end
          end
        end

        it 'does not add a duplicate version error' do
          expect(result).to be_error
          expect(result.payload[:application_flow_definition].errors[:version]).to contain_exactly('is invalid')
        end
      end
    end
  end
end
