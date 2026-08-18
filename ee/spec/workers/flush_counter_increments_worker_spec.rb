# frozen_string_literal: true

require 'spec_helper'

# We need to assert the behavior with this worker with a model that uses composite primary keys.
# The only model with those conditions is only available on the EE side.
# When a model with similar aspects is available on CE, merge this spec with the CE spec.
RSpec.describe FlushCounterIncrementsWorker, :counter_attribute, feature_category: :source_code_management do
  let_it_be(:model) { create(:virtual_registries_packages_maven_cache_remote_entry) }
  let(:worker) { described_class.new }

  describe '#perform', :redis do
    subject(:perform) { worker.perform(model.class.name, model.id, 'downloads_count') }

    context 'with a composite primary key model' do
      it 'commits increments to database' do
        expect_next_instance_of(Gitlab::Counters::BufferedCounter) do |counter|
          expect(counter).to receive(:commit_increment!)
        end

        perform
      end
    end
  end
end
