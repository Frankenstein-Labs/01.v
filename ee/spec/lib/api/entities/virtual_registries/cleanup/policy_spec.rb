# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::VirtualRegistries::Cleanup::Policy, feature_category: :virtual_registry do
  let(:policy) { build_stubbed(:virtual_registries_cleanup_policy) }

  subject(:entity) { described_class.new(policy).as_json }

  it 'has the expected attributes' do
    expect(entity.keys).to contain_exactly(:group_id, :last_run_at, :enabled, :last_run_deleted_size,
      :last_run_deleted_entries_count, :keep_n_days_after_download, :cadence, :status, :failure_message, :created_at,
      :updated_at, :last_run_detailed_metrics, :next_run_at, :notify_on_success, :notify_on_failure)
  end
end
