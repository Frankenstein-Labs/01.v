# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::DependencyLicenseListEntity, feature_category: :dependency_management do
  let(:licenses) do
    [
      {
        'spdx_identifier' => 'Apache-2.0',
        'name' => 'Apache 2.0 License',
        'url' => 'https://spdx.org/licenses/Apache-2.0.html'
      },
      {
        'spdx_identifier' => 'MIT',
        'name' => 'MIT License',
        'url' => 'https://spdx.org/licenses/MIT.html'
      },
      {
        'spdx_identifier' => 'MPL-2.0',
        'name' => 'Mozilla Public License 2.0',
        'url' => 'https://spdx.org/licenses/MPL-2.0.html'
      }
    ]
  end

  subject { described_class.represent(licenses).as_json }

  it 'has a list of licenses' do
    expect(subject).to include(:licenses)
    expect(subject[:licenses]).to eq([
      {
        spdx_identifier: 'Apache-2.0',
        name: 'Apache 2.0 License',
        url: 'https://spdx.org/licenses/Apache-2.0.html'
      },
      {
        spdx_identifier: 'MIT',
        name: 'MIT License',
        url: 'https://spdx.org/licenses/MIT.html'
      },
      {
        spdx_identifier: 'MPL-2.0',
        name: 'Mozilla Public License 2.0',
        url: 'https://spdx.org/licenses/MPL-2.0.html'
      }
    ])
  end
end
