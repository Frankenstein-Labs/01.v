# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirements::Update,
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: framework)
  end

  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }

  let_it_be(:controls) do
    [
      {
        expression: "{\"operator\":\">=\",\"field\":\"minimum_approvals_required\",\"value\":2}",
        name: "minimum_approvals_required_2"
      },
      {
        expression: { operator: "=", field: "project_visibility_not_internal", value: true }.to_json,
        name: "project_visibility_not_internal"
      }
    ]
  end

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }
  let(:params) do
    {
      name: 'New Name',
      description: 'New Description'
    }
  end

  before_all do
    namespace.add_owner(owner)
    namespace.add_maintainer(maintainer)
    namespace.add_developer(developer)
    namespace.add_guest(guest)
  end

  subject(:mutate) { mutation.resolve(id: global_id_of(requirement), params: params, controls: controls) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)
    end

    context 'when parameters are valid' do
      context 'when current_user is an owner' do
        let(:current_user) { owner }

        it 'updates the requirement' do
          expect { mutate }.to change { requirement.reload.name }.to('New Name')
                                                                 .and change {
                                                                   requirement.reload.description
                                                                 }.to('New Description')
        end

        it 'returns the updated object' do
          response = mutate[:requirement]

          expect(response.name).to eq('New Name')
          expect(response.description).to eq('New Description')
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

      context 'when current_user is a developer' do
        let(:current_user) { developer }

        it 'raises an error' do
          expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when current_user is a guest' do
        let(:current_user) { guest }

        it 'raises an error' do
          expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when parameters are invalid' do
      let(:current_user) { owner }
      let(:params) do
        {
          name: '',
          description: ''
        }
      end

      it 'does not change the requirement attributes' do
        expect { mutate }.to not_change { requirement.reload.attributes }
      end

      it 'returns validation errors' do
        expect(mutate[:errors])
          .to contain_exactly(
            "Name can't be blank",
            "Description can't be blank",
            "Failed to update compliance requirement"
          )
      end
    end

    context 'when controls are invalid' do
      let(:current_user) { owner }
      let_it_be(:controls) do
        [
          {
            expression: { operator: ">=", field: "minimum_approvals_required", value: "invalid_number" }.to_json,
            name: "minimum_approvals_required_2"
          }
        ]
      end

      it 'does not change the requirement attributes' do
        expect { mutate }.to not_change { requirement.reload.attributes }
      end

      it 'returns validation errors' do
        expect(mutate[:errors]).to include(%r{Expression property '/value' is not of type})
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
