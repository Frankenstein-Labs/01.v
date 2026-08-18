# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['UsersQueuedForRolePromotion'], feature_category: :seat_cost_management do
  it { expect(described_class.graphql_name).to eq('UsersQueuedForRolePromotion') }

  it 'includes the specific fields' do
    expected_fields = %w[
      user
      newAccessLevel
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'user field' do
    subject { described_class.fields['user'] }

    it { is_expected.to have_graphql_type(::Types::UserType) }
  end

  describe 'newAccessLevel field' do
    subject { described_class.fields['newAccessLevel'] }

    it { is_expected.to have_graphql_type(::Types::AccessLevelType) }
  end
end
