# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::Update,
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: create(:compliance_framework, namespace: namespace))
  end

  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }

  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  let_it_be(:control_expression) do
    {
      operator: "=",
      field: "project_visibility_not_internal",
      value: true
    }.to_json
  end

  let(:params) do
    {
      name: 'project_visibility_not_internal',
      expression: control_expression
    }
  end

  before_all do
    namespace.add_owner(owner)
    namespace.add_maintainer(maintainer)
  end

  subject(:mutate) { mutation.resolve(id: global_id_of(control), params: params) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'when parameters are valid' do
      context 'when current_user is an owner' do
        let(:current_user) { owner }

        it 'updates the requirement control' do
          expect { mutate }
            .to change { control.reload.name }.to('project_visibility_not_internal')
            .and change { control.reload.expression }.to(control_expression)
        end

        it 'returns the updated object' do
          response = mutate[:requirements_control]

          expect(response.name).to eq('project_visibility_not_internal')
          expect(response.expression).to eq(control_expression)
        end

        it 'returns no errors' do
          expect(mutate[:errors]).to be_empty
        end
      end

      context 'when current_user is a maintainer' do
        let(:current_user) { maintainer }

        it 'raises an error' do
          expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when parameters are invalid' do
      let(:current_user) { owner }
      let(:params) do
        {
          name: ''
        }
      end

      it 'does not change the requirement control attributes' do
        expect { mutate }.to not_change { control.reload.attributes }
      end

      it 'returns validation errors' do
        expect(mutate[:errors])
          .to contain_exactly("Failed to update compliance requirement control. Error: Name can't be blank")
      end
    end
  end

  context 'when feature is unlicensed' do
    let(:current_user) { owner }

    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it 'raises an error' do
      expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end
  end
end
