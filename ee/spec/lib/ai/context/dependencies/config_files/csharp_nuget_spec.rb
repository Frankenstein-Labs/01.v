# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::CsharpNuget, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('csharp')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~CONTENT
        <Project Sdk="Microsoft.NET.Sdk">
          <PropertyGroup>
            <OutputType>Exe</OutputType>
            <TargetFramework>net8.0</TargetFramework>
            <Nullable>enable</Nullable>
          </PropertyGroup>

          <ItemGroup>
            <PackageReference Include="Microsoft.Extensions.Hosting" Version="6.0.1" />
            <PackageReference Include="MessagePack" />
            <PackageReference Include="Microsoft.EntityFrameworkCore.Design">
              <PrivateAssets>all</PrivateAssets>
            </PackageReference>
            <PackageReference Include="Sentry" Version="5.3.1" PrivateAssets="All" />
          </ItemGroup>

          <ItemGroup>
            <ProjectReference Include="..local/.Date.csproj" />
          </ItemGroup>

          <ItemGroup>
            <None Include="artifacts-icon.png" Pack="true" />
            <None Include="README.md" Pack="true" />
          </ItemGroup>
        </Project>
      CONTENT
    end

    let(:expected_formatted_lib_names) do
      [
        'Microsoft.Extensions.Hosting (6.0.1)',
        'MessagePack',
        'Microsoft.EntityFrameworkCore.Design',
        'Sentry (5.3.1)'
      ]
    end
  end

  context 'when the XML doc specifies encoding and namespace' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:config_file_content) do
        <<~CONTENT
          <?xml version="1.0" encoding="UTF-8"?>
          <Project xmlns="http://my.namespace/4.1.0" Sdk="Microsoft.NET.Sdk">
            <PropertyGroup>
              <OutputType>Exe</OutputType>
              <TargetFramework>net8.0</TargetFramework>
              <Nullable>enable</Nullable>
            </PropertyGroup>

            <ItemGroup>
              <PackageReference Include="Sentry" Version="5.3.1" PrivateAssets="All" />
            </ItemGroup>
          </Project>
        CONTENT
      end

      let(:expected_formatted_lib_names) { ['Sentry (5.3.1)'] }
    end
  end

  it_behaves_like 'parsing an invalid dependency config file' do
    let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
    let(:expected_error_message) { 'content is not valid XML' }
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'my_proj.csproj'            | true
      'dir/MyProj.csproj'         | true
      'dir/subdir/Project.csproj' | true
      'dir/csproj'                | false
      'myproj.Csproj'             | false
      'myproj_csproj'             | false
      'csproj'                    | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
