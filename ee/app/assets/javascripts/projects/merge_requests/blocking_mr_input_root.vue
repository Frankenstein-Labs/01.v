<script>
import { ENTER_KEY, TAB_KEY } from '~/lib/utils/keys';
import RelatedIssuableInput from '~/related_issues/components/related_issuable_input.vue';
import { TYPE_MERGE_REQUEST } from '~/issues/constants';

export default {
  name: 'BlockingMrInputRoot',
  TYPE_MERGE_REQUEST,
  components: {
    RelatedIssuableInput,
  },
  props: {
    existingRefs: {
      type: Array,
      required: false,
      default: () => [],
    },
    containsHiddenBlockingMrs: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      references: this.existingRefs,
      inputValue: '',
      shouldRemoveHiddenBlockingMrs: false,
      hasFieldBeenTouched: false,
    };
  },
  methods: {
    onAddIssuable({ untouchedRawReferences, touchedReference }) {
      this.hasFieldBeenTouched = true;
      this.setReferences(this.references.concat(untouchedRawReferences));
      this.inputValue = touchedReference;
    },
    setReferences(refs) {
      // Remove duplicates but retain order.
      // If you don't do this, Vue will be confused by duplicates and refuse to delete them all.
      this.references = refs.filter((ref, idx) => refs.indexOf(ref) === idx);
    },
    removeReference(idToRemove) {
      this.hasFieldBeenTouched = true;
      // With this `if` statement we should only ever have to actually check the `includes` statement once.
      if (
        this.containsHiddenBlockingMrs &&
        !this.shouldRemoveHiddenBlockingMrs &&
        this.references[idToRemove].isHiddenRef
      ) {
        this.shouldRemoveHiddenBlockingMrs = true;
      }

      this.references.splice(idToRemove, 1);
    },
    onBlur(val) {
      if (val) {
        this.setReferences(this.references.concat(val));
        this.inputValue = '';
      }
    },
    onKeyFinish({ value, event }) {
      const isTab = event.key === TAB_KEY;
      const isEnter = event.key === ENTER_KEY;
      const isUnmodifiedEnter = isEnter && !(event.metaKey || event.ctrlKey);

      if (isTab || isUnmodifiedEnter) {
        event.preventDefault();
        event.stopPropagation();

        this.onBlur(value);
      }
    },
  },
};
</script>

<template>
  <div>
    <related-issuable-input
      path-id-separator="!"
      input-id="merge_request_blocking_merge_request_references"
      :references="references"
      :input-value="inputValue"
      :issuable-type="$options.TYPE_MERGE_REQUEST"
      @add-issuable-form-input="onAddIssuable"
      @pending-issuable-remove-request="removeReference"
      @add-issuable-form-blur="onBlur"
      @add-issuable-finish-entry="onKeyFinish"
    />
    <input
      v-for="ref in references"
      :key="ref"
      :value="ref"
      type="hidden"
      name="merge_request[blocking_merge_request_references][]"
    />
    <input
      v-if="containsHiddenBlockingMrs"
      type="hidden"
      name="merge_request[remove_hidden_blocking_merge_requests]"
      :value="shouldRemoveHiddenBlockingMrs"
    />
    <input
      type="hidden"
      name="merge_request[update_blocking_merge_request_refs]"
      :value="hasFieldBeenTouched"
    />
  </div>
</template>
