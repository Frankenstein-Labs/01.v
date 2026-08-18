# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Secure
          class DependencyList < QA::Page::Base
            view 'ee/app/assets/javascripts/dependencies/components/dependencies_table.vue' do
              element 'dependencies-table-content'
            end

            view 'ee/app/assets/javascripts/dependencies/components/app.vue' do
              element 'dependency-list-empty-state-description-content'
            end

            def has_dependency_count_of?(expected)
              # SBOM ingestion can lag behind pipeline completion, so poll
              # (with page reloads) until the expected rows appear
              wait_until(
                max_duration: 30,
                sleep_interval: 5,
                raise_on_failure: false,
                message: "Waiting for #{expected} dependencies to be ingested"
              ) do
                next false unless has_element?('dependencies-table-content', wait: 1)

                # count body rows only; the header row is hidden when the
                # table collapses to its stacked layout (container < md)
                within_element('dependencies-table-content') { all('tbody > tr').count == expected }
              end
            end

            def has_empty_state_description?(text)
              within_element('dependency-list-empty-state-description-content') do
                has_text?(text)
              end
            end
          end
        end
      end
    end
  end
end
