# frozen_string_literal: true

module EE
  module Issuable # rubocop:disable Gitlab/BoundedContexts -- existing module we need for looking up callback classes
    module Callbacks
      module Labels
        extend ::Gitlab::Utils::Override

        private

        override :compute_new_label_ids
        def compute_new_label_ids
          @label_ids_ordered_by_selection = params[:add_label_ids].to_a + params[:label_ids].to_a # rubocop:disable Gitlab/ModuleWithInstanceVariables -- only used within this module

          filter_mutually_exclusive_labels(super)
        end

        def filter_mutually_exclusive_labels(new_label_ids)
          return new_label_ids unless issuable.resource_parent.licensed_feature_available?(:scoped_labels)

          added_label_ids = new_label_ids - issuable.label_ids
          return new_label_ids if added_label_ids.empty?

          label_sets = ScopedLabelSet.from_label_ids(new_label_ids)

          label_sets.flat_map do |set|
            if set.valid? || !set.contains_any?(added_label_ids)
              set.label_ids
            elsif issuable.supports_lock_on_merge? && set.lock_on_merge_labels?
              set.label_ids - added_label_ids
            else
              set.last_id_by_order(@label_ids_ordered_by_selection) # rubocop:disable Gitlab/ModuleWithInstanceVariables -- only used within this module
            end
          end
        end
      end
    end
  end
end
