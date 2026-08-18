<script>
import { GlDrawer, GlButton, GlSkeletonLoader, GlToastMixin } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { DRAWER_FLASH_CONTAINER_CLASS } from '../../components/security_attributes/constants';
import getSecurityCategoriesAndAttributes from '../../graphql/group_security_categories_and_attributes.query.graphql';
import ProjectSecurityAttributesUpdateMutation from '../../graphql/project_security_attributes_update.mutation.graphql';
import ProjectAttributesUpdateForm from './project_attributes_update_form.vue';

const i18n = {
  updateSuccess: s__('SecurityAttributes|Successfully updated the security attributes'),
  addAndRemove: s__(
    'SecurityAttributes|Successfully added %{addedCount} and removed %{removedCount} security attributes',
  ),
  addOnly: s__('SecurityAttributes|Successfully added %{addedCount} security attributes'),
  removeOnly: s__('SecurityAttributes|Successfully removed %{removedCount} security attributes'),
};

export default {
  name: 'ProjectAttributesUpdateDrawer',
  components: {
    GlDrawer,
    GlButton,
    ProjectAttributesUpdateForm,
    GlSkeletonLoader,
  },
  mixins: [GlToastMixin],
  inject: ['groupFullPath'],
  props: {
    projectId: {
      type: String,
      required: true,
    },
    selectedAttributes: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['saved'],
  data() {
    return {
      group: {
        securityCategories: [],
      },
      isDrawerOpen: false,
      pendingAttributes: this.selectedAttributes.map((attr) => attr.id),
    };
  },
  apollo: {
    group: {
      query: getSecurityCategoriesAndAttributes,
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
    },
  },
  computed: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    saveAttributePayload() {
      const oldAttributesIds = new Set(this.selectedAttributes.map((attr) => attr.id));
      const newAttributesIds = new Set(this.pendingAttributes);

      return {
        addAttributeIds: Array.from(newAttributesIds).filter((id) => !oldAttributesIds.has(id)),
        removeAttributeIds: Array.from(oldAttributesIds).filter((id) => !newAttributesIds.has(id)),
      };
    },
    isFormDirty() {
      const { addAttributeIds, removeAttributeIds } = this.saveAttributePayload;
      return addAttributeIds.length > 0 || removeAttributeIds.length > 0;
    },
    filteredCategories() {
      if (this.group.securityCategories === null) {
        return [];
      }
      return this.group.securityCategories.filter(
        (category) => category.securityAttributes?.length > 0,
      );
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties
    openDrawer() {
      this.isDrawerOpen = true;
    },
    closeDrawer() {
      this.isDrawerOpen = false;
    },
    handleUpdate(attributes) {
      this.pendingAttributes = attributes;
    },
    formatToastMessage(addedCount, removedCount) {
      if (addedCount > 0 && removedCount > 0) {
        return sprintf(i18n.addAndRemove, { addedCount, removedCount });
      }
      if (addedCount > 0) {
        return sprintf(i18n.addOnly, { addedCount });
      }
      if (removedCount > 0) {
        return sprintf(i18n.removeOnly, { removedCount });
      }
      return i18n.updateSuccess;
    },
    updateAttributes() {
      const payload = this.saveAttributePayload;

      return this.$apollo
        .mutate({
          mutation: ProjectSecurityAttributesUpdateMutation,
          variables: {
            input: {
              projectId: this.projectId,
              ...payload,
            },
          },
        })
        .then((result) => {
          const { addedCount = 0, removedCount = 0 } =
            result.data.securityAttributeProjectUpdate || {};

          const toastMsg = this.formatToastMessage(addedCount, removedCount);

          this.$toast.show(toastMsg);
          this.$emit('saved');
          this.closeDrawer();
        })
        .catch((error) => {
          Sentry.captureException(error);
          createAlert({
            message: s__(
              'SecurityAttributes|An error has occurred while applying security attributes.',
            ),
            containerSelector: `.${DRAWER_FLASH_CONTAINER_CLASS}`,
          });
        });
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :open="isDrawerOpen"
    :header-height="getDrawerHeaderHeight"
    size="md"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="closeDrawer"
  >
    <template #title>
      <h4 class="gl-my-0 gl-mr-3 gl-text-size-h2">
        {{ s__('SecurityAttributes|Edit project security attributes') }}
      </h4>
    </template>

    <project-attributes-update-form
      v-if="!$apollo.queries.group.loading"
      :categories="group.securityCategories"
      :filtered-categories="filteredCategories"
      :selected-attributes="selectedAttributes"
      @update="handleUpdate"
    />
    <gl-skeleton-loader v-else :height="200" :width="400" />

    <template #footer>
      <div v-if="filteredCategories.length" class="gl-display-flex gl-gap-3">
        <gl-button
          category="primary"
          variant="confirm"
          data-testid="submit-btn"
          :disabled="!isFormDirty"
          @click="updateAttributes"
        >
          {{ __('Save changes') }}
        </gl-button>
        <gl-button data-testid="cancel-btn" class="gl-ml-2" @click="closeDrawer">
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </template>
  </gl-drawer>
</template>
