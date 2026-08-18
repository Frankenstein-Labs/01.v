# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirements::Destroy,
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:requirement) { create(:compliance_requirement, framework: framework) }

  let_it_be(:current_user) { create(:user) }
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  subject { mutation.resolve(id: global_id_of(requirement)) }

  before_all do
    namespace.add_owner(current_user)
  end

  shared_examples 'a compliance requirement that cannot be found' do
    it 'raises an error' do
      expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end
  end

  shared_examples 'one compliance requirement was destroyed' do
    it 'destroys a compliance requirement' do
      expect { subject }.to change {
        ComplianceManagement::ComplianceFramework::ComplianceRequirement.exists?(id: requirement.id)
      }.from(true).to(false)
    end

    it 'expects zero errors in the response' do
      expect(subject[:errors]).to be_empty
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it_behaves_like 'a compliance requirement that cannot be found'
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'when current_user is namespace owner' do
      it_behaves_like 'one compliance requirement was destroyed'
    end

    context 'when current_user is group owner' do
      let_it_be(:group) { create(:group) }
      let_it_be(:current_user) { create(:user) }
      let_it_be(:framework) { create(:compliance_framework, namespace: group) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: framework) }

      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'one compliance requirement was destroyed'
    end
  end
end
