# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyScope, feature_category: :security_policy_management do
  describe '#match_mode' do
    context 'when match_mode is present' do
      let(:policy_scope) { described_class.new({ match_mode: 'any' }) }

      it 'returns the specified match_mode' do
        expect(policy_scope.match_mode).to eq('any')
      end
    end

    context 'when match_mode is not present' do
      let(:policy_scope) { described_class.new({}) }

      it 'returns the default match_mode' do
        expect(policy_scope.match_mode).to eq('all')
      end
    end

    context 'when policy_scope is nil' do
      let(:policy_scope) { described_class.new(nil) }

      it 'returns the default match_mode' do
        expect(policy_scope.match_mode).to eq('all')
      end
    end
  end

  describe '#match_mode_any?' do
    context 'when match_mode is any' do
      let(:policy_scope) { described_class.new({ match_mode: 'any' }) }

      it 'returns true' do
        expect(policy_scope.match_mode_any?).to be true
      end
    end

    context 'when match_mode is all' do
      let(:policy_scope) { described_class.new({ match_mode: 'all' }) }

      it 'returns false' do
        expect(policy_scope.match_mode_any?).to be false
      end
    end

    context 'when match_mode is not present' do
      let(:policy_scope) { described_class.new({}) }

      it 'returns false (defaults to all)' do
        expect(policy_scope.match_mode_any?).to be false
      end
    end
  end

  describe '#compliance_frameworks' do
    context 'when compliance_frameworks is present' do
      let(:policy_scope_data) { { compliance_frameworks: [{ id: 1 }, { id: 2 }] } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the compliance_frameworks array' do
        expect(policy_scope.compliance_frameworks).to match_array([{ id: 1 }, { id: 2 }])
      end
    end

    context 'when compliance_frameworks is not present' do
      let(:policy_scope_data) { {} }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns an empty array' do
        expect(policy_scope.compliance_frameworks).to be_empty
      end
    end
  end

  describe '#projects' do
    context 'when projects is present' do
      let(:policy_scope_data) { { projects: { including: [{ id: 1 }, { id: 2 }, { id: 3 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the projects hash' do
        expect(policy_scope.projects).to eq({ including: [{ id: 1 }, { id: 2 }, { id: 3 }] })
      end
    end

    context 'when projects has excluding' do
      let(:policy_scope_data) { { projects: { excluding: [{ id: 4 }, { id: 5 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the projects hash with excluding' do
        expect(policy_scope.projects).to eq({ excluding: [{ id: 4 }, { id: 5 }] })
      end
    end

    context 'when projects has both including and excluding' do
      let(:policy_scope_data) { { projects: { including: [{ id: 1 }, { id: 2 }], excluding: [{ id: 3 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the projects hash with both including and excluding' do
        expect(policy_scope.projects).to eq({ including: [{ id: 1 }, { id: 2 }], excluding: [{ id: 3 }] })
      end
    end

    context 'when projects is not present' do
      let(:policy_scope_data) { {} }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns an empty hash' do
        expect(policy_scope.projects).to be_empty
      end
    end
  end

  describe '#groups' do
    context 'when groups is present' do
      let(:policy_scope_data) { { groups: { including: [{ id: 4 }, { id: 5 }, { id: 6 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the groups hash' do
        expect(policy_scope.groups).to eq({ including: [{ id: 4 }, { id: 5 }, { id: 6 }] })
      end
    end

    context 'when groups has excluding' do
      let(:policy_scope_data) { { groups: { excluding: [{ id: 7 }, { id: 8 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the groups hash with excluding' do
        expect(policy_scope.groups).to eq({ excluding: [{ id: 7 }, { id: 8 }] })
      end
    end

    context 'when groups has both including and excluding' do
      let(:policy_scope_data) { { groups: { including: [{ id: 4 }, { id: 5 }], excluding: [{ id: 6 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the groups hash with both including and excluding' do
        expect(policy_scope.groups).to eq({ including: [{ id: 4 }, { id: 5 }], excluding: [{ id: 6 }] })
      end
    end

    context 'when groups is not present' do
      let(:policy_scope_data) { {} }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns an empty hash' do
        expect(policy_scope.groups).to be_empty
      end
    end
  end

  describe '#business_impact' do
    context 'when business_impact is present' do
      let(:policy_scope_data) { { business_impact: { including: [{ id: 1 }], excluding: [{ id: 2 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the business_impact hash' do
        expect(policy_scope.business_impact).to eq({ including: [{ id: 1 }], excluding: [{ id: 2 }] })
      end
    end

    context 'when business_impact is not present' do
      let(:policy_scope) { described_class.new({}) }

      it 'returns an empty hash' do
        expect(policy_scope.business_impact).to be_empty
      end
    end
  end

  describe '#application' do
    context 'when application is present' do
      let(:policy_scope_data) { { application: { including: [{ id: 1 }], excluding: [{ id: 2 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the application hash' do
        expect(policy_scope.application).to eq({ including: [{ id: 1 }], excluding: [{ id: 2 }] })
      end
    end

    context 'when application is not present' do
      let(:policy_scope) { described_class.new({}) }

      it 'returns an empty hash' do
        expect(policy_scope.application).to be_empty
      end
    end
  end

  describe '#business_unit' do
    context 'when business_unit is present' do
      let(:policy_scope_data) { { business_unit: { including: [{ id: 1 }], excluding: [{ id: 2 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the business_unit hash' do
        expect(policy_scope.business_unit).to eq({ including: [{ id: 1 }], excluding: [{ id: 2 }] })
      end
    end

    context 'when business_unit is not present' do
      let(:policy_scope) { described_class.new({}) }

      it 'returns an empty hash' do
        expect(policy_scope.business_unit).to be_empty
      end
    end
  end

  describe '#exposure' do
    context 'when exposure is present' do
      let(:policy_scope_data) { { exposure: { including: [{ id: 1 }], excluding: [{ id: 2 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the exposure hash' do
        expect(policy_scope.exposure).to eq({ including: [{ id: 1 }], excluding: [{ id: 2 }] })
      end
    end

    context 'when exposure is not present' do
      let(:policy_scope) { described_class.new({}) }

      it 'returns an empty hash' do
        expect(policy_scope.exposure).to be_empty
      end
    end
  end

  describe '#has_security_attribute?' do
    let(:attribute_id) { 42 }

    subject(:has_security_attribute?) do
      described_class.new(policy_scope_data).has_security_attribute?(scope_key, attribute_id)
    end

    described_class::SECURITY_ATTRIBUTE_SCOPE_KEYS.each_key do |key|
      context "with scope_key :#{key}" do
        let(:scope_key) { key }

        context 'when scope is empty' do
          let(:policy_scope_data) { {} }

          it { is_expected.to be_falsey }
        end

        context 'when scope includes the attribute_id' do
          let(:policy_scope_data) { { key => { including: [{ id: attribute_id }] } } }

          it { is_expected.to be_truthy }
        end

        context 'when scope excludes the attribute_id' do
          let(:policy_scope_data) { { key => { excluding: [{ id: attribute_id }] } } }

          it { is_expected.to be_truthy }
        end

        context 'when scope has a non-matching attribute_id' do
          let(:policy_scope_data) { { key => { including: [{ id: attribute_id + 1 }] } } }

          it { is_expected.to be_falsey }
        end

        context 'when scope has multiple attributes and one matches' do
          let(:policy_scope_data) { { key => { including: [{ id: attribute_id }, { id: attribute_id + 1 }] } } }

          it { is_expected.to be_truthy }
        end

        context 'when scope value is not a Hash' do
          let(:policy_scope_data) { { key => nil } }

          it { is_expected.to be_falsey }
        end
      end
    end
  end

  describe '#references_any_security_attribute?' do
    let(:attribute_id) { 42 }

    subject(:references_any_security_attribute?) do
      described_class.new(policy_scope_data).references_any_security_attribute?(attribute_id)
    end

    shared_examples 'includes attribute in scope' do
      let(:policy_scope_data) { { scope_key => { including: [{ id: attribute_id }] } } }

      it { is_expected.to be_truthy }
    end

    shared_examples 'excludes attribute in scope' do
      let(:policy_scope_data) { { scope_key => { excluding: [{ id: attribute_id }] } } }

      it { is_expected.to be_truthy }
    end

    context 'when no security attributes are present' do
      let(:policy_scope_data) { {} }

      it { is_expected.to be_falsey }
    end

    context 'when attribute_id is referenced in business_impact scope' do
      let(:scope_key) { :business_impact }

      it_behaves_like 'includes attribute in scope'
    end

    context 'when attribute_id is referenced in application scope' do
      let(:scope_key) { :application }

      it_behaves_like 'includes attribute in scope'
    end

    context 'when attribute_id is referenced in business_unit scope' do
      let(:scope_key) { :business_unit }

      it_behaves_like 'includes attribute in scope'
    end

    context 'when attribute_id is referenced in exposure scope' do
      let(:scope_key) { :exposure }

      it_behaves_like 'includes attribute in scope'
    end

    context 'when attribute_id is excluded in business_impact scope' do
      let(:scope_key) { :business_impact }

      it_behaves_like 'excludes attribute in scope'
    end

    context 'when attribute_id is excluded in application scope' do
      let(:scope_key) { :application }

      it_behaves_like 'excludes attribute in scope'
    end

    context 'when attribute_id is excluded in business_unit scope' do
      let(:scope_key) { :business_unit }

      it_behaves_like 'excludes attribute in scope'
    end

    context 'when attribute_id is excluded in exposure scope' do
      let(:scope_key) { :exposure }

      it_behaves_like 'excludes attribute in scope'
    end

    context 'when attribute_id is not referenced in any scope' do
      let(:policy_scope_data) do
        {
          business_impact: { including: [{ id: attribute_id + 1 }] },
          application: { including: [{ id: attribute_id + 2 }] },
          business_unit: { including: [{ id: attribute_id + 3 }] },
          exposure: { including: [{ id: attribute_id + 4 }] }
        }
      end

      it { is_expected.to be_falsey }
    end

    context 'when scope values are not Hashes' do
      let(:policy_scope_data) do
        {
          business_impact: nil,
          application: nil,
          business_unit: nil,
          exposure: nil
        }
      end

      it { is_expected.to be_falsey }
    end
  end
end
