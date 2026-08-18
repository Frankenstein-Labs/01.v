# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::Destroy,
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: create(:compliance_framework, namespace: namespace))
  end

  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }

  let_it_be(:current_user) { create(:user) }
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  subject(:mutate) { mutation.resolve(id: global_id_of(control)) }

  before_all do
    namespace.add_owner(current_user)
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it 'raises an error' do
      expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    it 'destroys a compliance requirement control' do
      expect { mutate }.to change {
        ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.exists?(id: control.id)
      }.from(true).to(false)
    end

    it 'expects zero errors in the response' do
      expect(mutate[:errors]).to be_empty
    end
  end
end
