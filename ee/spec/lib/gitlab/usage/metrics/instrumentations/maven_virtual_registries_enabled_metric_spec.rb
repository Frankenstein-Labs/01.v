# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::MavenVirtualRegistriesEnabledMetric, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  describe '#value' do
    let_it_be(:group) { create(:group) }

    let_it_be_with_refind(:setting) { create(:virtual_registries_setting, group:) }

    let_it_be_with_refind(:registry) { create(:virtual_registries_packages_maven_registry, group:) }

    where(:setting_record, :registries_exist, :expected_value) do
      :none     | false | false
      :none     | true  | true
      :disabled | false | false
      :disabled | true  | false
      :enabled  | true  | true
      :enabled  | false | false
    end

    with_them do
      before do
        registry.destroy! unless registries_exist

        if setting_record == :none
          setting.destroy!
        else
          setting.update!(enabled: setting_record == :enabled)
        end
      end

      it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', data_source: 'database' }
    end
  end
end
