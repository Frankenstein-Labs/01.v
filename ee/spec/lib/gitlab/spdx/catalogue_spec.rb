# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::SPDX::Catalogue, feature_category: :software_composition_analysis do
  include StubRequests
  subject(:catalogue) { described_class.new(catalogue_hash) }

  let(:spdx_json) { File.read(Rails.root.join("spec", "fixtures", "spdx.json")) }
  let(:catalogue_hash) { Gitlab::Json.parse(spdx_json, symbolize_names: true) }

  describe "#version" do
    let(:version) { SecureRandom.uuid }

    it { expect(described_class.new(licenseListVersion: version).version).to eql(version) }
  end

  describe "#each" do
    it { expect(catalogue.count).to eql(catalogue_hash[:licenses].count) }
    it { expect(catalogue.map(&:id)).to match_array(catalogue_hash[:licenses].map { |x| x[:licenseId] }) }
    it { expect(catalogue.map(&:name)).to match_array(catalogue_hash[:licenses].map { |x| x[:name] }) }

    specify do
      deprecrated_gpl = catalogue.find { |license| license.id == 'GPL-1.0' }
      expect(deprecrated_gpl.deprecated).to be_truthy
    end

    specify do
      gpl = catalogue.find { |license| license.id == 'GPL-1.0-only' }
      expect(gpl.deprecated).to be_falsey
    end
  end

  describe "#licenses" do
    it 'returns all licenses converted to POROs' do
      expected = catalogue_hash[:licenses].map do |license|
        an_object_having_attributes(
          id: license[:licenseId],
          name: license[:name],
          deprecated: license[:isDeprecatedLicenseId]
        )
      end

      expect(catalogue.licenses).to match_array(expected)
    end

    it 'has identifiers for all licenses' do
      expect(catalogue.licenses.pluck(:id)).to all(be_present)
    end
  end

  describe ".latest" do
    subject(:latest) { described_class.latest }

    context "when the licenses.json endpoint is healthy" do
      let(:gateway) { instance_double(Gitlab::SPDX::CatalogueGateway, fetch: catalogue) }
      let(:catalogue) { instance_double(described_class) }

      before do
        allow(Gitlab::SPDX::CatalogueGateway).to receive(:new).and_return(gateway)
      end

      it { expect(latest).to be(catalogue) }
    end
  end

  describe ".latest_licenses", :clean_gitlab_redis_cache do
    subject(:latest_licenses) { described_class.latest_licenses }

    it 'returns SPDX licenses including the unknown placeholder' do
      expect(latest_licenses.map(&:id)).to include('MIT', 'GPL-1.0', 'unknown')
    end

    it 'returns licenses sorted by name' do
      names = latest_licenses.map(&:name)

      expect(names).to eq(names.sort)
    end

    it 'caches the licenses' do
      expect(Rails.cache).to receive(:fetch).with(described_class::LATEST_LICENSES_CACHE_KEY, expires_in: 7.days)
      latest_licenses
    end
  end

  describe ".latest_active_licenses", :clean_gitlab_redis_cache do
    subject(:latest_active_licenses) { described_class.latest_active_licenses }

    it 'rejects deprecated licenses' do
      expect(latest_active_licenses.find(&:deprecated)).to be_nil
    end

    it 'returns only active licenses' do
      expect(latest_active_licenses.all?(&:deprecated)).to be_falsey
    end

    it 'returns the expected active licenses' do
      expect(latest_active_licenses.find { |l| l.id == 'MIT' }).to be_present
    end

    it 'caches the active license' do
      expect(Rails.cache).to receive(:fetch).with(described_class::LATEST_ACTIVE_LICENSES_CACHE_KEY, expires_in: 7.days)
      latest_active_licenses
    end
  end

  describe ".latest_active_license_names", :clean_gitlab_redis_cache do
    let(:academic) { build(:spdx_license, name: 'Academic Free License v1.1', deprecated: false) }
    let(:mit) { build(:spdx_license, name: 'MIT License', deprecated: false) }
    let(:affero) { build(:spdx_license, name: 'GNU Affero General Public License v3.0', deprecated: true) }

    let(:licenses) { [academic, mit, affero] }

    let(:catalogue_hash) do
      {
        licenseListVersion: "3.6",
        licenses: [
          { isDeprecatedLicenseId: false, name: 'Academic Free License v1.1' },
          { isDeprecatedLicenseId: false, name: 'MIT License' },
          { isDeprecatedLicenseId: true, name: 'GNU Affero General Public License v3.0' }
        ]
      }
    end

    let(:gateway) { instance_double(Gitlab::SPDX::CatalogueGateway, fetch: catalogue) }
    let(:catalogue) { described_class.new(catalogue_hash) }

    before do
      allow(Gitlab::SPDX::CatalogueGateway).to receive(:new).and_return(gateway)
    end

    subject(:latest_active_license_names) { described_class.latest_active_license_names }

    it 'returns only active licenses sorted by name' do
      expect(latest_active_license_names).to contain_exactly(academic.name, mit.name)
    end
  end
end
