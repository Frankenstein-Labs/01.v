# frozen_string_literal: true

RSpec.shared_examples 'does not change namespace Duo Core features setting' do
  where(:existing_setting) do
    [true, false, nil]
  end

  with_them do
    before do
      namespace.namespace_settings.update!(duo_core_features_enabled: existing_setting) unless existing_setting.nil?
    end

    it 'does not change namespace Duo Core features setting' do
      expect { subject }
        .not_to change { namespace.namespace_settings.reload.duo_core_features_enabled }
        .from(existing_setting)
    end
  end
end

RSpec.shared_examples 'enables DuoCore automatically only if customer has not chosen DuoCore setting for namespace' do
  it 'enables Duo Core automatically if customer has not chosen DuoCore setting on this namespace' do
    expect { subject }
      .to change { namespace.namespace_settings.reload.duo_core_features_enabled }
      .from(nil).to(true)
  end

  context 'when customer has chosen DuoCore setting on this namespace' do
    [true, false].each do |customer_setting|
      it 'does not change existing setting' do
        namespace.namespace_settings.update!(duo_core_features_enabled: customer_setting)

        expect { subject }.not_to change { namespace.namespace_settings.reload.duo_core_features_enabled }
      end
    end
  end
end
