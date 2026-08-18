# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::PipelineMinimalAccessType, feature_category: :continuous_integration do
  include GraphqlHelpers

  let(:type) { described_class }

  it 'has the correct name' do
    expect(type.graphql_name).to eq('PipelineMinimalAccess')
  end

  specify { expect(type).to require_graphql_authorizations(:read_pipeline_metadata) }

  it 'implements the Types::Ci::PipelineInterface' do
    expect(type.interfaces).to include(Types::Ci::PipelineInterface)
  end

  describe 'fields', :enable_admin_mode, feature_category: :permissions do
    let_it_be(:role) { create(:admin_member_role, :read_admin_cicd) }
    let_it_be(:current_user) { role.user }
    let_it_be(:pipeline) { create(:ci_pipeline, user: create(:user)) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'only the defined fields resolve to non-nil values' do
      defined_fields = %w[id project user]

      expect(described_class.own_fields.keys.map(&:underscore)).to match_array(defined_fields)

      defined_fields.each do |field|
        field_value = resolve_field(field, pipeline, current_user: current_user)
        expect(field_value).not_to be_nil
      end
    end

    describe 'inherited fields' do
      where(:field) do
        (described_class.fields.keys - described_class.own_fields.keys).map(&:underscore)
      end

      with_them do
        it 'resolves to nil' do
          expect(resolve_field(field, pipeline, current_user: current_user)).to be_nil
        end
      end
    end
  end
end
