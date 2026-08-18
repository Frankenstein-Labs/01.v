# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::Projects::PathLock, feature_category: :source_code_management do
  specify do
    expected_permissions = %i[destroy_path_lock]

    expected_permissions.each do |permission|
      expect(described_class).to have_graphql_field(permission)
    end
  end
end
