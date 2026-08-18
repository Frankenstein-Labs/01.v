<script>
import { GlDrawer, GlButton } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { DRAWER_MODES } from './constants';
import SecurityAttributeForm from './attribute_form.vue';

export default {
  name: 'AttributeDrawer',
  components: {
    GlDrawer,
    GlButton,
    SecurityAttributeForm,
  },
  emits: ['delete-attribute', 'save-attribute'],
  DRAWER_Z_INDEX,
  i18n: {
    addAttributeTitle: s__('SecurityAttributes|Add security attribute'),
    editAttributeTitle: s__('SecurityAttributes|Edit security attribute'),
    updateAttributeButton: s__('SecurityAttributes|Update attribute'),
    createAttributeButton: s__('SecurityAttributes|Add attribute'),
    cancelButton: s__('SecurityAttributes|Cancel'),
    deleteButton: s__('SecurityAttributes|Delete'),
  },
  data() {
    return {
      isOpen: false,
      mode: DRAWER_MODES.ADD,
      attribute: {},
    };
  },
  computed: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    drawerTitle() {
      return this.mode === DRAWER_MODES.EDIT
        ? this.$options.i18n.editAttributeTitle
        : this.$options.i18n.addAttributeTitle;
    },
    primaryButtonText() {
      return this.mode === DRAWER_MODES.EDIT
        ? this.$options.i18n.updateAttributeButton
        : this.$options.i18n.createAttributeButton;
    },
    secondaryButtonText() {
      return this.$options.i18n.cancelButton;
    },
    deleteButtonText() {
      return this.$options.i18n.deleteButton;
    },
    isAddMode() {
      return this.mode === DRAWER_MODES.ADD;
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- `open()` is called from the parent component
    open(mode = DRAWER_MODES.ADD, attribute = {}) {
      this.attribute = attribute;
      this.mode = mode;
      this.isOpen = true;
    },
    close() {
      this.isOpen = false;
    },
    onSubmit(payload) {
      this.$emit('save-attribute', {
        id: this.attribute.id,
        ...payload,
      });
      this.close();
    },
    onDelete() {
      this.$emit('delete-attribute', this.attribute);
      this.close();
    },
  },
  DRAWER_MODES,
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :header-sticky="true"
    :open="isOpen"
    size="md"
    class="security-attribute-form-drawer"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="close"
  >
    <template #title>
      <h4 class="gl-my-0 gl-mr-3 gl-text-size-h2">{{ drawerTitle }}</h4>
    </template>

    <security-attribute-form
      ref="form"
      :key="attribute.id || 'new'"
      :attribute="attribute"
      :mode="mode"
      @saved="onSubmit"
      @cancel="close"
    />

    <template #footer>
      <div class="gl-align-items-center gl-flex !gl-flex-auto gl-justify-between">
        <div class="gl-display-flex gl-gap-3">
          <gl-button
            category="primary"
            variant="confirm"
            data-testid="submit-btn"
            @click="$refs.form.onSubmit()"
          >
            {{ primaryButtonText }}
          </gl-button>
          <gl-button data-testid="cancel-btn" class="gl-ml-2" @click="close">
            {{ secondaryButtonText }}
          </gl-button>
        </div>

        <gl-button
          v-if="!isAddMode"
          category="primary"
          variant="danger"
          data-testid="delete-btn"
          @click="onDelete"
        >
          {{ deleteButtonText }}
        </gl-button>
      </div>
    </template>
  </gl-drawer>
</template>
