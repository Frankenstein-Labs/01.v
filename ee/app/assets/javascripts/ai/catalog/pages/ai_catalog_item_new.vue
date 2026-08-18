<script>
import { GlToastMixin } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { getRegistryItem, itemTypeValidator } from '../item_type_registry';

import { prerequisitesError, isKnownPermissionError } from '../utils';
import { canCreateAiCatalogItem } from '../permissions';

export default {
  name: 'AiCatalogItemNew',
  components: {
    PageHeading,
  },
  mixins: [glAbilitiesMixin(), GlToastMixin],
  inject: {
    isGlobalNamespace: {},
  },
  props: {
    itemType: {
      type: String,
      required: true,
      validator: (value) => itemTypeValidator(value),
    },
  },
  data() {
    return {
      errors: [],
      isSubmitting: false,
    };
  },
  computed: {
    itemRegistry() {
      return getRegistryItem(this.itemType);
    },
    formComponent() {
      return this.itemRegistry.formComponent;
    },
    createConfig() {
      return this.itemRegistry.create;
    },
    heading() {
      return this.createConfig.heading;
    },
    description() {
      return this.createConfig.description;
    },
  },
  created() {
    if (
      !canCreateAiCatalogItem({
        isGlobalNamespace: this.isGlobalNamespace,
        glAbilities: this.glAbilities,
      })
    ) {
      this.$router.push({ name: this.itemRegistry.routes.list });
    }
  },
  methods: {
    async handleSubmit({ itemType, ...input }) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const itemTypeForConfig = itemType || this.itemType;
      const registry = getRegistryItem(itemTypeForConfig);
      const createConfig = registry.create;
      const apolloConfig = registry.mutations.create;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: apolloConfig.mutation,
          variables: { input },
        });
        if (data) {
          const createResponse = data[apolloConfig.responseKey];
          const { errors, item } = createResponse;
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }
          const newItemId = getIdFromGraphQLId(item.id);
          this.$toast.show(createConfig.createdMessage);
          this.$router.push({ name: registry.routes.show, params: { id: newItemId } });
        }
      } catch (error) {
        this.errors = [prerequisitesError(createConfig.errorMessage)];
        if (!isKnownPermissionError(error)) {
          Sentry.captureException(error);
        }
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
    <page-heading :heading="heading">
      <template #description> {{ description }} </template>
    </page-heading>
    <component
      :is="formComponent"
      mode="create"
      :is-loading="isSubmitting"
      :errors="errors"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
