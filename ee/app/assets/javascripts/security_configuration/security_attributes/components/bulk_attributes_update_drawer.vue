<script>
import {
  GlDrawer,
  GlButton,
  GlSkeletonLoader,
  GlSprintf,
  GlFormGroup,
  GlFormRadioGroup,
  GlFormRadio,
  GlToastMixin,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import {
  DRAWER_FLASH_CONTAINER_CLASS,
  BULK_EDIT_ADD,
  BULK_EDIT_REMOVE,
  BULK_EDIT_REPLACE,
} from '../../components/security_attributes/constants';
import getSecurityCategoriesAndAttributes from '../../graphql/group_security_categories_and_attributes.query.graphql';
import BulkUpdateSecurityAttributesMutation from '../../graphql/bulk_update_security_attributes.mutation.graphql';
import { updateSecurityAttributesCache } from '../graphql/cache_utils';
import ProjectAttributesUpdateForm from './project_attributes_update_form.vue';

export default {
  name: 'BulkAttributesUpdateDrawer',
  components: {
    GlDrawer,
    GlButton,
    ProjectAttributesUpdateForm,
    GlSkeletonLoader,
    GlSprintf,
    GlFormGroup,
    GlFormRadioGroup,
    GlFormRadio,
  },
  mixins: [GlToastMixin],
  inject: ['groupFullPath'],
  props: {
    itemIds: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['refetch'],
  data() {
    return {
      group: {
        securityCategories: [],
      },
      isDrawerOpen: false,
      pendingAttributes: [],
      updateMethod: null,
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
    isFormValid() {
      return Boolean(this.updateMethod) && Boolean(this.pendingAttributes.length);
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
      this.updateMethod = null;
      this.pendingAttributes = [];
    },
    handleUpdate(attributes) {
      this.pendingAttributes = attributes;
    },
    updateAttributes() {
      const input = {
        items: this.itemIds,
        mode: this.updateMethod,
        attributes: this.pendingAttributes,
      };
      return this.$apollo
        .mutate({
          mutation: BulkUpdateSecurityAttributesMutation,
          variables: {
            input,
          },
          update: updateSecurityAttributesCache(input, this.group.securityCategories),
        })
        .then(() => {
          this.$toast.show(
            s__('SecurityAttributes|Updating security attributes in the background'),
          );
          this.closeDrawer();
        })
        .catch((error) => {
          this.$emit('refetch');
          Sentry.captureException(error);
          createAlert({
            message: s__(
              'SecurityAttributes|An error has occurred while bulk editing security attributes.',
            ),
            containerSelector: `.${DRAWER_FLASH_CONTAINER_CLASS}`,
          });
        });
    },
  },
  DRAWER_Z_INDEX,
  BULK_EDIT_ADD,
  BULK_EDIT_REMOVE,
  BULK_EDIT_REPLACE,
  EMPTY_ARRAY: [],
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
        <gl-sprintf
          :message="
            n__(
              'SecurityAttributes|Edit security attributes for %d item',
              'SecurityAttributes|Edit security attributes for %d items',
              itemIds.length,
            )
          "
        >
          <template #itemCount>{{ itemIds.length }}</template>
        </gl-sprintf>
      </h4>
    </template>

    <h5 class="gl-mb-0 gl-text-size-h2">{{ __('Update method') }}</h5>
    <gl-form-group>
      <template #label>
        {{ __('Bulk update behavior') }}
      </template>
      <p>{{ __('Choose how to apply the selected attributes to your projects.') }}</p>
      <gl-form-radio-group v-model="updateMethod">
        <gl-form-radio :value="$options.BULK_EDIT_ADD">
          {{ __('Add attributes') }}
          <template #help>
            {{ __('Apply selected attributes to projects (keeps existing attributes)') }}
          </template>
        </gl-form-radio>
        <gl-form-radio :value="$options.BULK_EDIT_REMOVE">
          {{ __('Remove attributes') }}
          <template #help>
            {{ __('Remove selected attributes from projects') }}
          </template>
        </gl-form-radio>
        <gl-form-radio :value="$options.BULK_EDIT_REPLACE">
          {{ __('Replace all attributes') }}
          <template #help>
            {{ __('Remove all existing attributes and apply only the selected ones') }}
          </template>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>

    <h5 class="gl-mb-0 !gl-py-0 gl-text-size-h2">{{ __('Attributes') }}</h5>
    <project-attributes-update-form
      v-if="!$apollo.queries.group.loading"
      :categories="group.securityCategories"
      :filtered-categories="filteredCategories"
      :selected-attributes="$options.EMPTY_ARRAY"
      @update="handleUpdate"
    />
    <gl-skeleton-loader v-else :height="200" :width="400" />

    <template #footer>
      <div v-if="filteredCategories.length" class="gl-display-flex gl-gap-3">
        <gl-button
          category="primary"
          variant="confirm"
          data-testid="submit-btn"
          :disabled="!isFormValid"
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
