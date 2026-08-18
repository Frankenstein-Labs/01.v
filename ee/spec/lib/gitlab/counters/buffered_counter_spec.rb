# frozen_string_literal: true

require 'spec_helper'

# We need to assert the behavior with a counter record that has a group_id column.
# The only model with those conditions is only available on the EE side.
# When a model with similar aspects is available on CE, merge this spec with the CE spec.
RSpec.describe Gitlab::Counters::BufferedCounter, :clean_gitlab_redis_shared_state, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:counter_record) { create(:virtual_registries_packages_maven_cache_remote_entry) }

  let(:attribute) { :downloads_count }

  subject(:counter) { described_class.new(counter_record, attribute) }

  describe '#get' do
    it_behaves_like 'handling a buffered counter in redis'
  end

  describe '#increment' do
    let(:increment) { Gitlab::Counters::Increment.new(amount: 123, ref: 1) }
    let(:other_increment) { Gitlab::Counters::Increment.new(amount: 100, ref: 2) }

    it_behaves_like 'incrementing a buffered counter when not undergoing a refresh'
  end
end
