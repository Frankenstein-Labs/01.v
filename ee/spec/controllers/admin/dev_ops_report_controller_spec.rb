# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::DevOpsReportController, feature_category: :devops_reports do
  describe 'show_adoption?' do
    it "is false if license feature 'devops_adoption' is disabled" do
      expect(controller.show_adoption?).to be false
    end

    context "'devops_adoption' license feature is enabled" do
      before do
        stub_licensed_features(devops_adoption: true)
      end

      it 'is true' do
        expect(controller.show_adoption?).to be true
      end
    end

    context "'devops_adoption' is enabled through usage ping features" do
      before do
        stub_usage_ping_features(true)
      end

      it 'is true' do
        expect(controller.show_adoption?).to be true
      end
    end
  end

  describe '#show' do
    let(:user) { create(:admin) }

    before do
      sign_in(user)
    end

    context 'with devops adoption available' do
      before do
        stub_licensed_features(devops_adoption: true)
      end

      ['', 'dev', 'sec', 'ops'].each do |tab|
        it_behaves_like 'internal event tracking' do
          let(:event) { 'i_analytics_dev_ops_adoption' }
          let(:category) { described_class.name }

          subject { get :show, params: { tab: tab }, format: :html }
        end
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'i_analytics_dev_ops_score' }
        let(:category) { described_class.name }

        subject { get :show, params: { tab: 'devops-score' }, format: :html }
      end
    end

    context 'with devops adoption not available' do
      before do
        stub_licensed_features(devops_adoption: false)
      end

      ['', 'dev', 'sec', 'ops', 'devops-score'].each do |tab|
        it_behaves_like 'internal event tracking' do
          let(:event) { 'i_analytics_dev_ops_score' }
          let(:category) { described_class.name }

          subject { get :show, params: { tab: tab }, format: :html }
        end
      end
    end
  end
end
