<script>
import { GlToastMixin } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { getRegistryItem } from '../item_type_registry';
import { prerequisitesError, resolveVersion } from '../utils';
import { canDuplicateAiCatalogItem } from '../permissions';

export default {
  name: 'AiCatalogItemDuplicate',
  components: {
    PageHeading,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagsMixin(), GlToastMixin],
  inject: {
    isGlobalNamespace: {},
    isGroupNamespace: {},
  },
  props: {
    aiCatalogItem: {
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
    duplicateConfig() {
      return this.itemRegistry.duplicate;
    },
    formComponent() {
      return this.itemRegistry.formComponent;
    },
    activeVersion() {
      return resolveVersion(this.aiCatalogItem, {
        isGlobalNamespace: this.isGlobalNamespace,
        isGroupNamespace: this.isGroupNamespace,
      });
    },
    initialValues() {
      return this.duplicateConfig.buildInitialValues(this.aiCatalogItem, {
        activeVersion: this.activeVersion,
        glFeatures: this.glFeatures,
      });
    },
    canDuplicate() {
      return canDuplicateAiCatalogItem(this.aiCatalogItem, {
        isGlobalNamespace: this.isGlobalNamespace,
        isGroupNamespace: this.isGroupNamespace,
        glAbilities: this.glAbilities,
        glFeatures: this.glFeatures,
      });
    },
  },
  created() {
    if (!this.canDuplicate) {
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
      const apolloConfig = registry.mutations.create;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: apolloConfig.mutation,
          variables: { input },
        });
        if (data) {
          const { errors, item } = data[apolloConfig.responseKey];
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }
          this.$toast.show(registry.duplicate.createdMessage);
          this.$router.push({
            name: registry.routes.show,
            params: { id: getIdFromGraphQLId(item.id) },
          });
        }
      } catch (error) {
        this.errors = [prerequisitesError(registry.duplicate.errorMessage)];
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
    <page-heading :heading="duplicateConfig.heading">
      <template #description>{{ duplicateConfig.description }}</template>
    </page-heading>
    <component
      :is="formComponent"
      mode="create"
      :initial-values="initialValues"
      :is-loading="isSubmitting"
      :errors="errors"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
