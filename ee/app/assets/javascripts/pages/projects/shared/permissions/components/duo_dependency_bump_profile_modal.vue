<script>
import { GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'DuoDependencyBumpProfileModal',
  components: {
    GlModal,
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['confirm', 'cancel', 'hide'],
  computed: {
    primaryAction() {
      return {
        text: s__('DuoDependencyBump|Turn on dependency version bumps'),
        attributes: { variant: 'confirm', loading: this.isLoading },
      };
    },
    cancelAction() {
      return {
        text: s__('DuoDependencyBump|Turn on without enabling dependency version bumps'),
        attributes: { disabled: this.isLoading },
      };
    },
  },
  methods: {
    onPrimary() {
      this.$emit('confirm');
    },
    onCancel() {
      this.$emit('cancel');
    },
    onHide() {
      this.$emit('hide');
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    modal-id="duo-dependency-bump-profile-modal"
    :title="s__('DuoDependencyBump|Turn on dependency version bumps')"
    :action-primary="primaryAction"
    :action-cancel="cancelAction"
    data-testid="duo-dependency-bump-profile-modal"
    @primary="onPrimary"
    @cancel="onCancel"
    @hide="onHide"
  >
    <p>
      {{
        s__(
          'DuoDependencyBump|Dependency version bumping is not turned on for this project. This feature works together with Agentic Breaking Change Resolution to automatically open merge requests that fix vulnerable dependencies.',
        )
      }}
    </p>
    <p class="gl-mb-0">
      {{
        s__(
          'DuoDependencyBump|Would you like to turn on dependency version bumping now? You can also turn on Agentic Breaking Change Resolution without enabling the profile.',
        )
      }}
    </p>
  </gl-modal>
</template>
