# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::IndexInitialBulkCronWorker, feature_category: :global_search do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
end
