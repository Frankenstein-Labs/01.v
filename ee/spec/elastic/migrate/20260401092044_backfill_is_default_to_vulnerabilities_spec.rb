# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260401092044_backfill_is_default_to_vulnerabilities.rb')

RSpec.describe BackfillIsDefaultToVulnerabilities, :elastic_delete_by_query, feature_category: :vulnerability_management do
  include_examples 'migration backfills fields' do
    let_it_be(:project) { create(:project) }
    let_it_be(:tracked_context) { create(:security_project_tracked_context, :default, project: project) }

    let(:vulnerabilities_with_context) do
      create_list(:vulnerability_read, 2, tracked_context: tracked_context, project: project)
    end

    let(:vulnerability_missing_context) do
      create(:vulnerability_read, security_project_tracked_context_id: nil, project: project)
    end

    let(:objects) do
      vulnerabilities_with_context + [vulnerability_missing_context]
    end

    let(:expected_fields) { { is_default: tracked_context.is_default } }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 9000 }
    let(:version) { 20260401092044 }
  end
end
