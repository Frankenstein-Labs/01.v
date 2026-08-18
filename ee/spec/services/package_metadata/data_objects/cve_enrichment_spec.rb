# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::DataObjects::CveEnrichment, feature_category: :software_composition_analysis do
  describe '.create' do
    let(:data) do
      {
        "cve_id" => "CVE-2023-12345",
        "epss_score" => 0.5,
        "is_known_exploit" => false
      }
    end

    subject(:create) { described_class.create(data, nil) }

    it { is_expected.to be_kind_of(described_class) }

    it do
      is_expected.to match(have_attributes(
        cve_id: "CVE-2023-12345",
        epss_score: 0.5,
        is_known_exploit: false
      ))
    end

    context 'when an attribute is missing' do
      using RSpec::Parameterized::TableSyntax

      subject(:create!) { described_class.create(data.except(attribute.to_s), nil) }

      where(:attribute, :required) do
        :cve_id      | true
        :epss_score  | true
      end

      with_them do
        specify do
          required ? expect { create! }.to(raise_error(ArgumentError)) : expect { create! }.not_to(raise_error)
        end
      end
    end
  end

  describe '==' do
    let(:obj) { described_class.new(cve_id: "CVE-2023-12345", epss_score: 0.85, is_known_exploit: false) }

    subject(:equality) { obj == other }

    context 'when all attributes are equal' do
      let(:other) { obj }

      it { is_expected.to be(true) }
    end

    context 'when cve_id does not match' do
      let(:other) { obj.dup.tap { |o| o.cve_id = "CVE-2023-54321" } }

      it { is_expected.to be(false) }
    end

    context 'when epss_score does not match' do
      let(:other) { obj.dup.tap { |o| o.epss_score = 0.9 } }

      it { is_expected.to be(false) }
    end

    context 'when is_known_exploit does not match' do
      let(:other) { obj.dup.tap { |o| o.is_known_exploit = true } }

      it { is_expected.to be(false) }
    end
  end
end
