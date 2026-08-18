# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsageUserSort'], feature_category: :consumables_cost_management do
  specify { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsageUserSort') }

  describe 'sort values' do
    using RSpec::Parameterized::TableSyntax

    where(:sort_name, :sort_value) do
      'NAME_ASC'                 | :name_asc
      'NAME_DESC'                | :name_desc
      'TOTAL_CREDITS_USED_ASC'   | :total_credits_used_asc
      'TOTAL_CREDITS_USED_DESC'  | :total_credits_used_desc
    end

    with_them do
      it 'exposes a sort value with the correct value' do
        expect(described_class.values[sort_name].value).to eq(sort_value)
      end
    end
  end
end
