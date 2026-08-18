# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConsistencyChecks::HasVulnerabilitiesIsCorrectCheck,
  feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  let!(:project_setting) { create(:project_setting, project: project, has_vulnerabilities: has_vulnerabilities_value) }
  let(:check) { described_class.new(project) }

  using RSpec::Parameterized::TableSyntax

  before do
    create(:vulnerability, project: project) if actually_has_vulnerabilities
  end

  describe '#consistent?' do
    where(:has_vulnerabilities_value, :actually_has_vulnerabilities, :expected) do
      true  | true  | true
      false | false | true
      true  | false | false
      false | true  | false
    end

    with_them do
      it 'returns expected value' do
        expect(check.consistent?).to be(expected)
      end
    end
  end

  describe '#fix!' do
    subject(:fix!) { check.fix! }

    where(:has_vulnerabilities_value, :actually_has_vulnerabilities) do
      true  | false
      false | true
    end

    with_them do
      it 'makes has_vulnerabilities? consistent' do
        expect { fix! }.to change {
          project_setting.reload.has_vulnerabilities?
        }.from(has_vulnerabilities_value).to(actually_has_vulnerabilities)
      end
    end
  end

  describe '#execute' do
    context 'when check is consistent' do
      where(:has_vulnerabilities_value, :actually_has_vulnerabilities) do
        true  | true
        false | false
      end

      with_them do
        it 'does not call fix!' do
          expect(check).not_to receive(:fix!)

          check.execute
        end
      end
    end

    context 'when check is inconsistent' do
      where(:has_vulnerabilities_value, :actually_has_vulnerabilities) do
        true  | false
        false | true
      end

      with_them do
        it 'calls fix!' do
          expect(check).to receive(:fix!).and_call_original

          check.execute
        end
      end
    end
  end
end
