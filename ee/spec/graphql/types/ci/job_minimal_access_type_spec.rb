# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::JobMinimalAccessType, feature_category: :continuous_integration do
  include GraphqlHelpers

  let(:type) { described_class }

  it 'has the correct name' do
    expect(type.graphql_name).to eq('CiJobMinimalAccess')
  end

  specify { expect(type).to require_graphql_authorizations(:read_build_metadata) }

  it 'implements the Types::Ci::JobInterface' do
    expect(type.interfaces).to include(Types::Ci::JobInterface)
  end

  describe 'fields', :enable_admin_mode, feature_category: :permissions do
    let_it_be(:role) { create(:admin_member_role, :read_admin_cicd) }
    let_it_be(:current_user) { role.user }
    let_it_be(:runner) { create(:ci_runner) }
    let_it_be(:job) { create(:ci_build, :finished, :scheduled, :manual, tag: true, coverage: 99, runner: runner) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    def resolve_type_field(field, object, current_user)
      context = { current_user: current_user }

      resolve_field(field, object, ctx: context)
    end

    it 'only the defined fields resolve to non-nil values', :aggregate_failures do
      defined_fields = %w[
        active
        allow_failure
        coverage
        created_by_tag
        detailed_status
        duration
        finished_at
        id
        manual_job
        name
        pipeline
        project
        queued_duration
        ref_name
        runner
        scheduled_at
        short_sha
        status
        stuck
        tags
        triggered
      ]

      expect(described_class.own_fields.keys.map(&:underscore)).to match_array(defined_fields)

      defined_fields.each do |field|
        field_value = resolve_type_field(field, job, current_user)
        expect(field_value).not_to be_nil
      end
    end

    describe 'inherited fields' do
      where(:field) do
        (described_class.fields.keys - described_class.own_fields.keys).map(&:underscore)
      end

      with_them do
        it 'resolves to nil' do
          expect(resolve_type_field(field, job, current_user)).to be_nil
        end
      end
    end
  end
end
