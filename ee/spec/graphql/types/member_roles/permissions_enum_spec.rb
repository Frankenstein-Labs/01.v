# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MemberRolePermission'], feature_category: :permissions do
  specify { expect(described_class.graphql_name).to eq('MemberRolePermission') }

  it 'exposes all the existing custom permissions',
    quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449111' do
    expect(described_class.values.keys)
      .to match_array(::MemberRole.all_customizable_permissions.keys.map(&:to_s).map(&:upcase))
  end
end
