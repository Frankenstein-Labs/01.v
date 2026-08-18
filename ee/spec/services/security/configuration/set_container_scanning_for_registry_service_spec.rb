# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetContainerScanningForRegistryService, feature_category: :software_composition_analysis do
  describe '#execute' do
    let_it_be_with_reload(:security_setting) do
      create(:project_security_setting, container_scanning_for_registry_enabled: false)
    end

    context 'when namespace is project' do
      let_it_be(:namespace) { security_setting.project }

      it 'returns attribute value' do
        expect(described_class.execute(namespace: namespace,
          enable: true)).to have_attributes(errors: be_blank, payload: include(enabled: true))
        expect(described_class.execute(namespace: namespace,
          enable: false)).to have_attributes(errors: be_blank, payload: include(enabled: false))
      end

      it 'changes the attribute' do
        expect { described_class.execute(namespace: namespace, enable: true) }
          .to change { security_setting.reload.container_scanning_for_registry_enabled }
          .from(false).to(true)
        expect { described_class.execute(namespace: namespace, enable: true) }
          .not_to change { security_setting.reload.container_scanning_for_registry_enabled }
        expect { described_class.execute(namespace: namespace, enable: false) }
          .to change { security_setting.reload.container_scanning_for_registry_enabled }
          .from(true).to(false)
        expect { described_class.execute(namespace: namespace, enable: false) }
          .not_to change { security_setting.reload.container_scanning_for_registry_enabled }
      end

      context 'when fields are invalid' do
        context 'when repository_path_pattern is invalid' do
          it 'returns nil and error' do
            expect(described_class.execute(namespace: namespace,
              enable: nil)).to have_attributes(errors: be_present, payload: include(enabled: nil))
          end

          it 'does not change the attribute' do
            expect { described_class.execute(namespace: namespace, enable: nil) }
              .not_to change { security_setting.reload.container_scanning_for_registry_enabled }
          end
        end
      end
    end
  end
end
