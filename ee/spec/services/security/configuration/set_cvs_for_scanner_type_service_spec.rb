# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetCvsForScannerTypeService, feature_category: :software_composition_analysis do
  describe '.execute' do
    using RSpec::Parameterized::TableSyntax

    where(:scanner_type, :attribute) do
      :container_scanning | :cvs_for_container_scanning_enabled
      :dependency_scanning | :cvs_for_dependency_scanning_enabled
    end

    with_them do
      let(:security_setting) { create(:project_security_setting, attribute => false) }
      let(:project) { security_setting.project }

      it 'returns the new attribute value' do
        expect(described_class.execute(project: project, enable: true, scanner_type: scanner_type))
          .to have_attributes(errors: be_blank, payload: include(enabled: true))
        expect(described_class.execute(project: project, enable: false, scanner_type: scanner_type))
          .to have_attributes(errors: be_blank, payload: include(enabled: false))
      end

      it 'persists the change' do
        expect { described_class.execute(project: project, enable: true, scanner_type: scanner_type) }
          .to change { security_setting.reload.public_send(attribute) }.from(false).to(true)
      end

      context 'when an invalid value is provided' do
        it 'returns an error with the project id' do
          expect(described_class.execute(project: project, enable: nil, scanner_type: scanner_type))
            .to have_attributes(errors: be_present, payload: include(project_id: project.id))
        end

        it 'does not change the attribute' do
          expect { described_class.execute(project: project, enable: nil, scanner_type: scanner_type) }
            .not_to change { security_setting.reload.public_send(attribute) }
        end
      end

      context 'when an unexpected error occurs' do
        it 'propagates the error' do
          allow(project.security_setting).to receive(:"set_cvs_for_#{scanner_type}!")
            .and_raise(RuntimeError, 'unexpected')

          expect { described_class.execute(project: project, enable: true, scanner_type: scanner_type) }
            .to raise_error(RuntimeError, 'unexpected')
        end
      end
    end
  end
end
