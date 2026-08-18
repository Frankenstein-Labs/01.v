# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Namespace::PackageSettings::Update, feature_category: :package_registry do
  include GraphqlHelpers

  let_it_be_with_reload(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }

  describe '#resolve' do
    subject { described_class.new(object: namespace, context: query_context, field: nil).resolve(**params) }

    let(:params) { { namespace_path: namespace.full_path, audit_events_enabled: true } }

    shared_examples 'returning a success' do
      it 'returns the namespace package setting with no errors' do
        is_expected.to include(
          package_settings: have_attributes(audit_events_enabled: true),
          errors: []
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
