# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:rake tasks', :silence_stdout, feature_category: :software_composition_analysis do
  before do
    Rake.application.rake_require 'tasks/gitlab/spdx'
  end

  describe 'import' do
    subject(:spdx_import) { run_rake_task 'gitlab:spdx:import' }

    let(:path) { Gitlab::SPDX::CatalogueGateway::OFFLINE_CATALOGUE_PATH }
    let(:data) { { license1: 'test', license2: 'test2' } }

    context 'with successful download of the catalogue' do
      before do
        stub_request(:get, Gitlab::SPDX::CatalogueGateway::ONLINE_CATALOGUE_URL).to_return(status: 200,
          body: data.to_json)
        allow(IO).to receive(:write)
        expect(IO).to receive(:write).with(path, anything, mode: 'w')
      end

      it 'saves the catalogue to the file' do
        expect { spdx_import }.to output("Local copy of SPDX catalogue is saved to #{path}\n").to_stdout
      end

      it 'deletes the software licenses from cache' do
        expect(Rails.cache).to receive(:delete).with(::Gitlab::SPDX::Catalogue::LATEST_ACTIVE_LICENSES_CACHE_KEY)

        spdx_import
      end
    end

    context 'when downloaded catalogue is broken' do
      before do
        stub_request(:get, Gitlab::SPDX::CatalogueGateway::ONLINE_CATALOGUE_URL).to_return(status: 200,
          body: data.inspect)
      end

      it 'raises parsing failure' do
        expect { spdx_import }.to output(/Import of SPDX catalogue failed: unexpected/).to_stdout
      end
    end

    context 'with network failure' do
      before do
        stub_request(:get, Gitlab::SPDX::CatalogueGateway::ONLINE_CATALOGUE_URL).to_return(status: 404)
      end

      it 'raises network failure error' do
        expect { spdx_import }.to output("Import of SPDX catalogue failed: Network failure\n").to_stdout
      end
    end
  end
end
