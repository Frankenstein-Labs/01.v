# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::KotlinGradle, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('kotlin')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~CONTENT
        buildscript {
            repositories {
                google()
                mavenCentral()
            }
        }

        val arcgisVersion = "4.5.0"
        val kotlinVersion = file("../kotlin-dsl/$kotlinVersionSourceFilePath").readLines().extractKotlinVersion()
        val libName = "test-lib-with-val"

        dependencies { // Comment
            implementation("org.codehaus.groovy:groovy:3.+")
            testImplementation("com.google.guava:guava:29.0.1") // Inline comment

            implementation(project(":utils"))
            runtimeOnly(files("libs/a.jar", "libs/b.jar"))

            implementation("com.esri.arcgisruntime:arcgis-java:$arcgisVersion")
            implementation("org.jetbrains.kotlin:kotlin-reflect:$kotlinVersion")

            implementation("org.jetbrains.kotlin:$libName:2.0.0")
        }

        java {
            withSourcesJar()
        }
      CONTENT
    end

    let(:expected_formatted_lib_names) do
      [
        'groovy (3.+)',
        'guava (29.0.1)',
        'arcgis-java (4.5.0)',
        'kotlin-reflect',
        'test-lib-with-val (2.0.0)'
      ]
    end
  end

  it_behaves_like 'parsing an invalid dependency config file'

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'build.gradle.kts'            | true
      'dir/build.gradle.kts'        | true
      'dir/subdir/build.gradle.kts' | true
      'dir/build.gradle'            | false
      'xbuild.gradle.kts'           | false
      'Build.gradle.kts'            | false
      'build_gradle_kts'            | false
      'build.gradle'                | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
