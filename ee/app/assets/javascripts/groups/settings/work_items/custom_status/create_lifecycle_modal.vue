<script>
import {
  GlModal,
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlSearchBoxByType,
  GlFormRadioGroup,
  GlFormRadio,
  GlLoadingIcon,
  GlAlert,
  GlToastMixin,
} from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ScrollScrim from '~/super_sidebar/components/scroll_scrim.vue';
import LifecycleDetail from './lifecycle_detail.vue';
import namespaceStatusesQuery from './graphql/namespace_lifecycles.query.graphql';
import namespaceDefaultLifecycleTemplatesQuery from './graphql/namespace_default_lifecycle_template.query.graphql';
import createLifecycleMutation from './graphql/create_lifecycle.mutation.graphql';

export default {
  name: 'CreateLifecycle',
  components: {
    GlModal,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    LifecycleDetail,
    GlSearchBoxByType,
    GlFormRadioGroup,
    GlFormRadio,
    GlLoadingIcon,
    GlAlert,
    ScrollScrim,
  },
  mixins: [GlToastMixin],
  i18n: {
    createLifecycle: s__('WorkItem|Create lifecycle'),
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  emits: ['close', 'lifecycle-created'],
  data() {
    return {
      errorMessage: '',
      searchTerm: '',
      lifecycles: [],
      lifecycleTemplate: {},
      formData: {
        name: '',
        selectedLifecycleId: null,
      },
      formError: '',
      isSubmitting: false,
    };
  },
  apollo: {
    lifecycles: {
      query: namespaceStatusesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      skip() {
        return !this.visible;
      },
      update(data) {
        return data.namespace?.lifecycles?.nodes || [];
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load statuses.');
        Sentry.captureException(error);
      },
    },
    lifecycleTemplate: {
      query: namespaceDefaultLifecycleTemplatesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        const template = data.namespace?.lifecycleTemplates[0] || {};
        if (template.id && !this.formData.selectedLifecycleId) {
          this.formData.selectedLifecycleId = template.id;
        }
        return template;
      },
      skip() {
        return !this.visible;
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load default lifecycle');
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    fetchingLifecycles() {
      return this.$apollo.queries.lifecycles.loading;
    },
    fetchingLifecycleTemplate() {
      return this.$apollo.queries.lifecycleTemplate.loading;
    },
    filteredLifecycles() {
      if (this.searchTerm) {
        return fuzzaldrinPlus.filter(this.lifecycles, this.searchTerm, {
          key: ['name'],
        });
      }
      return this.lifecycles;
    },
    allLifecycles() {
      return [this.lifecycleTemplate, ...this.lifecycles];
    },
    selectedLifecycle() {
      return (
        this.allLifecycles.find(
          (lifecycle) => this.formData.selectedLifecycleId === lifecycle.id,
        ) || {}
      );
    },
    selectedLifecycleStatuses() {
      return this.selectedLifecycle.statuses;
    },
    selectedLifecycleStatusesWithIds() {
      return this.selectedLifecycleStatuses.map((status) => ({
        id: status.id,
      }));
    },
    selectedLifecycleStatusNames() {
      return this.selectedLifecycleStatuses.map((status) => ({
        name: status?.name,
        category: status?.category.toUpperCase(),
        color: status?.color,
      }));
    },
    showLoadingIndicator() {
      return this.fetchingLifecycleTemplate || this.fetchingLifecycles;
    },
    isLifecycleTemplateSelected() {
      return this.formData.selectedLifecycleId === this.lifecycleTemplate.id;
    },
  },
  methods: {
    closeAndResetData() {
      this.$emit('close');
      this.resetFormData();
    },
    closeModal() {
      this.closeAndResetData();
    },
    resetFormData() {
      this.formData = {
        selectedLifecycleId: this.lifecycleTemplate.id,
        name: '',
      };
      this.searchTerm = '';
      this.errorMessage = '';
      this.formError = '';
    },
    validate() {
      if (!this.formData.name) {
        this.formError = s__('WorkItem|Please provide a name for the lifecycle.');
        return false;
      }
      this.formError = '';
      return true;
    },
    async onSubmit() {
      if (!this.validate()) {
        return;
      }

      this.isSubmitting = true;

      try {
        const { defaultOpenStatus, defaultClosedStatus, defaultDuplicateStatus } =
          this.selectedLifecycle;

        const defaultOpenStatusIndex = this.selectedLifecycleStatuses.findIndex(
          (s) => s.id === defaultOpenStatus.id,
        );
        const defaultClosedStatusIndex = this.selectedLifecycleStatuses.findIndex(
          (s) => s.id === defaultClosedStatus.id,
        );
        const defaultDuplicateStatusIndex = this.selectedLifecycleStatuses.findIndex(
          (s) => s.id === defaultDuplicateStatus.id,
        );

        const { data } = await this.$apollo.mutate({
          mutation: createLifecycleMutation,
          variables: {
            input: {
              namespacePath: this.fullPath,
              name: this.formData.name,
              statuses: this.isLifecycleTemplateSelected
                ? this.selectedLifecycleStatusNames
                : this.selectedLifecycleStatusesWithIds,
              defaultOpenStatusIndex: Math.max(0, defaultOpenStatusIndex),
              defaultClosedStatusIndex: Math.max(0, defaultClosedStatusIndex),
              defaultDuplicateStatusIndex: Math.max(0, defaultDuplicateStatusIndex),
            },
          },
        });

        if (data?.lifecycleCreate?.errors?.length) {
          throw new Error(data.lifecycleCreate.errors.join(', '));
        }

        this.$emit('lifecycle-created', data.lifecycleCreate.lifecycle.id);
        this.$toast.show(s__('WorkItem|Lifecycle created.'));
        this.closeAndResetData();
      } catch (error) {
        Sentry.captureException(error);
        this.errorMessage = error.message;
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    :title="$options.i18n.createLifecycle"
    scrollable
    modal-id="create-lifecycle-modal"
    @close="closeModal"
    @hide="closeModal"
  >
    <gl-alert
      v-if="errorMessage"
      variant="danger"
      class="gl-sticky gl-top-0 gl-my-5"
      data-testid="error-alert"
      @dismiss="errorMessage = ''"
    >
      {{ errorMessage }}
    </gl-alert>
    <p>
      {{
        s__(
          'WorkItem|Creating a lifecycle will not effect existing items. Change the lifecycle associated with an item type to use this new lifecycle.',
        )
      }}
    </p>

    <gl-form>
      <gl-form-group
        :label="s__('WorkItem|Lifecycle name')"
        :invalid-feedback="formError"
        label-size="sm"
        label-for="new-lifecycle-name"
        :state="!formError"
      >
        <gl-form-input
          id="new-lifecycle-name"
          v-model="formData.name"
          class="gl-w-34"
          data-testid="new-lifecycle-name-field"
          :state="!formError"
          @input="validate"
        />
      </gl-form-group>

      <h3 class="gl-mb-0 gl-mt-6 gl-text-base">{{ s__('WorkItem|Starting statuses') }}</h3>
      <p>
        {{
          s__(
            'WorkItem|Select a set of statuses to start from. You can edit statuses once the lifecycle created.',
          )
        }}
      </p>

      <div v-if="showLoadingIndicator">
        <gl-loading-icon size="lg" class="gl-p-4" />
      </div>
      <div v-else>
        <gl-form-radio-group v-model="formData.selectedLifecycleId" name="create-lifecycle-radio">
          <div class="gl-mb-3 gl-mt-5 gl-text-subtle">
            {{ s__('WorkItem|Start from a default configuration') }}
          </div>

          <div class="gl-border gl-rounded-lg gl-border-strong gl-bg-strong gl-p-4">
            <lifecycle-detail
              :lifecycle="lifecycleTemplate"
              :full-path="fullPath"
              :class="{
                'gl-border-blue-500': isLifecycleTemplateSelected,
              }"
              :show-usage-section="false"
              :show-not-in-use-section="false"
              is-lifecycle-template
              show-radio-selection
            >
              <template #radio-selection>
                <gl-form-radio :key="lifecycleTemplate.id" :value="lifecycleTemplate.id">
                  <span class="gl-font-bold">{{ s__('WorkItem|Default statuses') }}</span>
                </gl-form-radio>
              </template>
            </lifecycle-detail>
          </div>

          <div class="gl-mb-3 gl-mt-5 gl-text-subtle">
            {{ s__('WorkItem|Copy from existing lifecycle') }}
          </div>

          <div class="gl-border gl-rounded-lg gl-border-strong gl-bg-strong gl-p-4">
            <div class="gl-pb-3">
              <gl-search-box-by-type
                v-model="searchTerm"
                class="gl-w-34"
                :clear-button-title="__('Clear')"
                :placeholder="s__('WorkItem|Search lifecycles')"
              />
            </div>
            <div v-if="filteredLifecycles.length" class="gl-flex gl-max-h-31 gl-overflow-y-auto">
              <scroll-scrim class="gl-grow">
                <div class="gl-flex gl-flex-col gl-gap-4">
                  <lifecycle-detail
                    v-for="lifecycle in filteredLifecycles"
                    :key="lifecycle.id"
                    :full-path="fullPath"
                    :class="{
                      'gl-border-blue-500': formData.selectedLifecycleId === lifecycle.id,
                    }"
                    :lifecycle="lifecycle"
                    show-radio-selection
                    show-not-in-use-section
                    :show-usage-section="false"
                    :show-remove-lifecycle-button="false"
                  >
                    <template #radio-selection>
                      <gl-form-radio :key="lifecycle.id" :value="lifecycle.id">
                        <span class="gl-font-bold">{{ lifecycle.name }}</span>
                      </gl-form-radio>
                    </template>
                  </lifecycle-detail>
                </div>
              </scroll-scrim>
            </div>
            <div v-else class="gl-my-7 gl-text-center gl-text-subtle">
              {{ s__('WorkItem|No matching lifecycles.') }}
            </div>
          </div>
        </gl-form-radio-group>
      </div>
    </gl-form>

    <template #modal-footer>
      <gl-button data-testid="cancel-create-lifecycle" @click="closeModal">{{
        __('Cancel')
      }}</gl-button>
      <gl-button
        data-testid="create-lifecycle"
        variant="confirm"
        :disabled="isSubmitting"
        @click="onSubmit"
        >{{ __('Create') }}</gl-button
      >
    </template>
  </gl-modal>
</template>
