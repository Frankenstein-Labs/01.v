# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::PackageSettings::UpdateService, feature_category: :package_registry do
  let_it_be_with_reload(:namespace) { create(:group) }
  let_it_be(:user) { create(:user, owner_of: namespace) }

  let(:service) { described_class.new(container: namespace, current_user: user, params: params) }

  describe '#execute' do
    subject { service.execute }

    let(:params) { { audit_events_enabled: true } }

    shared_examples 'returning a success' do
      it 'returns a success' do
        is_expected.to be_success.and have_attributes(
          payload: { package_settings: have_attributes(audit_events_enabled: true) }
        )
      end
    end

    context 'with existing namespace package setting' do
      let_it_be(:package_settings) { create(:namespace_package_setting, namespace: namespace) }

      it_behaves_like 'updating the namespace package setting attributes',
        from: { audit_events_enabled: false }, to: { audit_events_enabled: true }
      it_behaves_like 'returning a success'
    end

    context 'without existing namespace package setting' do
      let(:package_settings) { namespace.package_settings }

      it_behaves_like 'creating the namespace package setting'
    end
  end
end
