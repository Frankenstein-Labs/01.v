# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::JavaGradle, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('java')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~CONTENT
        group = 'com.github.jitpack'
        version = '2.0'

        sourceCompatibility = 1.8 // java 8
        targetCompatibility = 1.8

        repositories {
            mavenCentral()
        }

        ext {
            arcgisVersion = '4.5.0'
            libName = 'test-lib'
        }

        dependencies { // Comment
            implementation 'org.codehaus.groovy:groovy:3.+'
            testImplementation "com.google.guava:guava:29.0.1" // Inline comment
            "implementation" 'org.ow2.asm:asm:9.6'

            implementation group: "org.neo4j", name: "neo4j-jmx", version: "1.3"
            testImplementation group: 'junit', name: 'junit', version: '4.11'
            "testImplementation" group: "org.apache.ant", name: "ant", version: "1.10.14"

            implementation project(':utils')
            runtimeOnly files('libs/a.jar', 'libs/b.jar')

            implementation "com.esri.arcgisruntime:arcgis-java:$arcgisVersion"
            implementation "com.esri.arcgisruntime:$libName:2.0.0"
        }

        license {
            exclude 'net/abc/gradle/common/diff/'
            exclude 'net/abc/gradle/common/util/JavaVersionParser.java'
        }
      CONTENT
    end

    let(:expected_formatted_lib_names) do
      [
        'groovy (3.+)',
        'guava (29.0.1)',
        'asm (9.6)',
        'neo4j-jmx (1.3)',
        'junit (4.11)',
        'ant (1.10.14)',
        'arcgis-java (4.5.0)',
        'test-lib (2.0.0)'
      ]
    end
  end

  it_behaves_like 'parsing an invalid dependency config file'

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'build.gradle'            | true
      'dir/build.gradle'        | true
      'dir/subdir/build.gradle' | true
      'dir/build'               | false
      'xbuild.gradle'           | false
      'Build.gradle'            | false
      'build_gradle'            | false
      'build'                   | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
