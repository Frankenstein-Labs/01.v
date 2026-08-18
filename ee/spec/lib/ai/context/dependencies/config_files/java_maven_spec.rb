# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::JavaMaven, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('java')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~CONTENT
      <project>
          <modelVersion>4.0.0</modelVersion>

          <groupId>com.example.application</groupId>
          <artifactId>my-application</artifactId>
          <version>1.0</version>

          <dependencies>
              <dependency>
                  <groupId>org.junit.jupiter</groupId>
                  <artifactId>junit-jupiter-engine</artifactId>
                  <version>1.2.0</version>
              </dependency>
              <dependency>
                  <groupId>net.authorize</groupId>
                  <artifactId>anet-java-sdk</artifactId>
                  <version>2.0.5</version>
              </dependency>
          </dependencies>
      </project>
      CONTENT
    end

    let(:expected_formatted_lib_names) { ['junit-jupiter-engine (1.2.0)', 'anet-java-sdk (2.0.5)'] }
  end

  context 'when the XML doc contains only one dependency' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:config_file_content) do
        <<~CONTENT
        <project>
            <modelVersion>4.0.0</modelVersion>

            <groupId>com.example.application</groupId>
            <artifactId>my-application</artifactId>
            <version>1.0</version>

            <dependencies>
                <dependency>
                    <groupId>org.junit.jupiter</groupId>
                    <artifactId>junit-jupiter-engine</artifactId>
                    <version>1.2.0</version>
                </dependency>
            </dependencies>
        </project>
        CONTENT
      end

      let(:expected_formatted_lib_names) { ['junit-jupiter-engine (1.2.0)'] }
    end
  end

  context 'when the XML doc specifies encoding and namespace' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:config_file_content) do
        <<~CONTENT
        <?xml version="1.0" encoding="UTF-8"?>
        <project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">

            <dependencies>
                <dependency>
                    <groupId>org.junit.jupiter</groupId>
                    <artifactId>junit-jupiter-engine</artifactId>
                    <version>1.2.0</version>
                </dependency>
                <dependency>
                    <groupId>net.authorize</groupId>
                    <artifactId>anet-java-sdk</artifactId>
                    <version>2.0.5</version>
                </dependency>
            </dependencies>
        </project>
        CONTENT
      end

      let(:expected_formatted_lib_names) { ['junit-jupiter-engine (1.2.0)', 'anet-java-sdk (2.0.5)'] }
    end
  end

  it_behaves_like 'parsing an invalid dependency config file' do
    let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
    let(:expected_error_message) { 'content is not valid XML' }
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'pom.xml'            | true
      'dir/pom.xml'        | true
      'dir/subdir/pom.xml' | true
      'dir/pom'            | false
      'xpom.xml'           | false
      'Pom.xml'            | false
      'pom_xml'            | false
      'pom'                | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
