# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::InitializeStackService, :clean_gitlab_redis_shared_state,
  feature_category: :product_analytics do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, group: group, maintainers: user) }

  before do
    stub_feature_flags(product_analytics_billing_override: false)
  end

  describe '#lock!' do
    subject { described_class.new(container: project, current_user: user).lock! }

    it 'sets the redis key' do
      expect { subject }
        .to change {
          described_class.new(container: project, current_user: user).send(:locked?)
        }.from(false).to(true)
    end
  end

  describe '#unlock!' do
    subject { described_class.new(container: project, current_user: user).unlock! }

    it 'deletes the redis key' do
      subject

      expect(described_class.new(container: project, current_user: user).send(:locked?)).to be false
    end
  end

  describe '#execute' do
    subject { described_class.new(container: project, current_user: user).execute }

    before do
      stub_licensed_features(product_analytics: true)
      stub_ee_application_setting(product_analytics_enabled: true)
      stub_feature_flags(product_analytics_billing: false)
    end

    context 'when snowplow support is enabled' do
      context 'when project is already initialized for product analytics' do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: '123')
        end

        it 'returns an error response' do
          expect(subject).to be_error
          expect(subject.message).to eq('Product analytics initialization is already complete')
        end
      end
    end

    context 'when product analytics is disabled per project' do
      before do
        allow(project).to receive(:product_analytics_enabled?).and_return(false)
      end

      it 'returns an error' do
        expect(subject.message).to eq "Product analytics is disabled for this project"
      end
    end

    context 'when product analytics is disabled at instance level' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(false)
      end

      it 'returns an error' do
        expect(subject.message).to eq "Product analytics is disabled"
      end
    end
  end
end
