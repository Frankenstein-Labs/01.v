# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Params, feature_category: :global_search do
  describe 'EE scope conversion' do
    using RSpec::Parameterized::TableSyntax

    let(:search) { 'search' }
    let(:params) { ActionController::Parameters.new(group_id: 123, search: search, scope: input_scope) }
    let(:search_params) { described_class.new(params, detect_abuse: false) }

    where(:input_scope, :expected_scope) do
      'epics'      | 'work_items'
      'work_items' | 'work_items'
      'blobs'      | 'blobs'
    end

    with_them do
      it 'handles EE-specific legacy scopes' do
        expect(search_params[:scope]).to eq(expected_scope)
      end
    end
  end
end
