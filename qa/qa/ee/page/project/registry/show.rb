# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Registry
          module Show
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                view 'ee/app/assets/javascripts/packages_and_registries/container_registry/explorer/components/' \
                  'list_page/container_scanning_counts.vue' do
                  element 'counts'
                end
              end
            end

            def has_non_zero_counts?
              within_element('counts') do
                has_text?(%r{\b[1-9]\d*\s+critical\b}) ||
                  has_text?(%r{\b[1-9]\d*\s+high\b}) ||
                  has_text?(%r{\b[1-9]\d*\s+other\b})
              end
            end
          end
        end
      end
    end
  end
end
