# frozen_string_literal: true

require 'spec_helper'

RSpec.describe InstanceClusterablePresenter, :enable_admin_mode, feature_category: :environment_management do
  include Gitlab::Routing.url_helpers

  let(:presenter) { described_class.new(instance) }
  let(:cluster) { build_stubbed(:cluster, :provided_by_gcp, :instance) }
  let(:instance) { cluster.instance }

  describe '#environments_cluster_path' do
    subject { presenter.environments_cluster_path(cluster) }

    before do
      stub_licensed_features(cluster_deployments: true)
      allow(presenter).to receive(:current_user).and_return(user)
    end

    context 'with permissions' do
      let(:user) { build_stubbed(:admin) }

      it { is_expected.to eq(environments_admin_cluster_path(cluster)) }
    end

    context 'without permissions' do
      let(:user) { build_stubbed(:user) }

      it { is_expected.to be_nil }
    end
  end
end
