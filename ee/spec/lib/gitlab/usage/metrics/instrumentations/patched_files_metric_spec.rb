# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::PatchedFilesMetric, feature_category: :delivery do
  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' } do
    let(:expected_value) { nil }
  end

  describe 'when redis has data' do
    let(:expected_value) do
      <<~OUTPUT
        S.5....T.    /opt/gitlab/embedded/cookbooks/gitlab-pages/libraries/gitlab_pages.rb
        S.5....T.    /opt/gitlab/embedded/service/gitlab-rails/app/views/projects/issues/_details_content.html.haml
      OUTPUT
    end

    before do
      mock_redis = instance_double(Redis)
      allow(Gitlab::Redis::SharedState).to receive(:with).and_yield(mock_redis)
      allow(mock_redis).to receive(:get).with(Metrics::PatchedFilesWorker::REDIS_KEY).and_return(expected_value)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
