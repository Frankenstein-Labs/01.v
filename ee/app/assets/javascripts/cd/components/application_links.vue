<script>
import { GlAlert, GlButton, GlIcon, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { linkTypeIcon } from '../constants';
import cdApplicationLinkCreateMutation from '../graphql/cd_application_link_create.mutation.graphql';
import cdApplicationLinkUpdateMutation from '../graphql/cd_application_link_update.mutation.graphql';
import cdApplicationLinkDeleteMutation from '../graphql/cd_application_link_delete.mutation.graphql';
import LinkForm from './link_form.vue';

export default {
  name: 'ApplicationLinks',
  components: {
    GlAlert,
    GlButton,
    GlIcon,
    GlLink,
    LinkForm,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    applicationId: {
      type: String,
      required: true,
    },
    links: {
      type: Array,
      required: false,
      default: () => [],
    },
    full: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['expand', 'created', 'updated', 'deleted'],
  data() {
    return {
      editingLink: null,
      isFormOpen: false,
      isSubmitting: false,
      errorMessage: '',
    };
  },
  watch: {
    full(isFull) {
      if (!isFull) {
        this.closeForm();
      }
    },
  },
  methods: {
    iconFor(link) {
      return linkTypeIcon(link.linkType);
    },
    hostFor(link) {
      try {
        return new URL(link.url).hostname || link.url;
      } catch {
        return link.url;
      }
    },
    editLabel(link) {
      return sprintf(__('Edit %{name}'), { name: link.name });
    },
    deleteLabel(link) {
      return sprintf(__('Delete %{name}'), { name: link.name });
    },
    openForm(link = null) {
      this.editingLink = link;
      this.isFormOpen = true;
      this.$emit('expand');
    },
    closeForm() {
      this.isFormOpen = false;
      this.editingLink = null;
      this.errorMessage = '';
    },
    async onSubmit(input) {
      this.isSubmitting = true;
      this.errorMessage = '';

      try {
        const errors = this.editingLink
          ? await this.updateLink(input)
          : await this.createLink(input);

        if (errors.length) {
          this.errorMessage = errors.join(' ');
          return;
        }

        this.$emit(this.editingLink ? 'updated' : 'created');
        this.closeForm();
      } catch (error) {
        Sentry.captureException(error);
        this.errorMessage = s__('ContinuousDeployment|Failed to save the link. Try again later.');
      } finally {
        this.isSubmitting = false;
      }
    },
    async createLink(input) {
      const { data } = await this.$apollo.mutate({
        mutation: cdApplicationLinkCreateMutation,
        variables: { input: { applicationId: this.applicationId, ...input } },
      });

      return data.cdApplicationLinkCreate.errors;
    },
    async updateLink(input) {
      const { data } = await this.$apollo.mutate({
        mutation: cdApplicationLinkUpdateMutation,
        variables: { input: { id: this.editingLink.id, ...input } },
      });

      return data.cdApplicationLinkUpdate.errors;
    },
    async deleteLink(link) {
      const confirmed = await confirmAction(
        sprintf(s__('ContinuousDeployment|Are you sure you want to delete %{name} link?'), {
          name: link.name,
        }),
        {
          primaryBtnText: __('Delete'),
          primaryBtnVariant: 'danger',
        },
      );

      if (!confirmed) {
        return;
      }

      this.errorMessage = '';

      try {
        const { data } = await this.$apollo.mutate({
          mutation: cdApplicationLinkDeleteMutation,
          variables: { input: { id: link.id } },
        });

        if (data.cdApplicationLinkDelete.errors.length) {
          this.errorMessage = data.cdApplicationLinkDelete.errors.join(' ');
          return;
        }

        this.$emit('deleted');
      } catch (error) {
        Sentry.captureException(error);
        this.errorMessage = s__('ContinuousDeployment|Failed to delete the link. Try again later.');
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="errorMessage" variant="danger" class="gl-mb-3" @dismiss="errorMessage = ''">
      {{ errorMessage }}
    </gl-alert>

    <ul class="gl-m-0 gl-list-none gl-p-0">
      <li
        v-for="link in links"
        :key="link.id"
        class="gl-border-b gl-flex gl-items-center gl-gap-3 gl-px-4 gl-py-3 gl-text-sm hover:gl-bg-subtle"
        data-testid="link-row"
      >
        <gl-icon :name="iconFor(link)" class="gl-shrink-0 gl-text-subtle" />
        <gl-link
          v-gl-tooltip
          :title="link.url"
          :href="link.url"
          target="_blank"
          rel="noopener noreferrer"
          show-external-icon
        >
          {{ link.name }}
        </gl-link>

        <div v-if="full" class="gl-ml-auto gl-flex gl-items-center gl-gap-3">
          <gl-link
            :href="link.url"
            target="_blank"
            rel="noopener noreferrer"
            show-external-icon
            class="gl-text-subtle"
            data-testid="link-host"
          >
            {{ hostFor(link) }}
          </gl-link>
          <gl-button
            v-gl-tooltip
            category="tertiary"
            size="small"
            icon="pencil"
            class="!gl-text-subtle"
            :title="editLabel(link)"
            :aria-label="editLabel(link)"
            data-testid="edit-link-button"
            @click="openForm(link)"
          />
          <gl-button
            v-gl-tooltip
            category="tertiary"
            size="small"
            icon="remove"
            class="!gl-text-subtle"
            :title="deleteLabel(link)"
            :aria-label="deleteLabel(link)"
            data-testid="delete-link-button"
            @click="deleteLink(link)"
          />
        </div>
      </li>

      <li v-if="!isFormOpen" class="gl-p-2">
        <gl-button
          variant="link"
          icon="plus"
          class="!gl-text-sm !gl-text-subtle hover:!gl-text-link"
          data-testid="add-link-button"
          @click="openForm()"
        >
          {{ s__('ContinuousDeployment|Add link') }}
        </gl-button>
      </li>
    </ul>

    <link-form
      v-if="isFormOpen"
      :key="editingLink ? editingLink.id : 'create'"
      :link="editingLink"
      :submitting="isSubmitting"
      class="gl-mt-4"
      @submit="onSubmit"
      @cancel="closeForm"
    />
  </div>
</template>
