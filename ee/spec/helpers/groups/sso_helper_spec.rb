# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SsoHelper, feature_category: :shared do
  describe '#saml_provider_enabled' do
    using RSpec::Parameterized::TableSyntax
    context 'without group' do
      it 'returns false' do
        expect(helper.saml_provider_enabled?(nil)).to be false
        expect(helper.saml_provider_enabled?(build(:user_namespace))).to be false
        expect(helper.saml_provider_enabled?(build(:project))).to be false
      end
    end

    context 'with group' do
      where(:enabled, :result) do
        true  | true
        false | false
      end

      with_them do
        it 'returns the expected value' do
          provider = instance_double('SamlProvider')
          allow(provider).to receive(:enabled?) { enabled }

          group = instance_double('Group')
          allow(group).to receive(:is_a?).and_return(true)
          allow(group).to receive(:root_ancestor) { group }
          allow(group).to receive(:saml_provider) { provider }

          expect(helper.saml_provider_enabled?(group)).to eq(result)
        end
      end
    end
  end
end
