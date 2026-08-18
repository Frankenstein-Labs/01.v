# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::UserPreferencesType, feature_category: :user_profile do
  it 'has the expected EE fields' do
    expected_fields = %w[duo_default_namespace]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'duo_default_namespace field' do
    subject { described_class.fields['duoDefaultNamespace'] }

    it 'has the correct type' do
      is_expected.to have_graphql_type(Types::NamespaceType)
    end
  end
end
