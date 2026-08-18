# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyScope'], feature_category: :security_policy_management do
  let(:fields) do
    %i[compliance_frameworks including_projects excluding_personal_projects excluding_archived_projects
      excluding_projects including_groups excluding_groups match_mode
      including_business_impact_attributes excluding_business_impact_attributes
      including_application_attributes excluding_application_attributes
      including_business_unit_attributes excluding_business_unit_attributes
      including_exposure_attributes excluding_exposure_attributes]
  end

  it { expect(described_class).to have_graphql_fields(fields) }
end
