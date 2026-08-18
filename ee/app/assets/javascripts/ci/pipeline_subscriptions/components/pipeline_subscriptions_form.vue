<script>
import { GlButton, GlForm, GlFormGroup, GlFormInput, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import AddPipelineSubscription from '../graphql/mutations/add_pipeline_subscription.mutation.graphql';

export default {
  name: 'PipelineSubscriptionsForm',
  i18n: {
    formLabel: __('Project path'),
    inputPlaceholder: __('Paste project path (i.e. gitlab-org/gitlab)'),
    subscribe: __('Subscribe'),
    cancel: __('Cancel'),
    addSubscription: s__('PipelineSubscriptions|Add new pipeline subscription'),
    generalError: s__(
      'PipelineSubscriptions|An error occurred while adding a new pipeline subscription.',
    ),
    addSuccess: s__('PipelineSubscriptions|Subscription successfully created.'),
  },
  docsLink: helpPagePath('ci/pipelines/_index', {
    anchor: 'trigger-a-pipeline-when-an-upstream-project-is-rebuilt',
  }),
  components: {
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlLink,
    HelpIcon,
  },
  inject: {
    projectPath: {
      default: '',
    },
  },
  emits: ['add-subscription-success', 'canceled'],
  data() {
    return {
      upstreamPath: '',
    };
  },
  methods: {
    async createSubscription() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: AddPipelineSubscription,
          variables: {
            input: {
              projectPath: this.projectPath,
              upstreamPath: this.upstreamPath,
            },
          },
        });

        if (data.projectSubscriptionCreate.errors.length > 0) {
          createAlert({ message: data.projectSubscriptionCreate.errors[0] });
        } else {
          createAlert({ message: this.$options.i18n.addSuccess, variant: 'success' });
          this.upstreamPath = '';

          this.$emit('add-subscription-success');
        }
      } catch (error) {
        const { graphQLErrors } = error;

        if (graphQLErrors.length > 0) {
          createAlert({ message: graphQLErrors[0]?.message, variant: 'warning' });
        } else {
          createAlert({ message: this.$options.i18n.generalError });
        }
      }
    },
    cancelSubscription() {
      this.upstreamPath = '';
      this.$emit('canceled');
    },
  },
};
</script>

<template>
  <div>
    <h4 class="gl-mt-0">{{ $options.i18n.addSubscription }}</h4>
    <gl-form>
      <gl-form-group label-for="project-path">
        <template #label>
          {{ $options.i18n.formLabel }}
          <gl-link :href="$options.docsLink" target="_blank">
            <help-icon />
          </gl-link>
        </template>
        <gl-form-input
          id="project-path"
          v-model="upstreamPath"
          type="text"
          :placeholder="$options.i18n.inputPlaceholder"
          data-testid="upstream-project-path-field"
        />
      </gl-form-group>

      <div class="gl-flex gl-gap-3">
        <gl-button variant="confirm" data-testid="subscribe-button" @click="createSubscription">
          {{ $options.i18n.subscribe }}
        </gl-button>
        <gl-button data-testid="cancel-button" @click="cancelSubscription">
          {{ $options.i18n.cancel }}
        </gl-button>
      </div>
    </gl-form>
  </div>
</template>
