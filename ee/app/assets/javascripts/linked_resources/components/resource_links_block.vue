<script>
import { produce } from 'immer';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_ISSUE } from '~/graphql_shared/constants';
import { createAlert } from '~/alert';
import { sprintf } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { resourceLinksI18n } from '../constants';
import { displayAndLogError, identifyLinkType } from './utils';
import getIssuableResourceLinks from './graphql/queries/get_issuable_resource_links.query.graphql';
import deleteIssuableRsourceLink from './graphql/queries/delete_issuable_resource_link.mutation.graphql';
import createIssuableResourceLink from './graphql/queries/create_issuable_resource_link.mutation.graphql';
import AddIssuableResourceLinkForm from './add_issuable_resource_link_form.vue';
import ResourceLinksList from './resource_links_list.vue';

export default {
  name: 'ResourceLinksBlock',
  components: {
    AddIssuableResourceLinkForm,
    ResourceLinksList,
    CrudComponent,
  },
  mixins: [glSlotsMixin],
  i18n: resourceLinksI18n,
  ariaControlsId: 'resource-links-card',
  props: {
    issuableId: {
      type: Number,
      required: true,
    },
    canAddResourceLinks: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isSubmitting: false,
      resourceLinks: [],
    };
  },
  apollo: {
    resourceLinks: {
      query: getIssuableResourceLinks,
      variables() {
        return {
          incidentId: convertToGraphQLId(TYPENAME_ISSUE, this.issuableId),
        };
      },
      update(data) {
        return data?.issue?.issuableResourceLinks?.nodes;
      },
      error(error) {
        displayAndLogError(error);
      },
    },
  },
  computed: {
    resourceCount() {
      return this.resourceLinks.length;
    },
    hasResourceLinks() {
      return Boolean(this.resourceCount);
    },
    isFetching() {
      return Boolean(this.$apollo.queries.resourceLinks.loading);
    },
  },
  methods: {
    hideResourceLinkForm() {
      this.$refs.resourceLinksCrud.hideForm();
    },
    async onResourceLinkRemoveRequest(linkToRemove) {
      try {
        const result = await this.$apollo.mutate({
          mutation: deleteIssuableRsourceLink,
          variables: {
            input: {
              id: linkToRemove,
            },
          },
          update: () => {
            this.resourceLinks = this.resourceLinks.filter((link) => link.id !== linkToRemove);
          },
        });
        const { errors } = result.data.issuableResourceLinkDestroy;
        if (errors?.length) {
          const errorMessage = sprintf(this.$options.i18n.deleteError, {
            error: errors.join('. '),
          });
          throw new Error(errorMessage);
        }
      } catch (error) {
        const message = error.message || this.$options.i18n.deleteErrorGeneric;
        let captureError = false;
        let errorObj = null;

        if (message === this.$options.i18n.deleteErrorGeneric) {
          captureError = true;
          errorObj = error;
        }

        createAlert({
          message,
          captureError,
          error: errorObj,
        });
      }
    },
    updateCache(store, { data }) {
      const { issuableResourceLink: resourceLink, errors } = data?.issuableResourceLinkCreate || {};
      if (errors.length) {
        return;
      }

      const variables = {
        incidentId: convertToGraphQLId(TYPENAME_ISSUE, this.issuableId),
      };

      const sourceData = store.readQuery({
        query: getIssuableResourceLinks,
        variables,
      });

      const newData = produce(sourceData, (draftData) => {
        const { nodes: draftLinkList } = draftData.issue.issuableResourceLinks;
        draftLinkList.push(resourceLink);
        draftData.issue.issuableResourceLinks.nodes = draftLinkList;
      });

      store.writeQuery({
        query: getIssuableResourceLinks,
        variables,
        data: newData,
      });
    },
    onCreateResourceLink(resourceLink) {
      this.isSubmitting = true;
      return this.$apollo
        .mutate({
          mutation: createIssuableResourceLink,
          variables: {
            input: {
              ...resourceLink,
              id: convertToGraphQLId(TYPENAME_ISSUE, this.issuableId),
              linkType: identifyLinkType(resourceLink.link),
            },
          },
          update: this.updateCache,
        })
        .then(({ data = {} }) => {
          const errors = data.issuableResourceLinkCreate?.errors;
          if (errors.length) {
            const errorMessage = sprintf(
              this.$options.i18n.createError,
              { error: errors.join('. ') },
              false,
            );
            throw new Error(errorMessage);
          }
        })
        .catch((error) => {
          const message = error.message || this.$options.i18n.createErrorGeneric;
          let captureError = false;
          let errorObj = null;

          if (message === this.$options.i18n.createErrorGeneric) {
            captureError = true;
            errorObj = error;
          }

          createAlert({
            message,
            captureError,
            error: errorObj,
          });
        })
        .finally(() => {
          this.isSubmitting = false;
          this.$refs.resourceLinkForm.onFormCancel();
        });
    },
  },
};
</script>

<template>
  <div id="resource-links">
    <crud-component
      ref="resourceLinksCrud"
      :anchor-id="$options.ariaControlsId"
      :title="$options.i18n.headerText"
      icon="link"
      :count="resourceCount"
      :toggle-text="canAddResourceLinks ? __('Add') : null"
      :toggle-aria-label="$options.i18n.addButtonText"
      :is-loading="isFetching"
      is-collapsible
    >
      <template v-if="glSlots()['header-actions']" #actions>
        <slot name="header-actions"></slot>
      </template>

      <template #form>
        <add-issuable-resource-link-form
          ref="resourceLinkForm"
          :is-submitting="isSubmitting"
          @add-issuable-resource-link-form-cancel="hideResourceLinkForm"
          @create-resource-link="onCreateResourceLink"
        />
      </template>

      <template v-if="!hasResourceLinks" #empty>
        {{ $options.i18n.helpText }}
      </template>

      <resource-links-list
        data-testid="resource-links-list"
        :can-admin="canAddResourceLinks"
        :resource-links="resourceLinks"
        @resource-link-remove-request="onResourceLinkRemoveRequest"
      />
    </crud-component>
  </div>
</template>
