# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::MergeTrains::Car, feature_category: :merge_trains do
  specify do
    expected_permissions = [:delete_merge_train_car]

    expected_permissions.each do |permission|
      expect(described_class).to have_graphql_field(permission)
    end
  end
end
