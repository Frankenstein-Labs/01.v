# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::Create,
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: create(:compliance_framework, namespace: namespace))
  end

  let(:params) { valid_params }
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  subject(:mutate) { mutation.resolve(**params) }

  describe '#resolve' do
    shared_examples 'resource not available' do
      it 'raises error' do
        expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'when current_user is not group namespace owner' do
      it_behaves_like 'resource not available'
    end

    context 'when current_user is group owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      context 'when all arguments are valid' do
        it 'creates a new compliance requirement control' do
          expect { mutate }.to change { requirement.compliance_requirements_controls.count }.by 1
        end
      end

      context 'when control parameters are invalid' do
        subject(:mutate) { mutation.resolve(**invalid_name_params) }

        it 'does not create a new compliance control' do
          expect { mutate }.not_to change { requirement.compliance_requirements_controls.count }
        end

        it 'returns error for name' do
          expect(mutate[:errors]).to include "Name can't be blank"
        end
      end
    end

    context 'when current_user is personal namespace owner' do
      let_it_be(:namespace) { create(:user_namespace) }

      let(:current_user) { namespace.owner }

      context 'when control parameters are valid' do
        it_behaves_like 'resource not available'
      end
    end
  end

  private

  def valid_params
    {
      compliance_requirement_id: requirement.to_gid,
      params: {
        name: 'minimum_approvals_required_2',
        expression: control_expression
      }
    }
  end

  def invalid_name_params
    {
      compliance_requirement_id: requirement.to_gid,
      params: {
        name: '',
        expression: control_expression
      }
    }
  end

  def control_expression
    {
      operator: ">=",
      field: "minimum_approvals_required",
      value: 2
    }.to_json
  end
end
