<script>
import { GlAlert, GlSprintf, GlLink, GlToastMixin } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { getRegistryItem } from '../item_type_registry';
import { canEditAiCatalogItem } from '../permissions';

export default {
  name: 'AiCatalogItemEdit',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
    PageHeading,
  },
  mixins: [GlToastMixin],
  props: {
    aiCatalogItem: {
      type: Object,
      required: true,
    },
    version: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      errors: [],
      isSubmitting: false,
    };
  },
  computed: {
    itemType() {
      return this.aiCatalogItem.itemType;
    },
    itemRegistry() {
      return getRegistryItem(this.itemType);
    },
    editConfig() {
      return this.itemRegistry.edit;
    },
    formComponent() {
      return this.itemRegistry.formComponent;
    },
    // We compute whether to show the "editing latest version" warning because editing a pinned
    // version would result in version content becoming mis-aligned with the version numbers.
    shouldShowEditingLatestAlert() {
      return this.version.isUpdateAvailable && !this.isSubmitting;
    },
    duplicateLink() {
      return {
        name: this.itemRegistry.routes.duplicate,
        params: { id: this.$route.params.id },
      };
    },
    initialValues() {
      return this.editConfig.buildInitialValues(this.aiCatalogItem);
    },
  },
  created() {
    if (!canEditAiCatalogItem(this.aiCatalogItem)) {
      this.$router.push({
        name: this.itemRegistry.routes.show,
        params: { id: this.$route.params.id },
      });
    }
  },
  methods: {
    async handleSubmit({ itemType, ...input }) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const resolvedType = itemType || this.itemType;
      const registry = getRegistryItem(resolvedType);
      const apolloConfig = registry.mutations.update;
      const originalItemUpdatedAt = this.aiCatalogItem.updatedAt;
      const originalVersionUpdatedAt = this.aiCatalogItem.latestVersion.updatedAt;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: apolloConfig.mutation,
          variables: {
            input: { ...input, id: this.aiCatalogItem.id },
          },
          refetchQueries: [registry.queries.item],
          awaitRefetchQueries: true,
        });

        if (data) {
          const { errors, item } = data[apolloConfig.responseKey];
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          const itemWasUpdated = item.updatedAt !== originalItemUpdatedAt;
          const versionWasUpdated = item.latestVersion.updatedAt !== originalVersionUpdatedAt;
          if (itemWasUpdated || versionWasUpdated) {
            this.$toast.show(registry.edit.updatedMessage);
          }
          this.$router.push({
            name: registry.routes.show,
            params: { id: this.$route.params.id },
          });
        }
      } catch (error) {
        this.errors = [registry.edit.errorMessage];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    resetErrorMessages() {
      this.errors = [];
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="editConfig.heading">
      <template #description>{{ editConfig.description }}</template>
    </page-heading>
    <gl-alert
      v-if="shouldShowEditingLatestAlert"
      :dismissible="false"
      variant="warning"
      class="gl-my-6"
    >
      <gl-sprintf :message="editConfig.versionWarningMessage">
        <template #link="{ content }">
          <gl-link :to="duplicateLink">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
    <component
      :is="formComponent"
      mode="edit"
      :errors="errors"
      :initial-values="initialValues"
      :is-loading="isSubmitting"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
