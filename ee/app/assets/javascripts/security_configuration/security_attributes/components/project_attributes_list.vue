<script>
import { GlTable, GlLabel, GlButton, GlEmptyState, GlLoadingIcon, GlToastMixin } from '@gitlab/ui';
import EMPTY_ATTRIBUTE_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-labels-md.svg?url';
import { s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { InternalEvents } from '~/tracking';
import getProjectSecurityAttributesQuery from 'ee_component/security_configuration/graphql/project_security_attributes.query.graphql';
import ProjectSecurityAttributesUpdateMutation from '../../graphql/project_security_attributes_update.mutation.graphql';
import ProjectAttributesUpdateDrawer from './project_attributes_update_drawer.vue';

export default {
  name: 'ProjectAttributesList',
  components: {
    GlTable,
    GlLabel,
    GlButton,
    GlEmptyState,
    GlLoadingIcon,
    ProjectAttributesUpdateDrawer,
  },
  mixins: [InternalEvents.mixin(), GlToastMixin],
  inject: ['projectFullPath', 'canManageAttributes'],
  EMPTY_ATTRIBUTE_SVG,
  data() {
    return {
      project: {
        id: '',
        securityAttributes: { nodes: [] },
      },
    };
  },
  apollo: {
    project: {
      query: getProjectSecurityAttributesQuery,
      variables() {
        return {
          fullPath: this.projectFullPath,
        };
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.project.loading;
    },
  },
  mounted() {
    this.trackEvent('view_project_security_attributes');
  },
  methods: {
    openEditDrawer() {
      this.$refs.updateAttributesDrawer.openDrawer();
    },
    refreshDashboard() {
      this.$apollo.queries.project.refetch();
    },
    removeAttribute(item) {
      return this.$apollo
        .mutate({
          mutation: ProjectSecurityAttributesUpdateMutation,
          variables: {
            input: {
              projectId: this.project.id,
              removeAttributeIds: [item.id],
            },
          },
        })
        .then(() => {
          const toastMsg = sprintf(
            s__(
              'SecurityAttributes|Successfully removed "%{name}" security attribute from this project',
            ),
            {
              name: item.name,
            },
          );
          this.$toast.show(toastMsg);
        })
        .catch((error) => {
          Sentry.captureException(error);
          createAlert({
            message: s__(
              'SecurityAttributes|An error has occurred while removing the security attribute.',
            ),
          });
        })
        .finally(() => {
          this.$apollo.queries.project.refetch();
        });
    },
  },
  fields: [
    {
      key: 'securityCategory.name',
      label: s__('SecurityAttributes|Category'),
      thClass: 'gl-max-w-0',
    },
    { key: 'name', label: s__('SecurityAttributes|Attributes'), thClass: 'gl-w-1/5' },
    { key: 'description', label: s__('SecurityAttributes|Description'), thClass: 'gl-w-1/2' },
    { key: 'actions', label: '' },
  ],
};
</script>

<template>
  <div>
    <gl-button
      v-if="canManageAttributes"
      variant="confirm"
      class="gl-float-right gl-mb-5 gl-ml-5"
      @click="openEditDrawer"
    >
      {{ s__('SecurityAttributes|Edit project attributes') }}
    </gl-button>

    <p class="gl-my-5">
      {{
        s__(
          'SecurityAttributes|Security attributes help classify and organize your projects. Attributes are managed at the group level. Project Owners and Maintainers can add or remove attributes to this project as needed.',
        )
      }}
    </p>

    <gl-table
      :fields="$options.fields"
      :items="project.securityAttributes.nodes"
      table-class="gl-table-fixed"
      show-empty
      :busy="isLoading"
    >
      <template #table-busy>
        <div class="gl-py-5 gl-text-center">
          <gl-loading-icon size="md" />
        </div>
      </template>
      <template #empty>
        <gl-empty-state
          :svg-path="$options.EMPTY_ATTRIBUTE_SVG"
          :svg-height="100"
          :title="s__('SecurityAttributes|No security attributes added yet')"
          :description="__('Attributes you add will appear here.')"
        >
          <template #actions>
            <gl-button v-if="canManageAttributes" variant="confirm" @click="openEditDrawer">
              {{ s__('SecurityAttributes|Add attributes') }}
            </gl-button>
          </template>
        </gl-empty-state>
      </template>
      <template #cell(name)="{ item: { name, color } }">
        <gl-label :background-color="color" :title="name" />
      </template>
      <template v-if="canManageAttributes" #cell(actions)="{ item }">
        <gl-button @click="removeAttribute(item)">
          {{ s__('SecurityAttributes|Remove attribute') }}
        </gl-button>
      </template>
    </gl-table>

    <project-attributes-update-drawer
      v-if="!isLoading && canManageAttributes"
      ref="updateAttributesDrawer"
      :project-id="project.id"
      :selected-attributes="project.securityAttributes.nodes"
      @saved="refreshDashboard"
    />
  </div>
</template>
